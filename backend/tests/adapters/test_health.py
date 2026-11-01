"""The breaker, the zero-items alarm and the ``sources`` bump (T057, R17)."""

from __future__ import annotations

from datetime import UTC, datetime

import pytest
from sqlalchemy import text

from app.adapters import health
from app.adapters.health import column_available, record_run, source_is_paused
from tests.adapters.helpers import dataset_versions

NOW = datetime(2026, 11, 7, 12, 0, tzinfo=UTC)


@pytest.fixture
def health_ready(sync_session):  # noqa: ANN001 - the fixture yields nothing
    if not column_available(sync_session, "sources", "consecutive_failures"):
        pytest.skip("0005's source-health columns are not applied yet (B1 T008; rebase at T068)")


def _row(sync_session) -> tuple:
    return sync_session.execute(
        text(
            "SELECT consecutive_failures, breaker_opened_at, last_success_at, last_zero_alert_on "
            "FROM sources WHERE name = 'livesoccertv'"
        )
    ).one()


class Recorder:
    def __init__(self) -> None:
        self.sent: list[str] = []

    def __call__(self, text_: str) -> bool:
        self.sent.append(text_)
        return True


def test_a_failed_run_increments_the_failures(sync_session, health_ready) -> None:
    alerts = Recorder()
    record_run(
        sync_session,
        source="livesoccertv",
        status="failed",
        items_found=0,
        finished_at=NOW,
        alert=alerts,
        now=NOW,
    )
    assert _row(sync_session)[0] == 1
    assert alerts.sent == []


def test_a_success_resets_the_count_and_sets_last_success(sync_session, health_ready) -> None:
    for _ in range(2):
        record_run(
            sync_session,
            source="livesoccertv",
            status="failed",
            items_found=0,
            finished_at=NOW,
            alert=Recorder(),
            now=NOW,
        )
    record_run(
        sync_session,
        source="livesoccertv",
        status="succeeded",
        items_found=5,
        finished_at=NOW,
        alert=Recorder(),
        now=NOW,
    )

    failures, breaker, last_success, _ = _row(sync_session)
    assert failures == 0
    assert breaker is None
    assert last_success is not None


def test_the_third_failure_opens_the_breaker_and_alerts_once(sync_session, health_ready) -> None:
    alerts = Recorder()
    for _ in range(3):
        record_run(
            sync_session, source="livesoccertv", status="failed", items_found=0, finished_at=NOW, alert=alerts, now=NOW
        )

    failures, breaker, _, _ = _row(sync_session)
    assert failures == 3
    assert breaker is not None
    assert len(alerts.sent) == 1
    assert "livesoccertv" in alerts.sent[0]

    # A fourth failure keeps the breaker open without a second alert.
    record_run(
        sync_session, source="livesoccertv", status="failed", items_found=0, finished_at=NOW, alert=alerts, now=NOW
    )
    assert len(alerts.sent) == 1


def test_an_open_breaker_pauses_the_source(sync_session, health_ready) -> None:
    for _ in range(3):
        record_run(
            sync_session,
            source="livesoccertv",
            status="failed",
            items_found=0,
            finished_at=NOW,
            alert=Recorder(),
            now=NOW,
        )
    assert source_is_paused(sync_session, "livesoccertv", now=NOW) is True


def test_zero_items_with_pages_alerts_once_per_cairo_day(sync_session, health_ready) -> None:
    alerts = Recorder()
    record_run(
        sync_session,
        source="livesoccertv",
        status="succeeded",
        items_found=0,
        finished_at=NOW,
        pages=2,
        targets=1,
        alert=alerts,
        now=NOW,
    )
    assert len(alerts.sent) == 1
    assert "livesoccertv" in alerts.sent[0]
    assert _row(sync_session)[0] == 1

    record_run(
        sync_session,
        source="livesoccertv",
        status="succeeded",
        items_found=0,
        finished_at=NOW,
        pages=2,
        targets=1,
        alert=alerts,
        now=NOW,
    )
    assert len(alerts.sent) == 1  # same Cairo day: no second alarm

    tomorrow = datetime(2026, 11, 8, 12, 0, tzinfo=UTC)
    record_run(
        sync_session,
        source="livesoccertv",
        status="succeeded",
        items_found=0,
        finished_at=tomorrow,
        pages=2,
        targets=1,
        alert=alerts,
        now=tomorrow,
    )
    assert len(alerts.sent) == 2


def test_zero_items_without_pages_or_targets_is_not_an_alarm(sync_session, health_ready) -> None:
    alerts = Recorder()
    record_run(
        sync_session, source="livesoccertv", status="succeeded", items_found=0, finished_at=NOW, alert=alerts, now=NOW
    )
    assert alerts.sent == []
    assert _row(sync_session)[0] == 0


def test_every_run_bumps_the_sources_dataset(sync_session) -> None:
    """A13's ``ETag`` is built from ``sources``, so each run must move it (R12, R17)."""
    before = dataset_versions(sync_session)["sources"]
    record_run(
        sync_session,
        source="livesoccertv",
        status="succeeded",
        items_found=3,
        finished_at=NOW,
        alert=Recorder(),
        now=NOW,
    )
    assert dataset_versions(sync_session)["sources"] == before + 1


def test_before_the_migration_a_run_still_records_and_bumps(sync_session) -> None:
    """Without 0005 the health columns do not exist: the run is not lost (T068 turns this on)."""
    if column_available(sync_session, "sources", "consecutive_failures"):
        pytest.skip("0005 is applied: the guarded behaviour is tested above")
    before = dataset_versions(sync_session)["sources"]
    outcome = record_run(
        sync_session,
        source="livesoccertv",
        status="failed",
        items_found=0,
        finished_at=NOW,
        alert=Recorder(),
        now=NOW,
    )
    assert outcome.consecutive_failures == 0
    assert dataset_versions(sync_session)["sources"] == before + 1


def test_column_availability_is_asked_once_per_session(sync_session) -> None:
    assert health.column_available(sync_session, "sources", "name") is True
    assert health.column_available(sync_session, "sources", "no_such_column") is False
    assert sync_session.info["column:sources.no_such_column"] is False
