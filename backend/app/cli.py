"""CLI: export-openapi, load-snapshot, rehost-media (stdlib argparse)."""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

from fastapi import FastAPI
from sqlalchemy.orm import Session

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


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(prog="app.cli")
    sub = parser.add_subparsers(dest="command", required=True)

    sub.add_parser("export-openapi", help="Export the public and admin OpenAPI documents")

    p = sub.add_parser("load-snapshot", help="Load the snapshot into PostgreSQL")
    p.add_argument("--snapshot-dir", required=True)
    p.add_argument("--report-dir", required=True)

    p = sub.add_parser("rehost-media", help="Rehost snapshot media onto the media host")
    p.add_argument("--snapshot-dir", required=True)
    p.add_argument("--report-dir", required=True)

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
    parser.error(f"unknown command {args.command}")
    return 2


if __name__ == "__main__":
    sys.exit(main())
