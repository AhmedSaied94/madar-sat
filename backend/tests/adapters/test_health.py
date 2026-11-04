"""The breaker, the zero-items alarm and the ``sources`` bump (T057, R17)."""

from __future__ import annotations

from datetime import UTC, datetime

import pytest
from sqlalchemy import text

from app.adapters.health import record_live_cycle, record_run, source_is_paused
from tests.adapters.helpers import dataset_versions

NOW = datetime(2026, 11, 7, 12, 0, tzinfo=UTC)


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


def test_a_failed_run_increments_the_failures(sync_session) -> None:
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


def test_a_success_resets_the_count_and_sets_last_success(sync_session) -> None:
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


def test_the_third_failure_opens_the_breaker_and_alerts_once(sync_session) -> None:
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


def test_an_open_breaker_pauses_the_source(sync_session) -> None:
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


def test_zero_items_with_pages_alerts_once_per_cairo_day(sync_session, monkeypatch: pytest.MonkeyPatch) -> None:
    # Keep the breaker out of this test: it is the alarm that is being measured.
    monkeypatch.setenv("SOURCE_BREAKER_THRESHOLD", "10")
    from app.adapters.config import get_adapter_settings

    get_adapter_settings.cache_clear()
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


def test_zero_items_without_pages_or_targets_is_not_an_alarm(sync_session) -> None:
    alerts = Recorder()
    record_run(
        sync_session, source="livesoccertv", status="succeeded", items_found=0, finished_at=NOW, alert=alerts, now=NOW
    )
    assert alerts.sent == []
    assert _row(sync_session)[0] == 0


def test_a_run_for_an_unknown_source_writes_nothing_but_keeps_the_bump(sync_session) -> None:
    """A source row is seeded in 0001; an unknown name never crashes the run's transaction."""
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
    assert outcome.consecutive_failures == 1
    assert dataset_versions(sync_session)["sources"] == before + 1


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


# --- record_live_cycle (D5 T045): the poller's health, with no breaker --------------------------


def _live_row(sync_session) -> tuple:
    # 0007 seeds the row; the insert keeps these tests independent of it.
    sync_session.execute(
        text("INSERT INTO sources (name, kind) VALUES ('live_poller', 'internal') ON CONFLICT (name) DO NOTHING")
    )
    return _live_values(sync_session)


def _live_values(sync_session) -> tuple:
    return sync_session.execute(
        text("SELECT consecutive_failures, breaker_opened_at, last_success_at FROM sources WHERE name = 'live_poller'")
    ).one()


def test_a_failed_live_cycle_counts_and_never_opens_the_breaker(sync_session) -> None:
    _live_row(sync_session)
    for _ in range(10):  # far past SOURCE_BREAKER_THRESHOLD
        record_live_cycle(sync_session, status="failed", items_found=0, finished_at=NOW)

    failures, breaker_opened_at, last_success_at = _live_values(sync_session)
    assert failures == 10
    assert breaker_opened_at is None
    assert last_success_at is None


def test_a_good_live_cycle_resets_the_count_and_moves_last_success(sync_session) -> None:
    _live_row(sync_session)
    record_live_cycle(sync_session, status="failed", items_found=0, finished_at=NOW)
    record_live_cycle(sync_session, status="succeeded", items_found=4, finished_at=NOW)

    assert _live_values(sync_session) == (0, None, NOW)


def test_a_cycle_with_no_items_and_no_failure_changes_nothing(sync_session) -> None:
    """The poller reports an empty page as ``failed`` itself; an idle cycle says nothing about health."""
    _live_row(sync_session)
    record_live_cycle(sync_session, status="failed", items_found=0, finished_at=NOW)
    record_live_cycle(sync_session, status="succeeded", items_found=0, finished_at=NOW)

    assert _live_values(sync_session) == (1, None, None)


def test_a_live_cycle_leaves_the_datasets_alone(sync_session) -> None:
    """One cycle a minute must not move A13's ``ETag``; the poller bumps when something changed."""
    _live_row(sync_session)
    before = dataset_versions(sync_session)
    record_live_cycle(sync_session, status="succeeded", items_found=4, finished_at=NOW)

    assert dataset_versions(sync_session) == before
