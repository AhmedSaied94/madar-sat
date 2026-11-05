"""The capture recorder and the robots check (T019, T034, spec 031 T021)."""

from __future__ import annotations

import functools
import gzip
import http.client
import json
import logging
from datetime import UTC, datetime, timedelta

import httpx
import pytest
import redis
from sqlalchemy import event

from app.adapters.base import RawPage
from app.adapters.config import AdapterSettings
from app.adapters.fetcher import FetchError
from app.cli import build_parser, cmd_capture_live, main
from app.db.models import LiveProblem
from app.db.session import sync_engine
from app.live.capture import (
    DEFAULT_PAGE_CAP,
    HEARTBEAT_KEY,
    LISTS,
    Target,
    capture_source,
    check_heartbeat,
    enabled_lists,
    output_path,
    run_capture,
)
from app.live.robots import FILGOAL_HOST, GOAL_HOST, YALLAKORA_HOST, committed_copy
from app.live.robots_check import check_robots
from app.live.sources import filgoal, goal, yallakora
from app.workers.base import Retryable
from tests.live.test_cycle import (
    FILGOAL_LIST,
    GOAL_LIST,
    LIVE,
    YALLAKORA_LIST,
    YK_LIVE,
    FakeRedis,
    filgoal_list,
    goal_list,
    yallakora_list,
)

NOW = datetime(2026, 11, 4, 20, 15, 30, tzinfo=UTC)
FILGOAL_PAGE = "https://www.filgoal.com/matches/f1/coverage/"
YALLAKORA_PAGE = "https://www.yallakora.com/league/1/match/y1/x"
GOAL_PAGE = "https://www.goal.com/ar-eg/match/x/g1"


def page(url: str, body: bytes = b"<html></html>") -> RawPage:
    return RawPage(url=url, status=200, body=body, content_type="text/html")


class Site:
    """A fake fetcher over all three sources. A value is a body, or an exception to raise."""

    def __init__(self):
        self.requests: list[str] = []
        self.pages: dict[str, bytes | Exception] = {
            FILGOAL_LIST: filgoal_list(("f1", 1, 0, LIVE)),
            YALLAKORA_LIST: yallakora_list(("y1", 1, 0, YK_LIVE)),
            GOAL_LIST: goal_list(("g1", 1, 0, "LIVE", "1H")),
            FILGOAL_PAGE: b"<html>f</html>",
            YALLAKORA_PAGE: b"<html>y</html>",
            GOAL_PAGE: b"<html>g</html>",
        }

    def __call__(self, url: str, host: str) -> RawPage:
        self.requests.append(url)
        value = self.pages[url]
        if isinstance(value, Exception):
            raise value
        return page(url, value)


class Timer:
    """The clock ``run_capture`` reads, moved on by the sleep it asks for."""

    def __init__(self):
        self.now = NOW
        self.waits: list[float] = []

    def __call__(self):
        return self.now

    def sleep(self, seconds: float):
        self.waits.append(seconds)
        self.now += timedelta(seconds=seconds)


class Run:
    def __init__(self, tmp_path):
        self.site = Site()
        self.root = tmp_path
        self.timer = Timer()
        self.redis = FakeRedis()
        self.alerts: list[str] = []

    def alert(self, text: str) -> bool:
        self.alerts.append(text)
        return True

    def __call__(self, minutes: int = 1, **values) -> int:
        return run_capture(
            LISTS,
            self.site,
            self.root,
            minutes,
            alert=self.alert,
            client=self.redis,
            clock=self.timer,
            sleep=self.timer.sleep,
            **values,
        )

    def saved(self) -> list[str]:
        return sorted(path.name for path in (self.root / "capture" / "2026-11-04").iterdir())

    def about(self, source: str) -> list[str]:
        return [text for text in self.alerts if source in text]


@pytest.fixture
def run(tmp_path):
    return Run(tmp_path)


def test_all_three_lists_are_read_and_live_match_pages_are_picked_with_no_ids_given(run):
    run()

    assert run.site.requests == [FILGOAL_LIST, FILGOAL_PAGE, YALLAKORA_LIST, YALLAKORA_PAGE, GOAL_LIST, GOAL_PAGE]
    assert run.saved() == [
        "201530_filgoal_f1.html.gz",
        "201530_filgoal_list.html.gz",
        "201530_goal_g1.html.gz",
        "201530_goal_list.html.gz",
        "201530_yallakora_list.html.gz",
        "201530_yallakora_y1.html.gz",
    ]


def test_a_match_that_is_not_being_played_gets_no_page(run):
    run.site.pages[FILGOAL_LIST] = filgoal_list(("f1", "-", "-", "لم تبدأ"), ("f2", 1, 0, "انتهت"))

    run()

    assert not any("/matches/f" in url for url in run.site.requests)


def test_a_row_with_an_unknown_status_gets_a_page_as_it_may_be_extra_time(run):
    run.site.pages[FILGOAL_LIST] = filgoal_list(("f1", 1, 1, "شوط إضافي"))

    run()

    assert FILGOAL_PAGE in run.site.requests


def test_pages_stop_at_the_cap_for_each_source(run):
    run.site.pages[FILGOAL_LIST] = filgoal_list(("f1", 1, 0, LIVE), ("f2", 1, 0, LIVE), ("f3", 1, 0, LIVE))
    run.site.pages["https://www.filgoal.com/matches/f2/coverage/"] = b"<html></html>"

    run(page_cap=2)

    assert [url for url in run.site.requests if "/coverage/" in url] == [
        FILGOAL_PAGE,
        "https://www.filgoal.com/matches/f2/coverage/",
    ]


def test_the_cli_defaults_are_the_ones_the_disk_figure_assumes():
    args = build_parser().parse_args(["capture-live"])

    assert (args.minutes, args.page_cap) == (240, DEFAULT_PAGE_CAP)


def test_pages_are_saved_gzipped(run):
    run()

    saved = run.root / "capture" / "2026-11-04" / "201530_filgoal_f1.html.gz"
    assert gzip.decompress(saved.read_bytes()) == b"<html>f</html>"


def test_an_id_from_a_page_cannot_leave_the_capture_folder(tmp_path):
    target = Target("goal_x", GOAL_HOST, "/a")
    assert output_path(tmp_path, target, NOW).parent == tmp_path / "capture" / "2026-11-04"

    site = Site()
    site.pages[GOAL_LIST] = goal_list(("../../evil", 1, 0, "LIVE", "1H"))
    site.pages["https://www.goal.com/ar-eg/match/x/evil"] = b"<html></html>"

    capture_source(next(item for item in LISTS if item.name == "goal"), site, tmp_path, lambda: NOW, 12)

    assert all(path.parent.name == "2026-11-04" for path in tmp_path.rglob("*.gz"))


def test_the_output_layout_is_by_cairo_date_with_a_timestamp(tmp_path):
    late = datetime(2026, 11, 4, 23, 30, 5, tzinfo=UTC)  # already the 5th in Cairo

    path = output_path(tmp_path, Target("filgoal_list", FILGOAL_HOST, "/matches/"), late)

    assert path == tmp_path / "capture" / "2026-11-05" / "233005_filgoal_list.html.gz"


def test_a_page_the_deny_list_covers_is_not_requested(run):
    run.site.pages[YALLAKORA_LIST] = yallakora_list(("y1", 1, 0, YK_LIVE)).replace(
        b"/league/1/match/y1/x", b"/x/Match/Matchsquad2"
    )

    run()

    assert not any("Matchsquad2" in url for url in run.site.requests)


READ_ERRORS = {
    "incomplete_read": http.client.IncompleteRead(b"partial"),
    "retryable": Retryable("answered 503"),
    "fetch_error": FetchError("answered 404", status=404),
    "httpx": httpx.ConnectError("no route"),
    "os_error": OSError("reset"),
    "anything_else": RuntimeError("redis went away"),
}


@pytest.mark.parametrize("error", READ_ERRORS.values(), ids=READ_ERRORS.keys())
def test_a_read_error_of_any_kind_is_logged_and_the_next_page_goes_on(run, error, caplog):
    run.site.pages[FILGOAL_PAGE] = error

    run()

    assert YALLAKORA_LIST in run.site.requests
    assert GOAL_PAGE in run.site.requests
    assert "capture_failed" in caplog.text


@pytest.mark.parametrize("error", READ_ERRORS.values(), ids=READ_ERRORS.keys())
def test_a_list_read_error_stops_no_other_source(run, error):
    run.site.pages[FILGOAL_LIST] = error

    run()

    assert YALLAKORA_LIST in run.site.requests
    assert GOAL_LIST in run.site.requests


def test_a_list_that_cannot_be_parsed_is_still_saved_and_the_capture_goes_on(run, caplog):
    run.site.pages[FILGOAL_LIST] = b"<html><body>Just a moment...</body></html>"

    run()

    assert "201530_filgoal_list.html.gz" in run.saved()
    assert GOAL_PAGE in run.site.requests
    assert "capture_list_not_parsed" in caplog.text


def test_it_records_once_a_minute_for_the_minutes_asked(run):
    saved = run(3)

    assert saved == 18
    assert run.timer.waits == [60.0, 60.0, 60.0]


def test_a_slow_round_counts_against_its_minute(run):
    real = run.site

    def slow(url, host):
        run.timer.now += timedelta(seconds=7)
        return real(url, host)

    run.site = slow

    run(1)

    assert run.timer.waits == [60.0 - 6 * 7]


def test_a_round_longer_than_its_minute_does_not_wait(run):
    real = run.site

    def slow(url, host):
        run.timer.now += timedelta(seconds=30)
        return real(url, host)

    run.site = slow

    run(1)

    assert run.timer.waits == [0.0]


# ---------------------------------------------------------------------------------------------- alerts


def test_it_alerts_at_the_start_naming_its_end_and_at_the_end(run):
    run(3)

    assert len(run.alerts) == 2
    assert "22:18" in run.alerts[0]  # 20:15:30 UTC + 3 minutes, in Cairo
    assert "انتهى" in run.alerts[1]


def _script_lists(run, source_url, bodies):
    """Serve ``bodies`` for one list, a round at a time; the last repeats."""
    real = run.site
    queue = list(bodies)

    def fetch(url, host):
        if url == source_url:
            real.requests.append(url)
            value = queue.pop(0) if len(queue) > 1 else queue[0]
            if isinstance(value, Exception):
                raise value
            return page(url, value)
        return real(url, host)

    run.site = fetch


def test_a_source_failing_five_rounds_sends_one_alert_and_one_on_recovery(run):
    fine = filgoal_list(("f1", 1, 0, LIVE))
    _script_lists(run, FILGOAL_LIST, [Retryable("answered 503")] * 7 + [fine])

    run(10)

    about = run.about("filgoal")
    assert len(about) == 2
    assert "5" in about[0]


def test_four_failed_rounds_send_nothing(run):
    fine = filgoal_list(("f1", 1, 0, LIVE))
    _script_lists(run, FILGOAL_LIST, [http.client.IncompleteRead(b"x")] * 4 + [fine])

    run(10)

    assert run.about("filgoal") == []


def test_a_failure_streak_must_be_in_a_row(run):
    fine = filgoal_list(("f1", 1, 0, LIVE))
    bad = httpx.ConnectError("no route")
    _script_lists(run, FILGOAL_LIST, [bad, bad, bad, bad, fine, bad, bad, bad, bad, fine])

    run(10)

    assert run.about("filgoal") == []


def test_a_source_quiet_for_five_rounds_while_another_shows_live_rows_alerts_once_and_on_recovery(run):
    quiet = filgoal_list(("f1", 1, 0, "لم تبدأ"))
    live = filgoal_list(("f1", 1, 0, LIVE))
    _script_lists(run, FILGOAL_LIST, [quiet] * 7 + [live])

    run(10)

    about = run.about("filgoal")
    assert len(about) == 2
    assert "جارية" in about[0]


def test_an_unknown_status_counts_as_quiet(run):
    """That's what a changed wording looks like during a capture."""
    _script_lists(run, FILGOAL_LIST, [filgoal_list(("f1", 1, 0, "حالة جديدة"))])

    run(6)

    assert len(run.about("filgoal")) == 1


def test_no_source_showing_live_rows_is_not_quiet(run):
    run.site.pages[FILGOAL_LIST] = filgoal_list(("f1", 1, 0, "انتهت"))
    run.site.pages[YALLAKORA_LIST] = yallakora_list(("y1", 1, 0, "انتهت"))
    run.site.pages[GOAL_LIST] = goal_list(("g1", 1, 0, "RESULT", None))

    run(10)

    assert len(run.alerts) == 2  # the start and the end


def test_a_failed_read_is_not_quiet(run):
    _script_lists(run, FILGOAL_LIST, [httpx.ConnectError("no route")] * 4 + [filgoal_list(("f1", 1, 0, LIVE))])

    run(10)

    assert run.about("filgoal") == []


# ------------------------------------------------------------------------------------------- a refusal

SECOND_PAGE = "https://www.filgoal.com/matches/f2/coverage/"
REFUSALS = {"forbidden": f"{FILGOAL_PAGE} answered 403", "too_many": f"{FILGOAL_PAGE} answered 429"}


@pytest.mark.parametrize("message", REFUSALS.values(), ids=REFUSALS.keys())
def test_a_refused_match_page_ends_that_sources_round_and_tells_the_owner_at_once(run, message):
    run.site.pages[FILGOAL_LIST] = filgoal_list(("f1", 1, 0, LIVE), ("f2", 1, 0, LIVE))
    run.site.pages[FILGOAL_PAGE] = Retryable(message)
    run.site.pages[SECOND_PAGE] = b"<html></html>"

    run()

    assert SECOND_PAGE not in run.site.requests
    assert YALLAKORA_PAGE in run.site.requests
    assert GOAL_PAGE in run.site.requests
    assert len(run.about("filgoal")) == 1


def test_a_refused_list_ends_that_sources_round_and_tells_the_owner_at_once(run):
    run.site.pages[FILGOAL_LIST] = Retryable(f"{FILGOAL_LIST} answered 403")

    run()

    assert FILGOAL_PAGE not in run.site.requests
    assert GOAL_PAGE in run.site.requests
    assert len(run.about("filgoal")) == 1


@pytest.mark.parametrize("refused", [FILGOAL_LIST, FILGOAL_PAGE], ids=["list", "match_page"])
def test_refused_in_the_next_round_too_the_source_gets_nothing_more_until_a_restart(run, refused):
    run.site.pages[refused] = Retryable(f"{refused} answered 403")

    run(10)

    assert run.site.requests.count(refused) == 2
    assert run.site.requests.count(YALLAKORA_LIST) == 10
    assert sum("filgoal" in url for url in run.site.requests[-20:]) == 0
    assert len(run.about("filgoal")) == 2
    assert run.alerts[-1].startswith("انتهى")


def test_a_refused_round_followed_by_a_clean_one_goes_on_and_says_so(run):
    fine = filgoal_list(("f1", 1, 0, LIVE))
    site = run.site
    _script_lists(run, FILGOAL_LIST, [Retryable(f"{FILGOAL_LIST} answered 429"), fine])

    run(4)

    assert site.requests.count(FILGOAL_LIST) == 4
    about = run.about("filgoal")
    assert len(about) == 2
    assert "عاد" in about[1]


def test_two_refusals_with_a_clean_round_between_them_do_not_stop_the_source(run):
    fine = filgoal_list(("f1", 1, 0, LIVE))
    refused = Retryable(f"{FILGOAL_LIST} answered 403")
    site = run.site
    _script_lists(run, FILGOAL_LIST, [refused, fine, refused, fine])

    run(6)

    assert site.requests.count(FILGOAL_LIST) == 6


NOT_REFUSALS = {
    "server_error": Retryable(f"{FILGOAL_LIST} answered 503"),
    "empty_bucket": Retryable("rate limit reached for www.filgoal.com"),
    "dropped_connection": http.client.IncompleteRead(b"partial"),
    "not_found": FetchError("answered 404", status=404),
}


@pytest.mark.parametrize("error", NOT_REFUSALS.values(), ids=NOT_REFUSALS.keys())
def test_anything_short_of_a_refusal_stays_a_logged_failure(run, error):
    run.site.pages[FILGOAL_LIST] = error

    run(4)

    assert run.site.requests.count(FILGOAL_LIST) == 4
    assert run.about("filgoal") == []


def test_a_url_that_only_looks_like_a_refusal_is_not_one(run):
    run.site.pages[FILGOAL_LIST] = Retryable("https://www.filgoal.com/answered 403/x answered 503")

    run(2)

    assert run.site.requests.count(FILGOAL_LIST) == 2
    assert run.about("filgoal") == []


# ------------------------------------------------------------------------------------------- heartbeat


def test_each_round_writes_its_time_and_a_normal_end_deletes_the_key(run):
    beats = []
    real = run.redis.set

    def spy(key, value, **kwargs):
        beats.append((key, value))
        return real(key, value, **kwargs)

    run.redis.set = spy

    run(2)

    assert {key for key, _ in beats} == {HEARTBEAT_KEY}
    assert datetime.fromisoformat(beats[0][1]) == NOW
    assert any(datetime.fromisoformat(value) == NOW + timedelta(seconds=60) for _, value in beats)
    assert run.redis.get(HEARTBEAT_KEY) is None


def test_a_capture_that_dies_leaves_its_key_for_the_watchdog(run):
    def dies(url, host):
        raise KeyboardInterrupt

    run.site = dies

    with pytest.raises(KeyboardInterrupt):
        run()

    assert run.redis.get(HEARTBEAT_KEY) is not None


class BrokenRedis(FakeRedis):
    def set(self, *_, **__):
        raise redis.ConnectionError("gone")

    def delete(self, *_):
        raise redis.ConnectionError("gone")


def test_a_failed_heartbeat_is_logged_and_the_capture_goes_on(run, caplog):
    run.redis = BrokenRedis()

    assert run(1) == 6
    assert "capture_heartbeat_failed" in caplog.text
    assert "انتهى" in run.alerts[-1]


def _sent():
    sent: list[str] = []

    def alert(text: str) -> bool:
        sent.append(text)
        return True

    return sent, alert


def test_a_stopped_capture_sends_one_alert_when_its_key_is_over_five_minutes_old():
    client = FakeRedis()
    client.set(HEARTBEAT_KEY, (NOW - timedelta(minutes=5, seconds=1)).isoformat())
    sent, alert = _sent()

    assert check_heartbeat(client, NOW, alert) is True
    assert check_heartbeat(client, NOW + timedelta(minutes=2), alert) is False
    assert len(sent) == 1


@pytest.mark.parametrize(
    "age", [timedelta(seconds=30), timedelta(minutes=5)], ids=["fresh", "exactly_five_minutes_old"]
)
def test_a_fresh_key_sends_nothing(age):
    client = FakeRedis()
    client.set(HEARTBEAT_KEY, (NOW - age).isoformat())
    sent, alert = _sent()

    assert check_heartbeat(client, NOW, alert) is False
    assert sent == []
    assert client.get(HEARTBEAT_KEY) is not None


def test_no_key_sends_nothing():
    sent, alert = _sent()

    assert check_heartbeat(FakeRedis(), NOW, alert) is False
    assert sent == []


def test_bytes_from_redis_are_read():
    client = FakeRedis()
    client.set(HEARTBEAT_KEY, (NOW - timedelta(minutes=9)).isoformat().encode())
    sent, alert = _sent()

    assert check_heartbeat(client, NOW, alert) is True
    assert len(sent) == 1


def test_an_alert_that_did_not_go_keeps_the_key_for_the_next_check():
    client = FakeRedis()
    client.set(HEARTBEAT_KEY, (NOW - timedelta(minutes=9)).isoformat())

    assert check_heartbeat(client, NOW, lambda text: False) is False
    assert client.get(HEARTBEAT_KEY) is not None


def test_a_broken_redis_stops_no_watchdog(caplog):
    class Broken(FakeRedis):
        def get(self, key):
            raise redis.ConnectionError("gone")

    assert check_heartbeat(Broken(), NOW, lambda text: True) is False
    assert "capture_heartbeat_not_checked" in caplog.text


# ------------------------------------------------------------------------------------------------- rest


def test_it_writes_nothing_to_the_database(run):
    statements = []

    def seen(conn, cursor, statement, *_):
        statements.append(statement)

    event.listen(sync_engine, "before_cursor_execute", seen)
    try:
        run(2)
    finally:
        event.remove(sync_engine, "before_cursor_execute", seen)

    assert statements == []


def test_goal_com_switched_off_gets_no_request():
    assert [item.name for item in enabled_lists(goal_enabled=False)] == [filgoal.SOURCE, yallakora.SOURCE]
    assert [item.name for item in enabled_lists(goal_enabled=True)] == [filgoal.SOURCE, yallakora.SOURCE, goal.SOURCE]


def test_it_never_runs_without_a_user_agent(monkeypatch):
    monkeypatch.setattr("app.adapters.config.get_adapter_settings", lambda: AdapterSettings(SCRAPE_USER_AGENT=None))
    args = build_parser().parse_args(["capture-live", "--minutes", "1"])

    with pytest.raises(RuntimeError, match="SCRAPE_USER_AGENT"):
        cmd_capture_live(args)


@pytest.fixture
def root_logging():
    """``setup_logging`` replaces the root logger's handlers, which later tests' ``caplog`` relies on."""
    root = logging.getLogger()
    handlers, level = root.handlers[:], root.level
    yield
    root.handlers[:] = handlers
    root.setLevel(level)


def test_a_failed_page_reaches_the_commands_output_with_its_page_and_why(tmp_path, monkeypatch, capsys, root_logging):
    """Through the real entry point: Celery's signal never fires here, and the report needs these fields."""

    class Fetcher:
        def __init__(self, *_, **__):
            pass

        def __enter__(self):
            return self

        def __exit__(self, *_):
            return False

        def get(self, url, *, allowed_hosts):
            raise Retryable(f"{url} answered 503")

    class Client(FakeRedis):
        def close(self):
            pass

    timer = Timer()
    settings = AdapterSettings(SCRAPE_USER_AGENT="madar-test", RAW_ROOT=tmp_path)
    monkeypatch.setattr("app.adapters.config.get_adapter_settings", lambda: settings)
    monkeypatch.setattr("app.adapters.fetcher.HttpFetcher", Fetcher)
    monkeypatch.setattr("app.adapters.ratelimit.RateLimiter", lambda client: None)
    monkeypatch.setattr("app.adapters.alerts.send_alert", lambda text: True)
    monkeypatch.setattr("redis.Redis.from_url", lambda url: Client())
    monkeypatch.setattr("app.live.capture.run_capture", functools.partial(run_capture, clock=timer, sleep=timer.sleep))

    assert main(["capture-live", "--minutes", "1"]) == 0

    records = [json.loads(line) for line in capsys.readouterr().out.splitlines() if line.startswith("{")]
    failure = next(record for record in records if record["message"] == "capture_failed")
    assert failure["page"] == "filgoal_list"
    assert "answered 503" in failure["why"]


def test_the_cli_takes_the_minutes_and_the_cap_and_no_ids():
    args = build_parser().parse_args(["capture-live", "--minutes", "240", "--page-cap", "4"])

    assert (args.minutes, args.page_cap) == (240, 4)
    with pytest.raises(SystemExit):
        build_parser().parse_args(["capture-live", "--filgoal", "1"])


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


def test_switched_off_goal_com_gets_no_robots_request(sync_session):
    hosts = []

    def fetch(url, host):
        hosts.append(host)
        return page(url, committed_copy(host).encode())

    check_robots(sync_session, fetch, NOW, goal_enabled=False)

    assert hosts == [FILGOAL_HOST, YALLAKORA_HOST]


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
