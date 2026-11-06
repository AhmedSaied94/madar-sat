"""CLI: export-openapi, load-snapshot, rehost-media, repair-matches, create-admin, set-admin-password, deactivate-admin.

Stdlib argparse. A password is never accepted as an argument (it would land in shell history and
``ps``): it is read twice from the terminal, or once from stdin with ``--password-stdin``.
"""

from __future__ import annotations

import argparse
import getpass
import json
import sys
from datetime import UTC, datetime
from pathlib import Path

from fastapi import FastAPI
from sqlalchemy.exc import OperationalError
from sqlalchemy.orm import Session

from app.auth import admins
from app.db.session import SyncSession
from app.etl.report import Report
from app.etl.snapshot import load
from app.etl.types import read_snapshot
from app.services.match_repair import (
    FillResult,
    MergeResult,
    RepairRefused,
    SportResult,
    fill_teams,
    merge_pairs,
    repair_sports,
)
from app.settings import get_settings


def _write_openapi(app: FastAPI, path: Path) -> None:
    schema = app.openapi()
    schema["info"]["version"] = get_settings().contract_version
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(schema, sort_keys=True, indent=2) + "\n", encoding="utf-8")


def cmd_export_openapi(_args: argparse.Namespace) -> int:
    from app.admin import app as admin_app
    from app.public import app as public_app

    _write_openapi(public_app, Path("openapi/public.json"))
    _write_openapi(admin_app, Path("openapi/admin.json"))
    print("Wrote openapi/public.json and openapi/admin.json")
    return 0


def _finish(session: Session, report: Report, report_dir: str) -> int:
    """Commit only a reconciled run (a found card-sharing label must not be stored, FR-005),
    write the report files and print the summary. Exit status 1 unless reconciled."""
    reconciled = report.reconciled
    if reconciled:
        session.commit()
    else:
        session.rollback()
    json_path, _details_path = report.write(report_dir)
    print("\n".join(report.summary()))
    print(f"report: {json_path}" + ("" if reconciled else " (not reconciled: rolled back)"))
    return 0 if reconciled else 1


def cmd_load_snapshot(args: argparse.Namespace) -> int:
    snapshot = read_snapshot(args.snapshot_dir)
    report = Report("load-snapshot", args.snapshot_dir)
    with SyncSession() as session:
        load(session, snapshot, report)
        return _finish(session, report, args.report_dir)


def cmd_rehost_media(args: argparse.Namespace) -> int:
    from app.etl.media import rehost

    settings = get_settings()
    snapshot = read_snapshot(args.snapshot_dir)
    report = Report("rehost-media", args.snapshot_dir)
    with SyncSession() as session:
        rehost(session, snapshot, report, settings.media_root, settings.media_rehost_allowed_hosts)
        return _finish(session, report, args.report_dir)


def _read_password(args: argparse.Namespace) -> str:
    """The new password: one line from stdin, or twice from the terminal (no echo)."""
    if args.password_stdin:
        return sys.stdin.readline().rstrip("\r\n")
    first = getpass.getpass("Password: ")
    if first != getpass.getpass("Repeat password: "):
        raise admins.AdminError("the two passwords differ")
    return first


def _run_admin_command(args: argparse.Namespace) -> int:
    """Run one account command in a transaction; a refusal prints its reason (never a password) and exits 1."""
    try:
        with SyncSession() as session:
            if args.command == "create-admin":
                password = _read_password(args)
                admin = admins.create_admin(session, args.email, args.name, args.role, password)
                message = f"created {admin.role} {admin.email} (id {admin.id})"
            elif args.command == "set-admin-password":
                password = _read_password(args)
                admin = admins.set_password(session, args.email, password)
                message = f"password changed for {admin.email}; every session of theirs has ended"
            else:
                admin = admins.deactivate(session, args.email)
                message = f"deactivated {admin.email}; every session of theirs has ended"
            session.commit()
    except admins.AdminError as exc:
        print(f"error: {exc}", file=sys.stderr)
        return 1
    print(message)
    return 0


def cmd_capture_live(args: argparse.Namespace) -> int:
    """Save live pages for the capture report (research R12). Never runs without a user agent."""
    import redis

    from app.adapters.alerts import send_alert
    from app.adapters.config import get_adapter_settings
    from app.adapters.fetcher import HttpFetcher
    from app.adapters.ratelimit import RateLimiter
    from app.live.capture import enabled_lists, run_capture
    from app.live.config import get_live_settings
    from app.workers.config import get_worker_settings
    from app.workers.logs import setup_logging

    setup_logging()  # Celery's signal never fires here, and the report needs each failure's page and reason
    settings = get_adapter_settings()
    user_agent = settings.require_user_agent()
    client = redis.Redis.from_url(get_worker_settings().broker_url)
    try:
        with HttpFetcher(RateLimiter(client), user_agent) as fetcher:
            saved = run_capture(
                enabled_lists(goal_enabled=get_live_settings().goal_enabled),
                lambda url, host: fetcher.get(url, allowed_hosts=frozenset({host})),
                Path(settings.raw_root),
                args.minutes,
                alert=send_alert,
                client=client,
                page_cap=args.page_cap,
            )
    finally:
        client.close()
    print(f"saved {saved} pages under {settings.raw_root}/capture/")
    return 0


def _read_pairs(path: str) -> list[tuple[int, int]]:
    """``[{"keep": 870, "drop": 1258}, ...]``, from a file or, with ``-``, stdin."""
    raw = sys.stdin.read() if path == "-" else Path(path).read_text(encoding="utf-8")
    return [(int(pair["keep"]), int(pair["drop"])) for pair in json.loads(raw)]


def _print_merge(result: MergeResult) -> None:
    print(
        json.dumps(
            {
                "keep": result.keep_id,
                "drop": result.drop_id,
                "filled": result.filled,
                "live_copied": result.live_copied,
                "differs": result.differs,
            },
            ensure_ascii=False,
        )
    )


def _read_sport_map(path: str) -> dict[int, str]:
    """``{"870": "basketball", ...}``, from a file or, with ``-``, stdin. Never from the snapshot."""
    raw = sys.stdin.read() if path == "-" else Path(path).read_text(encoding="utf-8")
    return {int(match_id): str(sport) for match_id, sport in json.loads(raw).items()}


def _print_sport(result: SportResult) -> None:
    for match_id, sport in result.listed:
        print(json.dumps({"listed": match_id, "sport": sport}))
    for match_id, before, after in result.changed:
        print(json.dumps({"changed": match_id, "from": before, "to": after}))
    for match_id in result.unchanged:
        print(json.dumps({"already": match_id}))


def _print_fill(result: FillResult) -> None:
    for match_id, side, team_id in result.filled:
        print(json.dumps({"match": match_id, "side": side, "team": team_id}))
    for name_norm, competition_norm in result.ambiguous:
        print(json.dumps({"decided_two_ways": name_norm, "competition": competition_norm}, ensure_ascii=False))


def cmd_repair_matches(args: argparse.Namespace) -> int:
    """All of it or none of it, and nothing at all without ``--apply``: a dry run rolls the real work back."""
    now = datetime.now(UTC)
    with SyncSession() as session:
        try:
            if args.action == "merge":
                for result in merge_pairs(session, _read_pairs(args.pairs), now):
                    _print_merge(result)
            elif args.action == "sport":
                mapping = _read_sport_map(args.map) if args.map else {}
                _print_sport(repair_sports(session, mapping, now))
            else:
                _print_fill(fill_teams(session, now))
        except RepairRefused as exc:
            session.rollback()
            print(f"REFUSED, nothing changed: {exc}")
            return 1
        except OperationalError as exc:
            session.rollback()
            print(f"Couldn't lock matches, nothing changed. Try again: {exc.orig}")
            return 1
        if args.apply:
            session.commit()
            print("Applied.")
        else:
            session.rollback()
            print("DRY RUN: nothing changed. Add --apply to do this.")
    return 0


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(prog="app.cli")
    sub = parser.add_subparsers(dest="command", required=True)

    sub.add_parser("export-openapi", help="Export the public and admin OpenAPI documents")

    p = sub.add_parser("create-admin", help="Create an editor or admin account (prompts for the password twice)")
    p.add_argument("--email", required=True)
    p.add_argument("--name", required=True)
    p.add_argument("--role", required=True, choices=list(admins.ROLES))
    p.add_argument("--password-stdin", action="store_true", help="read the password once from stdin")

    p = sub.add_parser("set-admin-password", help="Replace an admin's password and end their sessions")
    p.add_argument("--email", required=True)
    p.add_argument("--password-stdin", action="store_true", help="read the password once from stdin")

    p = sub.add_parser("deactivate-admin", help="Switch an account off and end their sessions")
    p.add_argument("--email", required=True)

    p = sub.add_parser("load-snapshot", help="Load the snapshot into PostgreSQL")
    p.add_argument("--snapshot-dir", required=True)
    p.add_argument("--report-dir", required=True)

    p = sub.add_parser("rehost-media", help="Rehost snapshot media onto the media host")
    p.add_argument("--snapshot-dir", required=True)
    p.add_argument("--report-dir", required=True)

    p = sub.add_parser("capture-live", help="Save live list and match pages for the capture report")
    p.add_argument("--minutes", type=int, default=240, help="How long to record, about one round a minute")
    p.add_argument("--page-cap", type=int, default=12, help="Most match pages per source per round")

    p = sub.add_parser("repair-matches", help="Fold duplicate matches together, or fill teams decided in A13")
    actions = p.add_subparsers(dest="action", required=True)
    merge = actions.add_parser("merge", help="Merge reviewed pairs. A dry run unless --apply")
    merge.add_argument("pairs", help='A JSON file of [{"keep": id, "drop": id}], or - for stdin')
    merge.add_argument("--apply", action="store_true", help="Do it, rather than show what it would do")
    fill = actions.add_parser(
        "fill-teams", help="Fill empty teams from names already decided. A dry run unless --apply"
    )
    fill.add_argument("--apply", action="store_true", help="Do it, rather than show what it would do")
    sport = actions.add_parser(
        "sport", help="Relabel sporteventz rows a reviewer's map reads. A dry run unless --apply"
    )
    sport.add_argument(
        "map", nargs="?", help='A JSON file of {"<match id>": "<sport>"}, or - for stdin. Without it, list only'
    )
    sport.add_argument("--apply", action="store_true", help="Do it, rather than show what it would do")

    return parser


def main(argv: list[str] | None = None) -> int:
    parser = build_parser()
    args = parser.parse_args(argv)
    if args.command == "export-openapi":
        return cmd_export_openapi(args)
    if args.command == "load-snapshot":
        return cmd_load_snapshot(args)
    if args.command == "rehost-media":
        return cmd_rehost_media(args)
    if args.command == "capture-live":
        return cmd_capture_live(args)
    if args.command == "repair-matches":
        return cmd_repair_matches(args)
    if args.command in ("create-admin", "set-admin-password", "deactivate-admin"):
        return _run_admin_command(args)
    parser.error(f"unknown command {args.command}")
    return 2


if __name__ == "__main__":
    sys.exit(main())
