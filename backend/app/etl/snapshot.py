"""Snapshot load orchestrator (README rules 1–17, research R10).

One transaction: reference data, then channels and rights, then matches. Every row is
upserted by ``legacy_id`` or its natural key, and link rows by their primary key, so a
re-run on the same snapshot changes nothing (FR-004) and a refreshed snapshot only adds or
updates rows (data-model "Identity and upserts"). Nothing is deleted: matches are history,
and later writers (importers, admins) own link rows the snapshot doesn't know about.
"""

from __future__ import annotations

from collections.abc import Iterable

from sqlalchemy import func, update
from sqlalchemy.orm import Session

from app.db.models import DATASET_NAMES, DatasetVersion
from app.etl import channels as etl_channels
from app.etl import matches as etl_matches
from app.etl import reference as etl_reference
from app.etl.checks import scan_card_sharing_labels
from app.etl.report import Report
from app.etl.types import Context, Snapshot


def load(session: Session, snapshot: Snapshot, report: Report) -> None:
    ctx = Context()
    etl_reference.load(session, snapshot, report, ctx)
    etl_channels.load(session, snapshot, report, ctx)
    etl_matches.load(session, snapshot, report, ctx)
    run_checks(session, report)
    # Bump every dataset version last (data-model "dataset_versions").
    bump_dataset_versions(session, DATASET_NAMES)


def run_checks(session: Session, report: Report) -> None:
    """SC-002: no stored text the ETL wrote may contain a card-sharing label."""
    hits = scan_card_sharing_labels(session)
    report.checks["card_sharing_labels_found"] = len(hits)
    for hit in hits:
        report.warn("card_sharing_label_found", f"{hit.table}.{hit.column} {hit.key}", hit.label)


def bump_dataset_versions(session: Session, names: Iterable[str]) -> None:
    """``version = version + 1`` for each named dataset; call as the transaction's last write."""
    wanted = sorted(set(names))
    if not wanted:
        return
    session.flush()
    session.execute(
        update(DatasetVersion)
        .where(DatasetVersion.name.in_(wanted))
        .values(version=DatasetVersion.version + 1, updated_at=func.now())
    )
