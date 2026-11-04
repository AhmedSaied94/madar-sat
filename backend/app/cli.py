"""CLI: export-openapi, load-snapshot, rehost-media, create-admin, set-admin-password, deactivate-admin.

Stdlib argparse. A password is never accepted as an argument (it would land in shell history and
``ps``): it is read twice from the terminal, or once from stdin with ``--password-stdin``.
"""

from __future__ import annotations

import argparse
import getpass
import json
import sys
from pathlib import Path

from fastapi import FastAPI
from sqlalchemy.orm import Session

from app.auth import admins
from app.db.session import SyncSession
from app.etl.report import Report
from app.etl.snapshot import load
from app.etl.types import read_snapshot
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
    """Save live pages for the capture report (research R1). Never runs without a user agent."""
    import redis

    from app.adapters.config import get_adapter_settings
    from app.adapters.fetcher import HttpFetcher
    from app.adapters.ratelimit import RateLimiter
    from app.live.capture import run_capture, targets
    from app.workers.config import get_worker_settings

    settings = get_adapter_settings()
    user_agent = settings.require_user_agent()
    items = targets(args.filgoal, args.yallakora)
    client = redis.Redis.from_url(get_worker_settings().broker_url)
    try:
        with HttpFetcher(RateLimiter(client), user_agent) as fetcher:
            saved = run_capture(
                items,
                lambda url, host: fetcher.get(url, allowed_hosts=frozenset({host})),
                Path(settings.raw_root),
                args.minutes,
            )
    finally:
        client.close()
    print(f"saved {saved} pages under {settings.raw_root}/capture/")
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
    p.add_argument("--filgoal", action="append", default=[], metavar="MATCH_ID", help="A FilGoal match id")
    p.add_argument("--yallakora", action="append", default=[], metavar="PATH", help="A YallaKora match path")
    p.add_argument("--minutes", type=int, default=150, help="How long to record, one round a minute")

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
    if args.command in ("create-admin", "set-admin-password", "deactivate-admin"):
        return _run_admin_command(args)
    parser.error(f"unknown command {args.command}")
    return 2


if __name__ == "__main__":
    sys.exit(main())
