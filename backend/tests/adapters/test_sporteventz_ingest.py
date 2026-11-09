"""A sporteventz run end to end: saved pages and answers through ``adapters.ingest`` (D6 T054, SC-010).

The fixtures are the 2026-11-06 capture. 191 events across four sports are imported as their own
fixtures with text-only names and two broadcaster slots, and a second run changes nothing.
"""

from __future__ import annotations

import json
from datetime import UTC, date, datetime
from pathlib import Path
from typing import Any

import pytest
from sqlalchemy import func, select, text

from app.adapters.base import RawPage
from app.adapters.messages import ScrapeResult
from app.adapters.sporteventz import PAGE_URL, SPORTS, SporteventzAdapter
from app.adapters.tasks import ingest
from app.db.models import ImportRun, Match, MatchCustomBroadcast, MatchExternalId

FIXTURES = Path(__file__).resolve().parents[1] / "fixtures" / "sporteventz" / "2026-11-06"
NOW = datetime(2026, 11, 6, 9, 0, tzinfo=UTC)
SOURCE_ROW = "SELECT consecutive_failures, last_zero_alert_on FROM sources WHERE name = 'sporteventz'"


@pytest.fixture(autouse=True)
def _task_session(monkeypatch: pytest.MonkeyPatch, sync_session, tmp_path: Path):
    from sqlalchemy.orm import Session

    import app.db.session as db_session

    monkeypatch.setattr(
        db_session,
        "SyncSession",
        lambda: Session(bind=sync_session.connection(), join_transaction_mode="create_savepoint"),
    )
    monkeypatch.setenv("RAW_ROOT", str(tmp_path))
    from app.adapters.config import get_adapter_settings

    get_adapter_settings.cache_clear()
    yield
    get_adapter_settings.cache_clear()


def _data_url(sport: str) -> str:
    return (FIXTURES / f"{sport}.url.txt").read_text(encoding="utf-8").split()[1]


def _pages() -> list[RawPage]:
    pages: list[RawPage] = []
    for sport in SPORTS:
        pages.append(
            RawPage(
                url=PAGE_URL.format(slug=sport),
                status=200,
                body=(FIXTURES / f"{sport}.html").read_bytes(),
                content_type="text/html",
            )
        )
        pages.append(
            RawPage(
                url=_data_url(sport),
                status=200,
                body=(FIXTURES / f"{sport}.json").read_bytes(),
                content_type="text/plain",
            )
        )
    return pages


def _items(pages: list[RawPage]) -> list[Any]:
    adapter = SporteventzAdapter(fetcher=None)
    return [item for page in pages for item in adapter.parse(page)]


def _run(run_id: str = "r-1", pages: list[RawPage] | None = None) -> dict[str, Any]:
    chosen = pages if pages is not None else _pages()
    result = ScrapeResult.build(
        source="sporteventz",
        run_id=run_id,
        started_at=NOW,
        finished_at=NOW,
        fetched_on="scrape-home",
        pages=chosen,
        items=_items(chosen),
    )
    return ingest.apply(args=[result.as_task_arg()]).get()


def _empty_run(run_id: str) -> dict[str, Any]:
    """A valid answer with no records in any sport: four sport pages, four empty data answers."""
    pages = [RawPage(url=PAGE_URL.format(slug=sport), status=200, body=b"<html>nothing</html>") for sport in SPORTS]
    result = ScrapeResult.build(
        source="sporteventz",
        run_id=run_id,
        started_at=NOW,
        finished_at=NOW,
        fetched_on="scrape-home",
        pages=pages,
        items=[],
    )
    return ingest.apply(args=[result.as_task_arg()]).get()


def _count(session: Any, model: Any, *where: Any) -> int:
    statement = select(func.count()).select_from(model)
    for clause in where:
        statement = statement.where(clause)
    return session.execute(statement).scalar_one()


def _slots(session: Any, match_id: int) -> list[tuple[int, str]]:
    return list(
        session.execute(
            select(MatchCustomBroadcast.slot, MatchCustomBroadcast.label)
            .where(MatchCustomBroadcast.match_id == match_id)
            .order_by(MatchCustomBroadcast.slot)
        ).all()
    )


def test_a_run_stores_every_sport_as_its_own_fixture_with_text_names_and_slots(sync_session, loaded_snapshot) -> None:
    football = _count(sync_session, Match, Match.sport == "football")

    outcome = _run()

    assert outcome["status"] == "succeeded"
    assert outcome["items_upserted"] == 191
    # SC-010: no new football row, and no team, competition or channel grew either.
    assert _count(sync_session, Match, Match.sport == "football") == football

    match = sync_session.execute(
        select(Match)
        .join(MatchExternalId, MatchExternalId.match_id == Match.id)
        .where(MatchExternalId.source == "sporteventz", MatchExternalId.external_id == "73719544")
    ).scalar_one()
    assert (match.sport, match.home_team_name, match.away_team_name) == (
        "basketball",
        "Phoenix Suns",
        "Orlando Magic",
    )
    assert (match.home_team_id, match.away_team_id, match.competition_id) == (None, None, None)
    assert match.kickoff_at == datetime(2026, 11, 6, 2, 0, tzinfo=UTC)
    assert _slots(sync_session, match.id) == [(1, "Sky Sport Mix HD"), (2, "Sky Sport Top Event HD")]

    sports = dict(
        sync_session.execute(
            select(Match.sport, func.count()).where(Match.source == "sporteventz").group_by(Match.sport)
        ).all()
    )
    assert sports == {"basketball": 79, "handball": 23, "volleyball": 28, "tennis": 61}


def test_a_second_run_changes_nothing_and_duplicates_no_match(sync_session, loaded_snapshot) -> None:
    _run("r-1")
    matches = _count(sync_session, Match, Match.source == "sporteventz")
    rows = _count(sync_session, MatchCustomBroadcast)

    outcome = _run("r-2")

    assert outcome["items_upserted"] == 0
    assert _count(sync_session, Match, Match.source == "sporteventz") == matches
    assert _count(sync_session, MatchCustomBroadcast) == rows


def test_a_locked_broadcast_list_is_left_alone(sync_session, loaded_snapshot) -> None:
    _run("r-1")
    match = sync_session.execute(
        select(Match)
        .join(MatchExternalId, MatchExternalId.match_id == Match.id)
        .where(MatchExternalId.source == "sporteventz", MatchExternalId.external_id == "73719544")
    ).scalar_one()
    sync_session.execute(
        text("UPDATE matches SET locked_fields = ARRAY['broadcasts'] WHERE id = :id"), {"id": match.id}
    )
    pages = _pages()
    changed = [
        page
        if "73719544" not in page.text
        else RawPage(
            url=page.url,
            status=200,
            body=page.body.replace(b"Sky Sport Mix HD", b"Another Channel"),
        )
        for page in pages
    ]

    _run("r-2", changed)

    sync_session.expire_all()
    assert _slots(sync_session, match.id) == [(1, "Sky Sport Mix HD"), (2, "Sky Sport Top Event HD")]


def test_a_card_sharing_name_is_refused_and_counted(sync_session, loaded_snapshot) -> None:
    record = {
        "@id": "990001",
        "Begin": "Friday, 06 November 2026 05:00",
        "Sport": {"#text": "Basketball"},
        "Team1": {"#text": "Home Club"},
        "Team2": {"#text": "Away Club"},
        "Tournament": {"#text": "A Cup"},
        "Category": {"#text": "Egypt"},
        "Channels": {
            "Channel": [
                {"Name": "beIN VIP", "Country": "QA"},
                {"Name": "Sky Sport", "Country": "DE"},
            ]
        },
    }
    page = RawPage(
        url=_data_url("basketball"),
        status=200,
        body=json.dumps({"Result": "OK", "Records": [record]}, ensure_ascii=False).encode(),
        content_type="text/plain",
    )

    outcome = _run("r-card", [page])

    assert outcome["items_upserted"] == 1
    stored = sync_session.execute(
        select(Match)
        .join(MatchExternalId, MatchExternalId.match_id == Match.id)
        .where(MatchExternalId.source == "sporteventz", MatchExternalId.external_id == "990001")
    ).scalar_one()
    assert _slots(sync_session, stored.id) == [(1, "Sky Sport")]
    assert any(item["reason"] == "card_sharing_label" for item in _last_run_skipped(sync_session))


def _last_run_skipped(session: Any) -> list[dict[str, Any]]:
    run = session.execute(
        select(ImportRun).where(ImportRun.source == "sporteventz").order_by(ImportRun.id.desc())
    ).scalar_one()
    return list(run.log.get("skipped", {}).get("items", []))


def test_the_unresolved_queue_does_not_grow(sync_session, loaded_snapshot) -> None:
    before = sync_session.execute(text("SELECT count(*) FROM unresolved_names")).scalar_one()

    _run()

    after = sync_session.execute(text("SELECT count(*) FROM unresolved_names")).scalar_one()
    assert after == before


def test_an_expired_key_reads_the_sport_page_once_more() -> None:
    class FakeFetcher:
        def __init__(self) -> None:
            self.gets: list[str] = []
            self.posts: list[str] = []
            self.fresh = False

        def get(self, url: str, allowed_hosts: frozenset[str]) -> RawPage:
            self.gets.append(url)
            if "?cb=" in url:
                self.fresh = True
            sport = "basketball"
            return RawPage(
                url=url,
                status=200,
                body=(FIXTURES / f"{sport}.html").read_bytes(),
                content_type="text/html",
            )

        def post(self, url: str, data: dict[str, str], allowed_hosts: frozenset[str]) -> RawPage:
            self.posts.append(url)
            expired = len(self.posts) == 1 and not self.fresh
            body = b"" if expired else b'{"Result": "OK", "Records": []}'
            return RawPage(url=url, status=200, body=body, content_type="text/plain")

    adapter = SporteventzAdapter(fetcher=FakeFetcher())
    from app.adapters.base import DateWindow

    pages = adapter.fetch(DateWindow.next_days(today=date(2026, 11, 6)))

    assert len(pages) == 8  # four sports, one page and one answer each, even after the retry
    assert len(adapter.fetcher.gets) == 5  # the first sport page was read twice
    assert "?cb=" in adapter.fetcher.gets[1]
    assert len(adapter.fetcher.posts) == 5
    # The offset the site was asked for is the one the adapter converts back from, encoded as %2B.
    assert all("client_tz_offset=%2B0300" in url for url in adapter.fetcher.posts)


def test_a_valid_empty_answer_is_quiet_until_seven_days_without_records(sync_session, loaded_snapshot) -> None:
    _run("r-1")
    assert sync_session.execute(text(SOURCE_ROW)).one() == (0, None)

    _empty_run("r-empty-1")

    assert sync_session.execute(text(SOURCE_ROW)).one() == (0, None)

    # Eight days on, a valid empty answer is the alarm that says the source went quiet.
    sync_session.execute(
        text(
            "UPDATE import_runs SET started_at = started_at - interval '8 days', "
            "finished_at = finished_at - interval '8 days' WHERE source = 'sporteventz'"
        )
    )
    _empty_run("r-empty-2")

    failures, alerted = sync_session.execute(text(SOURCE_ROW)).one()
    assert failures == 1
    assert alerted is not None


# --- skip counts and a changed record shape (B2-R1-1) --------------------------------------------


def _last_run(session: Any) -> ImportRun:
    run = (
        session.execute(select(ImportRun).where(ImportRun.source == "sporteventz").order_by(ImportRun.id.desc()))
        .scalars()
        .first()
    )
    assert run is not None
    return run


def _run_json(run: ImportRun) -> dict[str, Any]:
    assert run.raw_path is not None
    return json.loads((Path(run.raw_path) / "run.json").read_text(encoding="utf-8"))


def test_the_skip_counts_by_reason_reach_the_run_log_and_run_json(sync_session, loaded_snapshot) -> None:
    """FR-030: other sports are skipped *and counted*, and A13 and ``run.json`` show the count."""
    pages = _pages()
    rugby = {"@id": "rugby-1", "Sport": {"#text": "Rugby"}, "Begin": "Friday, 06 November 2026 05:00"}
    payload = json.loads(pages[1].body)
    payload["Records"].append(rugby)
    pages[1] = RawPage(url=pages[1].url, status=200, body=json.dumps(payload).encode(), content_type="text/plain")
    adapter = SporteventzAdapter(fetcher=None)
    items = [item for page in pages for item in adapter.parse(page)]
    result = ScrapeResult.build(
        source="sporteventz",
        run_id="r-skips",
        started_at=NOW,
        finished_at=NOW,
        fetched_on="vps2",
        pages=pages,
        items=items,
        parse_skipped=adapter.skip_counts(),
    )

    outcome = ingest.apply(args=[result.as_task_arg()]).get()

    assert outcome["status"] == "succeeded"  # an other-sport skip is expected, not a partial run
    run = _last_run(sync_session)
    assert run.log["parse_skipped"] == {"count": 1, "by_reason": {"other_sport": 1}}
    assert run.log["counts"]["parse_skipped"] == 1
    assert _run_json(run)["parse_skipped"] == {"count": 1, "by_reason": {"other_sport": 1}}


def test_a_changed_record_shape_fails_the_run_at_once_inside_the_grace(sync_session, loaded_snapshot) -> None:
    """FR-037: the 7-day quiet grace never hides a changed page; the breaker counts it."""
    _run("r-1")  # a run with records yesterday: the grace is open
    result = ScrapeResult.build(
        source="sporteventz",
        run_id="r-renamed",
        started_at=NOW,
        finished_at=NOW,
        fetched_on="vps2",
        pages=_pages(),
        items=[],
        error="layout_changed",
        parse_skipped={"missing_teams": 54},
    )

    outcome = ingest.apply(args=[result.as_task_arg()]).get()

    assert outcome["status"] == "failed"
    failures, _alerted = sync_session.execute(text(SOURCE_ROW)).one()
    assert failures == 1
    run = _last_run(sync_session)
    assert run.error == "layout_changed"
    assert run.log["parse_skipped"] == {"count": 54, "by_reason": {"missing_teams": 54}}
    assert _run_json(run)["parse_skipped"]["by_reason"] == {"missing_teams": 54}
