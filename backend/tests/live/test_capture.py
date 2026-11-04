"""The capture recorder and the robots check (T019, T034)."""

from __future__ import annotations

from datetime import UTC, datetime

import pytest

from app.adapters.base import RawPage
from app.adapters.config import AdapterSettings
from app.cli import build_parser, cmd_capture_live
from app.db.models import LiveProblem
from app.live.capture import Target, capture_once, output_path, run_capture, targets
from app.live.robots import FILGOAL_HOST, YALLAKORA_HOST, committed_copy
from app.live.robots_check import check_robots
from app.workers.base import Retryable

NOW = datetime(2026, 11, 4, 20, 15, 30, tzinfo=UTC)


def page(url: str, body: bytes = b"<html></html>") -> RawPage:
    return RawPage(url=url, status=200, body=body, content_type="text/html")


def test_both_lists_and_the_chosen_pages_are_targets():
    found = targets(["379130"], ["/egypt-cup/3066/match/114019/x#MC_MatcheDetails"])

    assert [(item.host, item.path) for item in found] == [
        (FILGOAL_HOST, "/matches/"),
        (YALLAKORA_HOST, "/matches-center"),
        (FILGOAL_HOST, "/matches/379130/coverage/"),
        (YALLAKORA_HOST, "/egypt-cup/3066/match/114019/x"),
    ]


def test_a_denied_path_fails_before_any_request():
    with pytest.raises(ValueError, match="off limits"):
        targets([], ["/x/Match/Matchsquad2"])


def test_the_output_layout_is_by_cairo_date_with_a_timestamp(tmp_path):
    late = datetime(2026, 11, 4, 23, 30, 5, tzinfo=UTC)  # already the 5th in Cairo

    path = output_path(tmp_path, Target("filgoal_list", FILGOAL_HOST, "/matches/"), late)

    assert path == tmp_path / "capture" / "2026-11-05" / "233005_filgoal_list.html"


def test_one_round_saves_every_page_and_survives_a_failure(tmp_path):
    items = targets(["1"], [])
    requested = []

    def fetch(url, host):
        requested.append((url, host))
        if url.endswith("/matches-center"):
            raise Retryable("answered 429")
        return page(url, b"<html>" + url.encode() + b"</html>")

    assert capture_once(items, fetch, tmp_path, NOW) == 2

    saved = sorted(path.name for path in (tmp_path / "capture" / "2026-11-04").iterdir())
    assert saved == ["201530_filgoal_1.html", "201530_filgoal_list.html"]
    assert len(requested) == 3


def test_it_records_once_a_minute_for_the_minutes_asked(tmp_path):
    waits = []

    saved = run_capture(
        targets([], []), lambda url, host: page(url), tmp_path, 3, clock=lambda: NOW, sleep=waits.append
    )

    assert saved == 6
    assert waits == [60.0, 60.0, 60.0]


def test_it_never_runs_without_a_user_agent(monkeypatch):
    monkeypatch.setattr("app.adapters.config.get_adapter_settings", lambda: AdapterSettings(SCRAPE_USER_AGENT=None))
    args = build_parser().parse_args(["capture-live", "--filgoal", "1", "--minutes", "1"])

    with pytest.raises(RuntimeError, match="SCRAPE_USER_AGENT"):
        cmd_capture_live(args)


def test_the_cli_takes_the_three_options():
    args = build_parser().parse_args(
        ["capture-live", "--filgoal", "1", "--filgoal", "2", "--yallakora", "/a/1/match/1/", "--minutes", "5"]
    )

    assert (args.filgoal, args.yallakora, args.minutes) == (["1", "2"], ["/a/1/match/1/"], 5)


def _robots(changed_host: str | None):
    def fetch(url, host):
        body = committed_copy(host)
        if host == changed_host:
            body += "\nDisallow: /new\n"
        return page(url, body.encode())

    return fetch


def test_a_changed_robots_file_opens_a_problem_once_then_recovers(sync_session):
    assert check_robots(sync_session, _robots(None), NOW) == []

    assert len(check_robots(sync_session, _robots(FILGOAL_HOST), NOW)) == 1
    assert check_robots(sync_session, _robots(FILGOAL_HOST), NOW) == []
    assert sync_session.get(LiveProblem, f"robots:{FILGOAL_HOST}").closed_at is None

    assert len(check_robots(sync_session, _robots(None), NOW)) == 1


def test_a_failed_robots_fetch_changes_nothing(sync_session):
    def fails(url, host):
        raise Retryable("answered 503")

    assert check_robots(sync_session, fails, NOW) == []


def test_the_task_modules_are_registered():
    from app.workers import SCHEDULE_MODULES, TASK_MODULES, load_beat_schedule

    assert "app.live.tasks" in TASK_MODULES
    assert "app.live.schedule" in SCHEDULE_MODULES
    schedule = load_beat_schedule("app.live.schedule")
    assert {entry["task"] for entry in schedule.values()} == {
        "live.scheduler",
        "live.watchdog",
        "live.prune_runs",
        "live.check_robots",
    }
