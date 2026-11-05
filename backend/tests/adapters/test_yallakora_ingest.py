"""A YallaKora run end to end: saved pages through ``adapters.ingest`` (D5 T060's rules, SC-006)."""

from __future__ import annotations

import json
from datetime import UTC, datetime
from pathlib import Path
from typing import Any

import pytest
from sqlalchemy import func, select, text

from app.adapters.base import RawPage
from app.adapters.config import get_adapter_settings
from app.adapters.messages import ScrapeResult
from app.adapters.resolve import resolve_team
from app.adapters.tasks import ingest
from app.adapters.yallakora import LIST_URL, YallakoraAdapter
from app.db.models import Channel, Competition, ImportRun, Match, MatchExternalId, Team

FIXTURES = Path(__file__).resolve().parents[1] / "fixtures" / "yallakora"
NOW = datetime(2026, 11, 4, 12, 0, tzinfo=UTC)


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
    get_adapter_settings.cache_clear()
    yield
    get_adapter_settings.cache_clear()


def _run(run_id: str = "r-1") -> dict[str, Any]:
    adapter = YallakoraAdapter(fetcher=None)
    pages = [
        RawPage(url=f"{LIST_URL}?date={day}", status=200, body=(FIXTURES / f"{day}.html").read_bytes(), fetched_at=NOW)
        for day in ("2026-11-04", "2027-07-21")
    ]
    result = ScrapeResult.build(
        source="yallakora",
        run_id=run_id,
        started_at=NOW,
        finished_at=NOW,
        fetched_on="vps2",
        pages=pages,
        items=[item for page in pages for item in adapter.parse(page)],
    )
    return ingest.apply(args=[result.as_task_arg()]).get()


def _cards() -> list[Any]:
    adapter = YallakoraAdapter(fetcher=None)
    pages = [
        RawPage(url=f"{LIST_URL}?date={day}", status=200, body=(FIXTURES / f"{day}.html").read_bytes(), fetched_at=NOW)
        for day in ("2026-11-04", "2027-07-21")
    ]
    return [item for page in pages for item in adapter.parse(page)]


def _add_every_team(session: Any, *, but: tuple[str | None, ...] = ()) -> None:
    """As after an editor has worked the queue: a card whose names all resolve can be stored or linked."""
    for name in sorted({name for card in _cards() for name in (card.home, card.away)} - set(but)):
        found = resolve_team(session, external_id=None, name=name, competition_name=None, source="yallakora")
        if found.entity_id is None:
            session.add(Team(name=name))
    session.flush()


def _count(session: Any, model: Any) -> int:
    return session.execute(select(func.count()).select_from(model)).scalar_one()


def test_cards_with_names_we_cannot_resolve_wait_in_the_queue_and_add_no_row(sync_session, loaded_snapshot) -> None:
    """05 Nov 2026: 75 rows from one run, because a different spelling looked like a new fixture."""
    before = {model: _count(sync_session, model) for model in (Team, Competition, Channel, Match)}

    outcome = _run()

    assert outcome["status"] == "succeeded"
    assert outcome["items_upserted"] == 0
    assert {model: _count(sync_session, model) for model in before} == before
    queued = sync_session.execute(
        text("SELECT count(*) FROM unresolved_names WHERE source = 'yallakora' AND kind = 'team'")
    ).scalar_one()
    assert queued > 0


def test_a_run_stores_fixtures_broadcasters_and_queue_rows_and_creates_no_entity(sync_session, loaded_snapshot) -> None:
    _add_every_team(sync_session)
    before = {model: _count(sync_session, model) for model in (Team, Competition, Channel)}

    outcome = _run()

    assert outcome["status"] == "succeeded"
    assert outcome["items_upserted"] == 16
    # SC-006: 0 new teams, competitions or channels.
    assert {model: _count(sync_session, model) for model in before} == before

    run = sync_session.execute(select(ImportRun).where(ImportRun.source == "yallakora")).scalar_one()
    assert (run.status, run.items_found) == ("succeeded", 16)
    assert run.raw_path is not None

    match = sync_session.execute(
        select(Match)
        .join(MatchExternalId, MatchExternalId.match_id == Match.id)
        .where(MatchExternalId.source == "yallakora", MatchExternalId.external_id == "114019")
    ).scalar_one()
    assert match.kickoff_at == datetime(2026, 11, 4, 15, 0, tzinfo=UTC)
    assert match.status == "scheduled"
    assert (match.home_score, match.away_score) == (None, None)
    broadcaster = sync_session.execute(
        text("SELECT local_broadcaster_eg FROM matches WHERE id = :id"), {"id": match.id}
    ).scalar_one()
    assert broadcaster == "ON Sport MAX"

    queued = sync_session.execute(
        text("SELECT kind, count(*) FROM unresolved_names WHERE source = 'yallakora' GROUP BY kind")
    ).all()
    assert {kind for kind, _ in queued} <= {"team", "competition"}
    assert sum(count for _, count in queued) > 0


def test_a_second_run_raises_the_counts_and_duplicates_nothing(sync_session, loaded_snapshot) -> None:
    _add_every_team(sync_session)
    _run("r-1")
    matches = _count(sync_session, Match)
    rows = sync_session.execute(text("SELECT count(*), sum(seen_count) FROM unresolved_names")).one()

    outcome = _run("r-2")

    assert outcome["items_upserted"] == 0
    assert _count(sync_session, Match) == matches
    again = sync_session.execute(text("SELECT count(*), sum(seen_count) FROM unresolved_names")).one()
    assert again[0] == rows[0]
    assert again[1] > rows[1]


def test_a_card_that_waits_on_an_editor_is_listed_and_the_run_still_succeeds(
    sync_session, loaded_snapshot, tmp_path: Path
) -> None:
    """Waiting isn't a failed item, so the run isn't ``partial`` and ``run.json`` says who waits (B2-R1-1)."""
    card = next(
        item
        for item in _cards()
        if resolve_team(
            sync_session, external_id=None, name=item.home, competition_name=item.competition, source="yallakora"
        ).entity_id
        is None
    )
    _add_every_team(sync_session, but=(card.home,))
    held = Match(
        source="ysscores",
        match_date=card.match_date,
        kickoff_at=None,
        time_tbd=True,
        competition_name="أخرى",
        home_team_name=card.home,
        away_team_name=card.away,
    )
    sync_session.add(held)
    sync_session.flush()

    outcome = _run()

    assert outcome["status"] == "succeeded"
    assert outcome["items_upserted"] == 15
    run = sync_session.execute(select(ImportRun).where(ImportRun.source == "yallakora")).scalar_one()
    info = json.loads((tmp_path / run.raw_path / "run.json").read_text(encoding="utf-8"))
    assert info["waiting"] == [{"ref": card.external_id, "reason": "unresolved_team"}]
    assert run.log["waiting"]["items"] == info["waiting"]  # on disk only, an editor would never see why
    linked = sync_session.execute(
        select(MatchExternalId).where(MatchExternalId.source == "yallakora", MatchExternalId.match_id == held.id)
    ).first()
    assert linked is None
