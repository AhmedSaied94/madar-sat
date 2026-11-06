"""One cycle against a fake fetcher and real PostgreSQL (T027)."""

from __future__ import annotations

import json
import re
from datetime import UTC, datetime, timedelta
from pathlib import Path

import httpx
import pytest
from sqlalchemy import select, update
from sqlalchemy.exc import OperationalError
from sqlalchemy.orm import Session

from app.adapters.base import RawPage
from app.adapters.fetcher import FetchError
from app.adapters.health import record_live_cycle
from app.adapters.raw_store import RawStore, read_page
from app.adapters.unresolved import record_unresolved
from app.db.models import (
    ImportRun,
    LiveProblem,
    LiveSourceState,
    MatchEvent,
    MatchExternalId,
    MatchLineup,
    MatchSourceReading,
    MatchStats,
    NotificationOutbox,
    Source,
    Team,
    UnresolvedName,
)
from app.db.session import sync_engine
from app.live import cycle as cycle_module
from app.live.backoff import Backoff, PageHashes, next_delay
from app.live.config import LiveSettings
from app.live.cycle import Deps, OutOfTokens, delete_old_runs, run_cycle
from app.live.cycle import has_work_in as has_work_within
from app.live.sources import filgoal, goal, yallakora
from app.live.types import LayoutChanged
from app.workers.base import Retryable
from tests.live.helpers import make_match, version

NOW = datetime(2026, 11, 4, 20, 0, tzinfo=UTC)
KICKOFF = NOW - timedelta(minutes=30)
FILGOAL_LIST = "https://www.filgoal.com/matches/"
YALLAKORA_LIST = "https://www.yallakora.com/matches-center"
GOAL_LIST = f"https://{goal.HOST}{goal.LIST_PATH}"
FIXTURES = Path(__file__).parent / "fixtures"
LIVE = "الشوط الاول"
YK_LIVE = "الشوط الأول"


def filgoal_list(*rows) -> bytes:
    items = "".join(
        f'<li data-match-id="{id_}"><a href="/matches/{id_}/x"><h6>دوري</h6><div><b class="home-score">{h}</b>'
        f'<div><span>أ</span></div><p><span class="status">{status}</span><span class="time">22:00</span></p>'
        f'<b class="away-score">{a}</b><div><span>ب</span></div></div></a></li>'
        for id_, h, a, status in rows
    )
    return f'<html><body><div id="match-slider-holder"><ul>{items}</ul></div></body></html>'.encode()


def yallakora_list(*rows) -> bytes:
    items = "".join(
        f'<div livescorematchid="{id_}" class="item"><a href="/league/1/match/{id_}/x#MC">'
        f'<div class="matchStatus"><span>{status}</span></div><div class="teamsData">'
        f'<div class="teamA"><p>أ</p></div><div class="MResult"><span class="score">{h}</span>'
        f'<span class="score">{a}</span><span class="time">22:00</span></div><div class="teamB"><p>ب</p></div>'
        "</div></a></div>"
        for id_, h, a, status in rows
    )
    return (
        '<html><body><section class="matchesCenter"><div class="matchCard"><div class="title">'
        f'<a class="tourTitle"><h2>دوري</h2></a></div>{items}</div></section></body></html>'
    ).encode()


GOAL_LIVE = {"1H": {"type": "FIRST_HALF", "minute": 20}, "2H": {"type": "SECOND_HALF", "minute": 70}}


def goal_list(*rows) -> bytes:
    """Rows of ``(id, home, away, status, period)``, with the link the real list has for each."""
    matches = [
        {
            "id": id_,
            "status": status,
            "period": GOAL_LIVE.get(period),
            "score": {"teamA": h, "teamB": a},
            "startDate": "2026-11-04T19:30:00.000Z",
            "teamA": {"name": "أ"},
            "teamB": {"name": "ب"},
        }
        for id_, h, a, status, period in rows
    ]
    links = "".join(f'<a href="/ar-eg/match/x/{id_}">x</a>' for id_, *_ in rows)
    groups = [{"competition": {"name": "دوري"}, "matches": matches}]
    blob = json.dumps({"props": {"pageProps": {"content": {"liveScores": groups}}}}, ensure_ascii=False)
    script = f'<script id="__NEXT_DATA__" type="application/json">{blob}</script>'
    return f"<html><body>{script}{links}</body></html>".encode()


def goal_page(id_="g1", *, stats=None) -> bytes:
    match = {
        "id": id_,
        "status": "LIVE",
        "period": GOAL_LIVE["1H"],
        "score": {"teamA": 1, "teamB": 0},
        "startDate": "2026-11-04T19:30:00.000Z",
        "teamA": {"name": "أ"},
        "teamB": {"name": "ب"},
        "events": [
            {
                "type": "GOAL",
                "side": "TEAM_A",
                "period": {"minute": 12},
                "scorer": {"id": "p1", "name": "لاعب"},
            }
        ],
        "stats": {"summary": stats or []},
    }
    blob = json.dumps({"props": {"pageProps": {"content": {"match": match}}}}, ensure_ascii=False)
    return f'<html><body><script id="__NEXT_DATA__" type="application/json">{blob}</script></body></html>'.encode()


class Pages:
    """A fake fetcher. A value is a body, or an exception to raise."""

    def __init__(self, **_):
        self.pages: dict[str, bytes | Exception] = {}
        self.requests: list[str] = []

    def both(self, home: int | str = 0, away: int | str = 0, *, other=None):
        other_home, other_away = other if other is not None else (home, away)
        self.pages[FILGOAL_LIST] = filgoal_list(("f1", home, away, LIVE))
        self.pages[YALLAKORA_LIST] = yallakora_list(("y1", other_home, other_away, YK_LIVE))
        return self

    def goal(self, home: int = 0, away: int = 0, *, status="LIVE", period="1H"):
        self.pages[GOAL_LIST] = goal_list(("g1", home, away, status, period))
        return self

    def __call__(self, url: str, host: str) -> RawPage:
        self.requests.append(url)
        value = self.pages[url]
        if isinstance(value, Exception):
            raise value
        return RawPage(url=url, status=200, body=value, content_type="text/html")


class FakeRedis:
    def __init__(self):
        self.values: dict[str, object] = {}
        self.expiries: dict[str, int] = {}

    def exists(self, key):
        return int(key in self.values)

    def incr(self, key):
        self.values[key] = int(self.values.get(key, 0)) + 1
        return self.values[key]

    def expire(self, key, seconds):
        self.expiries[key] = seconds

    def set(self, key, value, ex=None, nx=False):
        if nx and key in self.values:
            return False
        self.values[key] = value
        if ex is not None:
            self.expiries[key] = ex
        return True

    def get(self, key):
        return self.values.get(key)

    def delete(self, *keys):
        for key in keys:
            self.values.pop(key, None)

    def eval(self, *_):
        return 1

    def close(self):
        return None


class Clock:
    def __init__(self):
        self.now = NOW

    def __call__(self):
        return self.now

    def tick(self, seconds=60):
        self.now += timedelta(seconds=seconds)


@pytest.fixture
def factory(_prepare_database):
    """Sessions over one connection in a transaction: they commit to savepoints, then all rolls back."""
    with sync_engine.connect() as conn:
        trans = conn.begin()
        try:
            yield lambda: Session(
                bind=conn, join_transaction_mode="create_savepoint", autoflush=False, expire_on_commit=False
            )
        finally:
            trans.rollback()


class World:
    def __init__(self, factory, tmp_path):
        self.factory = factory
        self.fetch = Pages().both()
        self.redis = FakeRedis()
        self.alerts: list[str] = []
        self.health: list[dict] = []
        self.unresolved: list[dict] = []
        self.clock = Clock()
        self.raw_root = tmp_path
        self.caps = {
            "LIVE_PAGE_CAP_FILGOAL": 0,
            "LIVE_PAGE_CAP_YALLAKORA": 0,
            "LIVE_PAGE_CAP_GOAL": 0,
            "LIVE_GOAL_ENABLED": False,
        }

    def deps(self, **changes) -> Deps:
        values = {
            "session_factory": self.factory,
            "fetch": self.fetch,
            "backoff": Backoff(self.redis, jitter=lambda: 0.0),
            "hashes": PageHashes(self.redis),
            "raw_store": RawStore(self.raw_root),
            "alert": self._alert,
            "settings": LiveSettings(**self.caps),
            "record_unresolved": lambda session, **v: self.unresolved.append(v),
            "record_live_cycle": lambda session, **v: self.health.append(v),
            "clock": self.clock,
            "monotonic": lambda: 0.0,
        }
        return Deps(**{**values, **changes})

    def _alert(self, text: str) -> bool:
        self.alerts.append(text)
        return True

    def run(self, **changes):
        result = run_cycle(self.deps(**changes))
        self.clock.tick()
        return result

    def add_match(self, kickoff=KICKOFF, **values):
        with self.factory() as session, session.begin():
            match = make_match(session, kickoff, **values)
            session.add(MatchExternalId(source="filgoal", external_id="f1", match_id=match.id))
            session.add(MatchExternalId(source="yallakora", external_id="y1", match_id=match.id))
            session.add(MatchExternalId(source="goal", external_id="g1", match_id=match.id))
            return match.id

    def with_goal(self, *values, **changes):
        self.caps["LIVE_GOAL_ENABLED"] = True
        self.fetch.goal(*values, **changes)
        return self

    def match(self, match_id):
        from app.db.models import Match

        with self.factory() as session:
            return session.get(Match, match_id)

    def rows(self, model):
        with self.factory() as session:
            return session.scalars(select(model)).all()

    def last_run(self):
        return max(self.rows(ImportRun), key=lambda run: run.id)

    def problem(self, key):
        with self.factory() as session:
            return session.get(LiveProblem, key)

    def source_state(self, source):
        with self.factory() as session:
            return session.get(LiveSourceState, source)

    def live_version(self):
        with self.factory() as session:
            return version(session, "live")


@pytest.fixture
def world(factory, tmp_path):
    return World(factory, tmp_path)


def has_work_in(factory, now):
    return has_work_within(factory, now, stuck_after=LiveSettings().stuck_after)


def test_both_sources_agreeing_put_the_score_on_the_row(world):
    match_id = world.add_match()
    world.fetch.both(1, 0)
    before = world.live_version()

    # The first 1–0 with nothing confirmed is news from two sources at once.
    world.run()

    row = world.match(match_id)
    assert (row.status_source, row.status, row.period, row.home_score, row.away_score) == ("feed", "live", "1H", 1, 0)
    assert world.live_version() == before + 1
    assert world.alerts == []


def test_a_match_with_no_opened_page_takes_status_and_score_from_the_lists(world):
    match_id = world.add_match()
    world.fetch.both(0, 0)

    world.run()

    assert world.match(match_id).minute is None
    assert world.rows(MatchEvent) == []
    assert world.rows(MatchLineup) == []
    assert world.match(match_id).status == "live"


def test_one_source_ahead_goes_out_at_once(world):
    match_id = world.add_match()
    world.run()

    world.fetch.both(1, 0, other=(0, 0))
    world.run()

    assert world.match(match_id).home_score == 1


def test_a_disagreement_alerts_once_after_the_wait_and_closes_on_agreement(world):
    match_id = world.add_match()
    world.run()
    world.fetch.both(1, 0, other=(0, 0))

    for _ in range(11):
        world.run()

    disagreement = [text for text in world.alerts if str(match_id) in text]
    assert len(disagreement) == 1
    assert world.match(match_id).home_score == 1
    assert world.problem(f"disagree:{match_id}").closed_at is None

    world.fetch.both(1, 0)
    world.run()

    assert world.problem(f"disagree:{match_id}").closed_at is not None
    assert len([text for text in world.alerts if str(match_id) in text]) == 2
    assert world.match(match_id).home_score == 1


def test_one_alert_per_problem_across_restarts_then_one_on_recovery(world):
    world.add_match()
    world.fetch.pages[FILGOAL_LIST] = b"<html><body>Just a moment...</body></html>"

    world.run()
    world.run()  # a new Deps each time: nothing is kept in the worker
    world.run()

    assert len([text for text in world.alerts if "filgoal" in text]) == 1
    assert world.problem("format:filgoal").closed_at is None

    world.fetch.both()
    world.run()

    assert world.problem("format:filgoal").closed_at is not None
    assert len([text for text in world.alerts if "filgoal" in text]) == 2


def test_a_quiet_window_sends_no_request(world):
    world.add_match(kickoff=NOW + timedelta(hours=5))

    assert run_cycle(world.deps()) == {"skipped": "no_matches"}
    assert has_work_in(world.factory, NOW) is False

    assert world.fetch.requests == []
    assert world.rows(ImportRun) == []


def test_the_scheduler_sees_a_match_in_the_window(world):
    world.add_match()

    assert has_work_in(world.factory, NOW) is True


def _pause(world):
    with world.factory() as session, session.begin():
        session.execute(
            update(Source).where(Source.name == "live_poller").values(paused_until=NOW + timedelta(hours=1))
        )


def test_a_pause_acts_as_both_down_with_no_alert_and_no_request(world):
    match_id = world.add_match()
    world.fetch.both(2, 1)
    world.run()
    assert world.match(match_id).home_score == 2
    _pause(world)
    requests = len(world.fetch.requests)
    before = world.live_version()

    assert has_work_in(world.factory, world.clock()) is False
    assert run_cycle(world.deps()) == {"skipped": "paused"}

    row = world.match(match_id)
    assert (row.status_source, row.home_score) == ("clock", None)
    assert world.live_version() == before + 1
    assert world.alerts == []
    assert len(world.fetch.requests) == requests
    assert world.problem("both_down") is None


def test_a_changed_format_gives_no_wrong_score(world):
    match_id = world.add_match()
    world.run()
    # Not a status any more, and not a score either: the page has changed shape.
    world.fetch.pages[FILGOAL_LIST] = b"<html><body>Just a moment...</body></html>"
    world.fetch.pages[YALLAKORA_LIST] = yallakora_list(("y1", 0, 0, YK_LIVE))

    world.run()
    world.run()

    row = world.match(match_id)
    assert (row.home_score, row.away_score) == (0, 0)
    assert world.source_state("filgoal").state == "invalid"
    assert world.problem("format:filgoal").raw_ref is not None


@pytest.mark.parametrize("status", [429, 403, 503])
def test_a_blocked_host_backs_off_and_the_cycle_skips_it_and_counts_a_failure(world, status):
    world.add_match()
    world.fetch.pages[FILGOAL_LIST] = Retryable(f"answered {status}")

    world.run()
    assert world.redis.exists("live:backoff:www.filgoal.com")
    assert world.redis.expiries["live:backoff:www.filgoal.com"] == 60
    assert world.source_state("filgoal").consecutive_failures == 1

    world.run()
    assert world.fetch.requests.count(FILGOAL_LIST) == 1
    assert world.source_state("filgoal").consecutive_failures == 2

    assert world.fetch.requests.count(YALLAKORA_LIST) == 2


def test_backoff_doubles_and_is_capped_with_jitter():
    assert [next_delay(n, lambda: 0.0) for n in (1, 2, 3, 4, 5, 9)] == [60, 120, 240, 480, 600, 600]
    assert next_delay(9, lambda: 1.0) == 300


def test_a_success_clears_the_backoff(world):
    world.add_match()
    world.fetch.pages[FILGOAL_LIST] = Retryable("answered 429")
    world.run()
    world.redis.delete("live:backoff:www.filgoal.com")
    world.fetch.both()

    world.run()

    assert not world.redis.exists("live:backoff:www.filgoal.com:strikes")
    assert world.source_state("filgoal").state == "ok"


@pytest.mark.parametrize("error", [FetchError("answered 404", status=404), httpx.ConnectError("no route")])
def test_other_failures_count_without_a_backoff(world, error):
    world.add_match()
    world.fetch.pages[FILGOAL_LIST] = error

    world.run()

    assert not world.redis.exists("live:backoff:www.filgoal.com")
    assert world.source_state("filgoal").state == "failing"


def test_running_out_of_tokens_is_not_a_failure(world):
    world.add_match()
    world.fetch.pages[FILGOAL_LIST] = OutOfTokens("rate limit reached")

    world.run()

    state = world.source_state("filgoal")
    assert state is None or state.consecutive_failures == 0
    assert "filgoal:list" in world.last_run().log["skipped"]


def test_an_empty_list_while_a_match_is_in_the_window_opens_a_format_problem_once(world):
    world.add_match()
    world.fetch.pages[FILGOAL_LIST] = filgoal_list()

    world.run()
    world.run()

    assert len([text for text in world.alerts if "filgoal" in text]) == 1
    assert world.problem("format:filgoal").closed_at is None


def test_repeated_failures_never_open_the_breaker_and_the_source_recovers(world):
    world.add_match()
    world.fetch.pages[FILGOAL_LIST] = httpx.ConnectError("no route")

    for _ in range(4):
        world.run()

    assert world.source_state("filgoal").state == "down"
    assert world.problem("down:filgoal").closed_at is None
    with world.factory() as session:
        assert session.get(Source, "live_poller").breaker_opened_at is None
        assert session.get(Source, "filgoal").breaker_opened_at is None

    world.fetch.both()
    world.run()

    assert world.source_state("filgoal").state == "ok"
    assert world.problem("down:filgoal").closed_at is not None


def test_every_source_down_goes_to_the_clock_with_one_alert_and_recovery_restores_the_score(world):
    match_id = world.add_match()
    world.fetch.both(2, 1)
    world.run()
    assert world.match(match_id).home_score == 2

    world.fetch.pages[FILGOAL_LIST] = httpx.ConnectError("no route")
    world.fetch.pages[YALLAKORA_LIST] = httpx.ConnectError("no route")
    world.run()
    world.run()
    assert world.match(match_id).status_source == "feed"  # below the limit: not down yet

    world.run()
    world.run()

    row = world.match(match_id)
    assert (row.status_source, row.status, row.home_score, row.minute) == ("clock", "scheduled", None, None)
    assert world.problem("both_down").closed_at is None
    assert len([text for text in world.alerts if "كل المصادر" in text]) == 1

    world.fetch.both(2, 1)
    world.run()

    row = world.match(match_id)
    assert (row.status_source, row.home_score, row.away_score) == ("feed", 2, 1)
    assert world.problem("both_down").closed_at is not None


def test_a_feed_match_stays_selected_up_to_kickoff_plus_210(world):
    match_id = world.add_match(
        kickoff=NOW - timedelta(minutes=200), status_source="feed", status="live", home_score=0, away_score=0
    )

    world.run()

    assert world.match(match_id).status == "live"
    assert FILGOAL_LIST in world.fetch.requests


def test_a_clock_match_past_the_start_window_is_not_selected(world):
    world.add_match(kickoff=NOW - timedelta(minutes=200))

    assert run_cycle(world.deps()) == {"skipped": "no_matches"}


def test_an_alert_is_sent_only_after_commit(world, monkeypatch):
    match_id = world.add_match()
    world.run()
    world.fetch.both(1, 0, other=(0, 0))
    world.run()
    world.clock.tick(LiveSettings().disagree_after_s)
    real = cycle_module.sync_problems

    def fails_after_writing(session, **values):
        real(session, **values)
        raise OperationalError("COMMIT", {}, Exception("lost"))

    monkeypatch.setattr(cycle_module, "sync_problems", fails_after_writing)
    # The source problems go through the same call, so those fail loudly; only the match's is under test.
    monkeypatch.setattr(
        cycle_module, "_update_sources", lambda deps, reads, raw_ref, now: {read.source: "ok" for read in reads}
    )

    world.run()

    assert world.alerts == []
    assert world.problem(f"disagree:{match_id}") is None
    assert world.last_run().log["match_errors"] == 1


def test_each_cycle_writes_a_run_row_and_tells_health(world):
    world.add_match()

    world.run()
    world.run()

    runs = sorted((run for run in world.rows(ImportRun) if run.source == "live_poller"), key=lambda run: run.id)
    assert len(runs) == 2
    assert all(run.status == "succeeded" and run.finished_at is not None for run in runs)
    assert runs[0].log["worker"] == "live"
    assert runs[0].log["sources"] == {"filgoal": "ok", "yallakora": "ok"}
    assert runs[0].items_found == 1
    assert [call["status"] for call in world.health] == ["succeeded", "succeeded"]
    assert world.health[0]["items_found"] == 1


def test_each_cycle_moves_the_sources_version_so_a13_sees_its_run(world):
    """The run list's ETag is built from it: without a move, a reload is a 304 on the old list."""
    world.add_match()
    with world.factory() as session:
        before = version(session, "sources")

    world.run()
    world.run()

    with world.factory() as session:
        assert version(session, "sources") == before + 2


@pytest.mark.parametrize("href", [":abc/x", "@evil.example/x", "/a/../login", "/a/./login", "/a\\b"])
def test_a_bad_path_from_a_page_costs_that_page_and_nothing_else(world, href):
    match_id = world.add_match()
    world.caps["LIVE_PAGE_CAP_YALLAKORA"] = 2
    body = yallakora_list(("y1", 1, 0, YK_LIVE)).decode().replace("/league/1/match/y1/x#MC", href)
    world.fetch.pages[YALLAKORA_LIST] = body.encode()

    world.run()

    assert world.last_run().status == "succeeded"
    assert world.match(match_id).home_score == 1
    assert [url for url in world.fetch.requests if url not in (FILGOAL_LIST, YALLAKORA_LIST)] == []


def test_a_url_httpx_refuses_costs_that_page_and_nothing_else(world):
    match_id = world.add_match()
    world.caps["LIVE_PAGE_CAP_YALLAKORA"] = 2
    world.fetch.pages[YALLAKORA_LIST] = yallakora_list(("y1", 1, 0, YK_LIVE))
    page_url = "https://www.yallakora.com/league/1/match/y1/x"
    world.fetch.pages[page_url] = httpx.InvalidURL("Invalid non-printable ASCII character in URL")

    world.run()

    assert world.last_run().status == "succeeded"
    assert world.match(match_id).home_score == 1


def test_one_failed_source_makes_a_partial_run(world):
    world.add_match()
    world.fetch.pages[FILGOAL_LIST] = httpx.ConnectError("no route")

    world.run()

    assert world.last_run().status == "partial"
    assert world.health[-1]["status"] == "partial"


def test_a_raw_page_is_saved_only_on_change_or_failure(world):
    world.add_match()

    world.run()
    first = world.last_run()
    assert first.raw_path is not None
    assert first.log["pages"] == 2

    world.run()
    second = world.last_run()
    assert second.raw_path is None
    assert second.log["pages"] == 0

    world.fetch.pages[FILGOAL_LIST] = b"<html><body>blocked</body></html>"
    world.run()
    third = world.last_run()
    assert third.raw_path is not None
    assert third.log["pages"] == 1


def test_a_match_page_replaces_the_list_reading_and_brings_events_and_lineups(world):
    match_id = world.add_match()
    world.caps["LIVE_PAGE_CAP_FILGOAL"] = 8
    page = (FIXTURES / "filgoal_match_finished.html").read_bytes()
    with world.factory() as session, session.begin():
        session.execute(update(MatchExternalId).where(MatchExternalId.external_id == "f1").values(external_id="378939"))
    world.fetch.pages[FILGOAL_LIST] = filgoal_list(("378939", 3, 2, "انتهت"))
    world.fetch.pages["https://www.filgoal.com/matches/378939/coverage/"] = page
    world.fetch.pages[YALLAKORA_LIST] = yallakora_list(("y1", 3, 2, "انتهت"))

    world.run()

    row = world.match(match_id)
    assert (row.status, row.home_score, row.away_score) == ("finished", 3, 2)
    assert {event.type for event in world.rows(MatchEvent)} == {"goal", "penalty", "red_card"}
    assert {lineup.side for lineup in world.rows(MatchLineup)} == {"home", "away"}
    assert world.rows(NotificationOutbox) == []  # FR-014


def test_a_page_that_fails_validation_stops_the_whole_source(world):
    match_id = world.add_match()
    world.caps["LIVE_PAGE_CAP_FILGOAL"] = 8
    world.fetch.pages[FILGOAL_LIST] = filgoal_list(("f1", 7, 7, LIVE))
    world.fetch.pages["https://www.filgoal.com/matches/f1/coverage/"] = b"<html><body>no model</body></html>"
    world.fetch.pages[YALLAKORA_LIST] = yallakora_list(("y1", 0, 0, YK_LIVE))

    world.run()

    assert world.source_state("filgoal").state == "invalid"
    assert world.match(match_id).home_score == 0


def test_a_slot_is_remembered_for_the_next_cycle(world):
    from app.db.models import MatchLiveState

    match_id = world.add_match()
    world.caps["LIVE_PAGE_CAP_FILGOAL"] = 8
    page = (FIXTURES / "filgoal_match_scheduled.html").read_bytes()
    with world.factory() as session, session.begin():
        session.execute(update(MatchExternalId).where(MatchExternalId.external_id == "f1").values(external_id="379130"))
    world.fetch.pages[FILGOAL_LIST] = filgoal_list(("379130", "-", "-", "لم تبدأ"))
    world.fetch.pages["https://www.filgoal.com/matches/379130/coverage/"] = page
    world.fetch.pages[YALLAKORA_LIST] = yallakora_list(("y1", "-", "-", "لم تبدأ"))

    world.run()

    with world.factory() as session:
        assert session.get(MatchLiveState, match_id).has_page_slot is True
    assert world.match(match_id).status_source == "clock"


def test_the_deadline_leaves_remaining_pages_skipped(world):
    world.add_match()
    world.caps["LIVE_PAGE_CAP_FILGOAL"] = 8
    times = iter([0.0, 100.0, 100.0, 100.0, 100.0])

    world.run(monotonic=lambda: next(times))

    assert "https://www.filgoal.com/matches/f1/coverage/" not in world.fetch.requests
    assert any(item.startswith("filgoal:") for item in world.last_run().log["skipped"])


def test_unresolved_names_reach_the_queue(world):
    world.add_match()
    world.fetch.pages[FILGOAL_LIST] = filgoal_list(("f1", 0, 0, LIVE), ("new", 0, 0, LIVE))

    world.run()

    assert {call["source"] for call in world.unresolved} == {"filgoal"}
    assert {call["kind"] for call in world.unresolved} == {"team"}


def test_a_queued_name_is_stored_and_bumps_its_dataset_once(world):
    world.add_match()
    world.fetch.pages[FILGOAL_LIST] = filgoal_list(("f1", 0, 0, LIVE), ("new", 0, 0, LIVE))
    with world.factory() as session:
        before = version(session, "unresolved_names")

    world.run(record_unresolved=record_unresolved)

    assert {(row.source, row.kind) for row in world.rows(UnresolvedName)} == {("filgoal", "team")}
    with world.factory() as session:
        assert version(session, "unresolved_names") == before + 1


def test_a_name_the_queue_did_not_change_bumps_nothing(world):
    world.add_match()
    world.fetch.pages[FILGOAL_LIST] = filgoal_list(("f1", 0, 0, LIVE), ("new", 0, 0, LIVE))
    with world.factory() as session:
        before = version(session, "unresolved_names")

    world.run(record_unresolved=lambda session, **values: False)

    with world.factory() as session:
        assert version(session, "unresolved_names") == before


def test_a_cycle_reaches_the_live_poller_row_without_a_breaker(world):
    world.add_match()

    world.run(record_live_cycle=record_live_cycle)

    row = next(source for source in world.rows(Source) if source.name == "live_poller")
    assert row.last_success_at == world.last_run().finished_at
    assert row.breaker_opened_at is None


def test_a_saved_run_opens_in_the_raw_view_with_its_urls(world):
    world.add_match()

    world.run()
    run = world.last_run()
    first = read_page(world.raw_root, run.raw_path, 0, max_bytes=1024 * 1024)
    second = read_page(world.raw_root, run.raw_path, 1, max_bytes=1024 * 1024)

    assert first["pages"] == run.log["pages"] == 2
    assert first["url"] == FILGOAL_LIST
    assert second["url"] == YALLAKORA_LIST
    assert first["content_type"] == "text/html"


def test_a_final_status_waits_out_a_disagreement_then_finishes_with_an_alert(world):
    match_id = world.add_match()
    world.fetch.both(1, 1)
    world.run()
    world.fetch.pages[FILGOAL_LIST] = filgoal_list(("f1", 2, 1, "انتهت"))
    world.fetch.pages[YALLAKORA_LIST] = yallakora_list(("y1", 1, 1, "انتهت"))

    for _ in range(5):
        world.run()

    row = world.match(match_id)
    assert (row.status_source, row.status, row.home_score, row.away_score) == ("feed", "live", 2, 1)
    assert has_work_in(world.factory, world.clock()) is True

    world.run()

    row = world.match(match_id)
    assert (row.status, row.home_score, row.away_score) == ("finished", 2, 1)
    assert world.problem(f"disagree:{match_id}").closed_at is None
    assert len([text for text in world.alerts if str(match_id) in text]) == 1
    assert has_work_in(world.factory, world.clock()) is False


def test_the_lagging_source_catching_up_finishes_a_held_match_at_once(world):
    match_id = world.add_match()
    world.fetch.both(1, 1)
    world.run()
    world.fetch.pages[FILGOAL_LIST] = filgoal_list(("f1", 2, 1, "انتهت"))
    world.fetch.pages[YALLAKORA_LIST] = yallakora_list(("y1", 1, 1, "انتهت"))
    world.run()
    assert world.match(match_id).status == "live"

    world.fetch.pages[YALLAKORA_LIST] = yallakora_list(("y1", 2, 1, "انتهت"))
    world.run()

    row = world.match(match_id)
    assert (row.status, row.home_score, row.away_score) == ("finished", 2, 1)
    assert world.problem(f"disagree:{match_id}") is None


def test_one_failed_request_cannot_lower_a_score_or_end_the_match(world):
    match_id = world.add_match()
    world.fetch.both(2, 1)
    world.run()
    world.fetch.pages[FILGOAL_LIST] = httpx.ConnectError("no route")
    world.fetch.pages[YALLAKORA_LIST] = yallakora_list(("y1", 1, 1, "انتهت"))
    world.run()

    row = world.match(match_id)
    assert (row.status, row.home_score, row.away_score) == ("live", 2, 1)


def test_one_source_holding_full_time_alone_finishes_after_the_hold(world):
    match_id = world.add_match()
    world.fetch.both(1, 0)
    world.run()
    world.fetch.pages[FILGOAL_LIST] = filgoal_list(("f1", 1, 0, "انتهت"))
    world.fetch.pages[YALLAKORA_LIST] = httpx.ConnectError("no route")

    world.run()
    assert world.match(match_id).status == "live"
    assert world.match(match_id).minute is None

    world.clock.tick(LiveSettings().fulltime_hold_s)
    world.run()

    row = world.match(match_id)
    assert (row.status, row.home_score, row.away_score) == ("finished", 1, 0)


def test_one_failed_filgoal_poll_cannot_move_a_live_match_back(world):
    match_id = world.add_match()
    world.fetch.pages[FILGOAL_LIST] = filgoal_list(("f1", 0, 0, LIVE))
    world.fetch.pages[YALLAKORA_LIST] = yallakora_list(("y1", "-", "-", "لم تبدأ"))
    world.run()
    world.run()
    assert world.match(match_id).status == "live"

    world.fetch.pages[FILGOAL_LIST] = httpx.ConnectError("no route")
    world.run()
    row = world.match(match_id)
    assert (row.status_source, row.status) == ("feed", "live")

    # Going back waits until no usable source has shown the later stage for five minutes.
    world.clock.tick(LiveSettings().drop_hold_s)
    world.run()
    assert world.match(match_id).status == "scheduled"


def _filgoal_page(**changes) -> bytes:
    """The real finished page with its model's shape changed."""
    text = (FIXTURES / "filgoal_match_finished.html").read_text()
    start = re.search(r"viewModelData\s*=\s*", text).end()
    model, length = json.JSONDecoder().raw_decode(text[start:])
    return (text[:start] + json.dumps({**model, **changes}, ensure_ascii=False) + text[start + length :]).encode()


SHAPE_CHANGES = {
    "a_string_in_events": {"Events": ["goal"]},
    "events_not_a_list": {"Events": 7},
    "a_string_in_the_squads": {"MatchTeamsSquads": ["player"]},
    "a_status_that_is_a_string": {"CurrentMatchStatus": {"MatchStatusName": 9}},
    "penalties_that_are_text": {"HomePenaltyScore": "x", "AwayPenaltyScore": "y"},
}


@pytest.mark.parametrize("changes", SHAPE_CHANGES.values(), ids=SHAPE_CHANGES.keys())
def test_any_error_reading_a_changed_filgoal_page_is_a_validation_failure(changes):
    with pytest.raises(LayoutChanged):
        cycle_module._parse_page(filgoal.SOURCE, _filgoal_page(**changes), "378939")


def test_any_error_reading_a_changed_yallakora_page_is_a_validation_failure():
    text = (FIXTURES / "yallakora_match_finished.html").read_text()
    changed = re.sub(r'(class="date"[^>]*>)[^<]*', r"\g<1>45 نوفمبر 2026", text)
    assert changed != text

    with pytest.raises(LayoutChanged):
        cycle_module._parse_page(yallakora.SOURCE, changed.encode(), "y1")


def test_a_changed_page_stops_that_source_with_one_alert_and_the_other_is_used(world):
    match_id = world.add_match()
    world.caps["LIVE_PAGE_CAP_FILGOAL"] = 8
    with world.factory() as session, session.begin():
        session.execute(update(MatchExternalId).where(MatchExternalId.external_id == "f1").values(external_id="378939"))
    world.fetch.pages[FILGOAL_LIST] = filgoal_list(("378939", 3, 2, "انتهت"))
    world.fetch.pages["https://www.filgoal.com/matches/378939/coverage/"] = _filgoal_page(Events=["goal"])
    world.fetch.pages[YALLAKORA_LIST] = yallakora_list(("y1", 1, 0, YK_LIVE))

    world.run()
    world.run()
    world.run()

    run = world.last_run()
    assert (run.status, run.finished_at is not None) == ("partial", True)
    assert world.source_state("filgoal").state == "invalid"
    assert world.problem("format:filgoal").closed_at is None
    assert world.problem("format:filgoal").raw_ref is not None
    assert len([text for text in world.alerts if "filgoal" in text]) == 1
    row = world.match(match_id)
    assert (row.status, row.home_score, row.away_score) == ("live", 1, 0)


def test_a_list_parser_error_is_a_validation_failure_of_that_source(world, monkeypatch):
    match_id = world.add_match()

    def breaks(*_args, **_kwargs):
        raise AttributeError("'str' object has no attribute 'get'")

    monkeypatch.setattr(filgoal, "_list_row", breaks)
    world.fetch.pages[YALLAKORA_LIST] = yallakora_list(("y1", 1, 0, YK_LIVE))

    world.run()
    world.run()

    assert world.source_state("filgoal").state == "invalid"
    assert world.problem("format:filgoal").closed_at is None
    assert world.last_run().status == "partial"
    assert world.match(match_id).home_score == 1


def _two_matches(world):
    first = world.add_match()
    with world.factory() as session, session.begin():
        second = make_match(session, KICKOFF + timedelta(minutes=1)).id
        session.add(MatchExternalId(source="filgoal", external_id="f2", match_id=second))
        session.add(MatchExternalId(source="yallakora", external_id="y2", match_id=second))
    world.fetch.pages[FILGOAL_LIST] = filgoal_list(("f1", 1, 0, LIVE), ("f2", 1, 0, LIVE))
    world.fetch.pages[YALLAKORA_LIST] = yallakora_list(("y1", 1, 0, YK_LIVE), ("y2", 1, 0, YK_LIVE))
    return first, second


def test_one_matchs_error_does_not_end_the_cycle(world, monkeypatch):
    first, second = _two_matches(world)
    real = cycle_module.decide

    def breaks_on_the_first(state, *args, **kwargs):
        if state.match_id == first:
            raise TypeError("a shape nobody checked")
        return real(state, *args, **kwargs)

    monkeypatch.setattr(cycle_module, "decide", breaks_on_the_first)

    world.run()

    assert world.match(first).status_source == "clock"
    assert world.match(second).home_score == 1
    run = world.last_run()
    assert (run.status, run.log["match_errors"]) == ("partial", 1)
    assert run.finished_at is not None


def test_one_rows_link_error_does_not_end_the_cycle(world, monkeypatch):
    first, second = _two_matches(world)
    real = cycle_module.link_reading

    def breaks_on_one(session, reading, **kwargs):
        if reading.external_id == "f1":
            raise AttributeError("a shape nobody checked")
        return real(session, reading, **kwargs)

    monkeypatch.setattr(cycle_module, "link_reading", breaks_on_one)

    world.run()

    assert world.match(second).home_score == 1
    run = world.last_run()
    assert (run.status, run.finished_at is not None, run.log["match_errors"]) == ("partial", True, 1)


def test_the_run_row_closes_when_the_cycle_itself_breaks(world, monkeypatch):
    world.add_match()

    def breaks(*_args, **_kwargs):
        raise RuntimeError("redis went away")

    monkeypatch.setattr(cycle_module, "_update_sources", breaks)

    with pytest.raises(RuntimeError):
        world.run()

    run = world.last_run()
    assert run.status == "failed"
    assert run.finished_at is not None
    assert "RuntimeError" in run.error
    assert world.health[-1]["status"] == "failed"


def test_a_postponed_match_is_written_then_polling_stops(world):
    match_id = world.add_match()
    world.fetch.pages[FILGOAL_LIST] = filgoal_list(("f1", "-", "-", "تأجيل"))
    world.fetch.pages[YALLAKORA_LIST] = yallakora_list(("y1", "-", "-", "تأجيل"))

    world.run()

    row = world.match(match_id)
    assert (row.status_source, row.status, row.status_label) == ("feed", "postponed", "تأجيل")
    requests = len(world.fetch.requests)

    assert has_work_in(world.factory, world.clock()) is False
    assert run_cycle(world.deps()) == {"skipped": "no_matches"}
    assert len(world.fetch.requests) == requests
    assert world.alerts == []


def test_old_poller_runs_are_pruned_and_importer_runs_are_not(world):
    with world.factory() as session, session.begin():
        session.add(ImportRun(source="live_poller", started_at=NOW - timedelta(days=31), status="succeeded"))
        session.add(ImportRun(source="live_poller", started_at=NOW - timedelta(days=29), status="succeeded"))
        session.add(ImportRun(source="ysscores", started_at=NOW - timedelta(days=90), status="succeeded"))

    with world.factory() as session, session.begin():
        assert delete_old_runs(session, NOW) == 1

    assert {(run.source, run.started_at) for run in world.rows(ImportRun)} == {
        ("live_poller", NOW - timedelta(days=29)),
        ("ysscores", NOW - timedelta(days=90)),
    }


def test_overlapping_cycles_exit(monkeypatch):
    from app.live import tasks

    held = FakeRedis()
    held.set("lock:live:poll", "another worker")
    monkeypatch.setattr(tasks, "_redis", lambda: held)
    monkeypatch.setattr(cycle_module, "run_cycle", lambda deps: pytest.fail("the lock is held"))

    assert tasks.live_poll.run() == {"skipped": "lock_held"}


# ----------------------------------------------------------------------------------- three sources (T016)


def test_three_sources_are_read_in_one_cycle_goal_com_last(world):
    match_id = world.with_goal(1, 0).add_match()
    world.fetch.both(0, 0)

    world.run()

    assert world.fetch.requests == [FILGOAL_LIST, YALLAKORA_LIST, GOAL_LIST]
    row = world.match(match_id)
    assert (row.home_score, row.away_score, row.minute) == (1, 0, "20")
    assert world.last_run().log["sources"] == {"filgoal": "ok", "yallakora": "ok", "goal": "ok"}
    with world.factory() as session:
        assert session.get(MatchSourceReading, (match_id, "goal")).home_score == 1


def test_switched_off_goal_com_gets_no_request_and_writes_nothing(world):
    match_id = world.add_match()
    world.fetch.goal(5, 5)

    world.run()

    assert GOAL_LIST not in world.fetch.requests
    assert world.source_state("goal") is None
    assert world.last_run().log["sources"] == {"filgoal": "ok", "yallakora": "ok"}
    assert world.match(match_id).home_score == 0
    with world.factory() as session:
        assert session.get(MatchSourceReading, (match_id, "goal")) is None


def test_goal_coms_pages_come_after_the_other_pages_and_bring_events_and_stats(world):
    world.with_goal(1, 0).add_match()
    world.caps["LIVE_PAGE_CAP_FILGOAL"] = 8
    world.caps["LIVE_PAGE_CAP_GOAL"] = 4
    page = "https://www.goal.com/ar-eg/match/x/g1"
    stats = [{"type": "POSSESSION", "teamA": 55, "teamB": 45}]
    world.fetch.pages[page] = goal_page(stats=stats)
    world.fetch.pages["https://www.filgoal.com/matches/f1/coverage/"] = httpx.ConnectError("no route")

    world.run()

    assert world.fetch.requests == [
        FILGOAL_LIST,
        YALLAKORA_LIST,
        "https://www.filgoal.com/matches/f1/coverage/",
        GOAL_LIST,
        page,
    ]
    assert {(row.source, row.type) for row in world.rows(MatchEvent)} == {("goal", "goal")}
    assert [row.stats for row in world.rows(MatchStats)] == [[{"type": "POSSESSION", "home": 55, "away": 45}]]


def test_goal_coms_page_cap_holds(world):
    world.with_goal(1, 0).add_match()

    world.run()

    assert world.fetch.requests == [FILGOAL_LIST, YALLAKORA_LIST, GOAL_LIST]


def test_goal_com_past_the_deadline_is_skipped_and_costs_the_others_nothing(world):
    match_id = world.with_goal(9, 9).add_match()
    world.fetch.both(1, 0)
    times = iter([0.0, 100.0, 100.0, 100.0])

    world.run(monotonic=lambda: next(times))

    assert world.fetch.requests == [FILGOAL_LIST, YALLAKORA_LIST]
    assert world.match(match_id).home_score == 1
    assert "goal:list" in world.last_run().log["skipped"]
    assert world.last_run().status == "partial"
    assert world.source_state("goal").consecutive_failures == 0


def test_goal_coms_pages_stop_at_the_deadline(world):
    world.with_goal(1, 0).add_match()
    world.caps["LIVE_PAGE_CAP_GOAL"] = 4
    times = iter([0.0, 0.0, 100.0, 100.0])

    world.run(monotonic=lambda: next(times))

    assert world.fetch.requests == [FILGOAL_LIST, YALLAKORA_LIST, GOAL_LIST]
    assert any(item.startswith("goal:") for item in world.last_run().log["skipped"])


@pytest.mark.parametrize(
    ("failure", "state", "problem"),
    [
        (httpx.ConnectError("no route"), "failing", None),
        (Retryable("answered 429"), "failing", None),
        (b"<html><body>Just a moment...</body></html>", "invalid", "format:goal"),
    ],
    ids=["failing", "blocked", "invalid"],
)
def test_goal_com_failing_leaves_the_others_working(world, failure, state, problem):
    match_id = world.with_goal().add_match()
    world.fetch.both(1, 0)
    world.fetch.pages[GOAL_LIST] = failure

    world.run()

    assert world.match(match_id).home_score == 1
    assert world.source_state("goal").state == state
    assert world.source_state("filgoal").state == "ok"
    assert world.last_run().status == "partial"
    if problem is not None:
        assert world.problem(problem).closed_at is None


def test_a_goal_com_block_backs_off_goal_com_only(world):
    world.with_goal().add_match()
    world.fetch.pages[GOAL_LIST] = Retryable("answered 403")

    world.run()
    world.run()

    assert world.redis.exists(f"live:backoff:{goal.HOST}")
    assert world.fetch.requests.count(GOAL_LIST) == 1
    assert world.fetch.requests.count(FILGOAL_LIST) == 2


def test_every_enabled_source_must_be_down_before_the_clock(world):
    match_id = world.with_goal().add_match()
    world.fetch.both(2, 1)
    world.fetch.goal(2, 1)
    world.run()
    world.fetch.pages[FILGOAL_LIST] = httpx.ConnectError("no route")
    world.fetch.pages[YALLAKORA_LIST] = httpx.ConnectError("no route")

    for _ in range(4):
        world.run()

    assert world.source_state("filgoal").state == "down"
    assert world.source_state("yallakora").state == "down"
    assert world.problem("both_down") is None
    assert world.match(match_id).status_source == "feed"

    world.fetch.pages[GOAL_LIST] = httpx.ConnectError("no route")
    for _ in range(4):
        world.run()

    assert world.problem("both_down").closed_at is None
    assert world.match(match_id).status_source == "clock"


def test_the_two_enabled_sources_down_is_all_of_them_with_goal_com_off(world):
    match_id = world.add_match()
    world.fetch.pages[FILGOAL_LIST] = httpx.ConnectError("no route")
    world.fetch.pages[YALLAKORA_LIST] = httpx.ConnectError("no route")

    for _ in range(4):
        world.run()

    assert world.problem("both_down").closed_at is None
    assert world.match(match_id).status_source == "clock"


def test_goal_com_names_reach_the_queue_under_goal_and_no_team_is_made(world):
    world.with_goal().add_match()
    world.fetch.pages[GOAL_LIST] = goal_list(("g1", 0, 0, "LIVE", "1H"), ("new", 0, 0, "LIVE", "1H"))
    with world.factory() as session:
        teams = len(session.scalars(select(Team)).all())

    world.run()

    assert {(call["source"], call["kind"]) for call in world.unresolved} == {("goal", "team")}
    with world.factory() as session:
        assert len(session.scalars(select(Team)).all()) == teams


# ----------------------------------------------------------------------------------- an unknown status


def test_an_unknown_status_opens_one_problem_and_does_not_stop_the_source(world):
    world.add_match()
    world.fetch.both(1, 0)
    world.run()
    world.fetch.pages[FILGOAL_LIST] = filgoal_list(("f1", 1, 0, "حالة جديدة"))

    world.run()
    world.run()

    assert world.problem("unknown_status:filgoal").closed_at is None
    assert len([text for text in world.alerts if "filgoal" in text]) == 1
    assert world.source_state("filgoal").state == "ok"
    assert world.problem("format:filgoal") is None
    assert world.last_run().log["unknown_statuses"] == {"filgoal": ["حالة جديدة"]}

    world.fetch.both(1, 0)
    world.run()

    assert world.problem("unknown_status:filgoal").closed_at is not None
    assert len([text for text in world.alerts if "filgoal" in text]) == 2


def test_an_unknown_status_with_a_score_counts_and_keeps_the_match_fresh(world):
    match_id = world.add_match()
    world.fetch.both(1, 0)
    world.run()
    world.fetch.pages[FILGOAL_LIST] = filgoal_list(("f1", 2, 0, "حالة جديدة"))
    world.fetch.pages[YALLAKORA_LIST] = httpx.ConnectError("no route")
    now = world.clock()

    world.run()

    row = world.match(match_id)
    assert (row.status, row.home_score) == ("live", 2)
    with world.factory() as session:
        from app.db.models import MatchLiveState

        assert session.get(MatchLiveState, match_id).last_reading_at == now
        assert session.get(MatchSourceReading, (match_id, "filgoal")).status is None


def test_an_unknown_status_with_no_score_is_as_if_it_did_not_cover_the_match(world):
    match_id = world.add_match()
    world.fetch.both(1, 0)
    world.run()
    before = world.clock()
    world.fetch.pages[FILGOAL_LIST] = filgoal_list(("f1", "-", "-", "حالة جديدة"))
    world.fetch.pages[YALLAKORA_LIST] = httpx.ConnectError("no route")

    world.run()

    with world.factory() as session:
        from app.db.models import MatchLiveState

        assert session.get(MatchLiveState, match_id).last_reading_at < before
    assert world.match(match_id).status_source == "feed"
    assert world.problem("unknown_status:filgoal").closed_at is None


def test_a_page_with_no_period_takes_the_stage_from_its_list_row(world):
    match_id = world.add_match()
    world.caps["LIVE_PAGE_CAP_YALLAKORA"] = 2
    world.fetch.pages[FILGOAL_LIST] = filgoal_list(("f1", 1, 0, "الشوط الثاني"))
    page = (FIXTURES / "yallakora_match_live.html").read_bytes()
    world.fetch.pages["https://www.yallakora.com/league/1/match/y1/x"] = page
    world.fetch.pages[YALLAKORA_LIST] = yallakora_list(("y1", 1, 0, "الشوط الثاني"))

    world.run()

    with world.factory() as session:
        reading = session.get(MatchSourceReading, (match_id, "yallakora"))
    assert (reading.status, reading.period) == ("live", "2H")
    assert world.match(match_id).period == "2H"


# ---------------------------------------------------------------------------------- Cairo's midnight

# 00:01 in Cairo on the 5th: YallaKora's list has moved to the 5th, with a match from the 4th still open.
AFTER_MIDNIGHT = datetime(2026, 11, 4, 22, 1, tzinfo=UTC)
LATE_KICKOFF = datetime(2026, 11, 4, 20, 0, tzinfo=UTC)
YALLAKORA_THE_4TH = f"{YALLAKORA_LIST}?date=2026-11-04"
YK_SECOND_HALF = "الشوط الثاني"
YK_FINISHED = "انتهت"


def _midnight_passes(world, *rows_of_the_4th):
    world.clock.now = AFTER_MIDNIGHT
    world.fetch.pages[FILGOAL_LIST] = filgoal_list(("f9", 0, 0, LIVE))
    world.fetch.pages[YALLAKORA_LIST] = yallakora_list(("y9", "-", "-", "لم تبدأ"))
    world.fetch.pages[YALLAKORA_THE_4TH] = yallakora_list(*rows_of_the_4th)


def _add_todays_match(world, external_id="y2"):
    with world.factory() as session, session.begin():
        match = make_match(session, AFTER_MIDNIGHT - timedelta(minutes=1))
        session.add(MatchExternalId(source="yallakora", external_id=external_id, match_id=match.id))
        return match.id


def test_a_match_still_on_at_midnight_is_read_from_its_own_days_list(world):
    match_id = world.add_match(LATE_KICKOFF)
    _midnight_passes(world, ("y1", 2, 1, YK_SECOND_HALF))

    world.run()

    assert YALLAKORA_THE_4TH in world.fetch.requests
    row = world.match(match_id)
    assert (row.status, row.period, row.home_score, row.away_score) == ("live", "2H", 2, 1)
    assert world.source_state("yallakora").state == "ok"


def test_a_lone_full_time_that_crosses_midnight_finishes_on_its_score(world):
    world.clock.now = AFTER_MIDNIGHT - timedelta(minutes=4)
    match_id = world.add_match(LATE_KICKOFF)
    world.fetch.pages[FILGOAL_LIST] = filgoal_list(("f9", 0, 0, LIVE))
    world.fetch.pages[YALLAKORA_LIST] = yallakora_list(("y1", 2, 1, YK_SECOND_HALF))
    world.run()
    world.fetch.pages[YALLAKORA_LIST] = yallakora_list(("y1", 2, 1, YK_FINISHED))
    world.run()

    _midnight_passes(world, ("y1", 2, 1, YK_FINISHED))
    world.run()
    assert world.match(match_id).status == "live"

    world.clock.tick(LiveSettings().fulltime_hold_s)
    world.run()

    row = world.match(match_id)
    assert (row.status, row.status_source, row.home_score, row.away_score) == ("finished", "feed", 2, 1)


def test_a_row_on_yesterdays_list_is_dated_yesterday(world):
    world.add_match(LATE_KICKOFF)
    _midnight_passes(world, ("y5", 2, 1, YK_SECOND_HALF))

    world.run()

    # Only a row inside the window gets as far as the queue, and 22:00 on the 5th isn't.
    assert {call["name"] for call in world.unresolved if call["source"] == "yallakora"} == {"أ", "ب"}


def test_todays_row_wins_an_id_both_lists_have(world):
    match_id = world.add_match(LATE_KICKOFF)
    _midnight_passes(world, ("y1", 2, 1, YK_SECOND_HALF))
    world.fetch.pages[YALLAKORA_LIST] = yallakora_list(("y1", 3, 1, YK_SECOND_HALF))

    world.run()

    assert world.match(match_id).home_score == 3


def test_before_midnight_only_todays_list_is_read(world):
    world.clock.now = AFTER_MIDNIGHT - timedelta(minutes=5)
    world.add_match(LATE_KICKOFF)

    world.run()

    assert not [url for url in world.fetch.requests if "?date=" in url]


def test_with_no_match_left_from_yesterday_its_list_is_not_read(world):
    _add_todays_match(world)
    _midnight_passes(world)

    world.run()

    assert YALLAKORA_THE_4TH not in world.fetch.requests


def test_only_a_source_with_dated_lists_reads_yesterday(world):
    world.with_goal().add_match(LATE_KICKOFF)
    _midnight_passes(world, ("y1", 2, 1, YK_SECOND_HALF))
    world.fetch.pages[GOAL_LIST] = goal_list(("g9", 0, 0, "LIVE", "1H"))

    world.run()

    assert sorted(world.fetch.requests) == sorted([FILGOAL_LIST, YALLAKORA_LIST, YALLAKORA_THE_4TH, GOAL_LIST])


def test_a_failed_read_of_yesterdays_list_costs_todays_list_nothing(world):
    world.add_match(LATE_KICKOFF)
    todays = _add_todays_match(world)
    _midnight_passes(world)
    world.fetch.pages[YALLAKORA_LIST] = yallakora_list(("y2", 1, 0, YK_LIVE))
    world.fetch.pages[YALLAKORA_THE_4TH] = httpx.ConnectError("no route")

    world.run()

    assert world.match(todays).home_score == 1
    assert world.source_state("yallakora").state == "ok"
    assert world.last_run().http_errors == 1


def test_a_block_on_yesterdays_list_backs_off_the_host_and_keeps_todays_list(world):
    world.add_match(LATE_KICKOFF)
    todays = _add_todays_match(world)
    _midnight_passes(world)
    world.fetch.pages[YALLAKORA_LIST] = yallakora_list(("y2", 1, 0, YK_LIVE))
    world.fetch.pages[YALLAKORA_THE_4TH] = Retryable("answered 403")

    world.run()

    assert world.redis.exists(f"live:backoff:{yallakora.HOST}")
    assert world.match(todays).home_score == 1


def test_no_tokens_for_yesterdays_list_is_nobodys_fault(world):
    world.add_match(LATE_KICKOFF)
    todays = _add_todays_match(world)
    _midnight_passes(world)
    world.fetch.pages[YALLAKORA_LIST] = yallakora_list(("y2", 1, 0, YK_LIVE))
    world.fetch.pages[YALLAKORA_THE_4TH] = OutOfTokens()

    world.run()

    assert world.match(todays).home_score == 1
    assert world.source_state("yallakora").state == "ok"
    assert world.last_run().log["skipped"] == ["yallakora:list:2026-11-04"]


def test_yesterdays_list_past_the_deadline_is_skipped(world):
    world.add_match(LATE_KICKOFF)
    _midnight_passes(world)

    world.run(monotonic=iter([0.0, 999.0, 999.0, 999.0, 999.0]).__next__)

    assert YALLAKORA_THE_4TH not in world.fetch.requests
    assert world.source_state("yallakora").state == "ok"
    assert world.last_run().log["skipped"] == ["yallakora:list:2026-11-04"]


def test_a_changed_page_on_yesterdays_list_stops_that_source_with_one_alert(world):
    world.add_match(LATE_KICKOFF)
    _midnight_passes(world)
    world.fetch.pages[YALLAKORA_THE_4TH] = b"<html><body>another page</body></html>"

    world.run()

    assert world.source_state("yallakora").state == "invalid"
    assert world.problem("format:yallakora").closed_at is None


def test_an_empty_list_for_yesterday_stops_nothing(world):
    world.add_match(LATE_KICKOFF)
    _midnight_passes(world)

    world.run()

    assert world.source_state("yallakora").state == "ok"
    assert world.problem("format:yallakora") is None
