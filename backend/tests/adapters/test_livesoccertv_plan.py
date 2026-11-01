"""LiveSoccerTV's planning pass: which Madar matches to read (T053, R14, T071)."""

from __future__ import annotations

from datetime import UTC, datetime, timedelta

import redis

from app.adapters.livesoccertv import (
    MemoryRecentFetches,
    last_plan_log,
    plan_targets,
    store_plan_log,
)
from tests.adapters.helpers import new_lst_team, new_match, new_team

NOW = datetime(2026, 11, 7, 12, 0, tzinfo=UTC)


def _mapped_pair(session):
    """Two Madar teams, both in the dictionary, so planning has something to find."""
    home = new_team(session, "الأهلي")
    away = new_team(session, "الزمالك")
    new_lst_team(session, ar_name="الأهلي", slug="al-ahly", country="egypt", team_id=home.id)
    new_lst_team(session, ar_name="الزمالك", slug="al-zamalek", country="egypt", team_id=away.id)
    return home, away


def test_targets_are_the_matches_whose_teams_map(sync_session) -> None:
    home, away = _mapped_pair(sync_session)
    mapped = new_match(sync_session, kickoff_at=NOW + timedelta(hours=3), home_team_id=home.id, away_team_id=away.id)
    new_match(sync_session, kickoff_at=NOW + timedelta(hours=4), home="فريق غير معروف", away="آخر")

    plan = plan_targets(sync_session, now=NOW, recent=MemoryRecentFetches())

    assert [target.match_id for target in plan.targets] == [mapped.id]
    assert plan.targets[0].home_slug == "al-ahly"
    assert plan.targets[0].away_slug == "al-zamalek"
    assert plan.targets[0].country == "egypt"
    assert plan.targets[0].kickoff_at == mapped.kickoff_at
    # One unmapped match is counted, never guessed at (constitution II).
    assert len(plan.unmapped) == 1
    assert plan.mapped == 1


def test_a_team_maps_by_its_normalized_arabic_name_when_the_id_is_missing(sync_session) -> None:
    home = new_team(sync_session, "الأهلي")
    away = new_team(sync_session, "الزمالك")
    new_lst_team(sync_session, ar_name="الاهلي", slug="al-ahly", country="egypt")
    new_lst_team(sync_session, ar_name="الزمالك", slug="al-zamalek", country="egypt")
    # The match was imported without team ids: the exact normalized name is what maps it.
    new_match(sync_session, kickoff_at=NOW + timedelta(hours=2), home="الأهلي", away="الزمالك")

    plan = plan_targets(sync_session, now=NOW, recent=MemoryRecentFetches())

    assert len(plan.targets) == 1
    assert plan.targets[0].home_slug == "al-ahly"
    assert home.id != away.id


def test_matches_outside_the_window_or_not_scheduled_are_not_planned(sync_session) -> None:
    home, away = _mapped_pair(sync_session)
    new_match(sync_session, kickoff_at=NOW + timedelta(hours=50), home_team_id=home.id, away_team_id=away.id)
    new_match(
        sync_session,
        kickoff_at=NOW + timedelta(hours=2),
        home_team_id=home.id,
        away_team_id=away.id,
        status="postponed",
    )
    new_match(
        sync_session,
        kickoff_at=NOW + timedelta(hours=2),
        home_team_id=home.id,
        away_team_id=away.id,
        time_tbd=True,
    )
    assert plan_targets(sync_session, now=NOW, recent=MemoryRecentFetches()).targets == []


def test_the_t60_window_is_fifty_five_to_seventy_minutes(sync_session) -> None:
    home, away = _mapped_pair(sync_session)
    inside = new_match(sync_session, kickoff_at=NOW + timedelta(minutes=60), home_team_id=home.id, away_team_id=away.id)
    new_match(sync_session, kickoff_at=NOW + timedelta(minutes=50), home_team_id=home.id, away_team_id=away.id)
    new_match(sync_session, kickoff_at=NOW + timedelta(minutes=80), home_team_id=home.id, away_team_id=away.id)

    plan = plan_targets(sync_session, now=NOW, window="t60", recent=MemoryRecentFetches())

    assert [target.match_id for target in plan.targets] == [inside.id]


def test_a_match_planned_in_the_last_thirty_minutes_is_skipped(sync_session) -> None:
    home, away = _mapped_pair(sync_session)
    fresh = new_match(sync_session, kickoff_at=NOW + timedelta(hours=3), home_team_id=home.id, away_team_id=away.id)
    other = new_match(sync_session, kickoff_at=NOW + timedelta(hours=4), home_team_id=home.id, away_team_id=away.id)
    recent = MemoryRecentFetches(seen={fresh.id})

    plan = plan_targets(sync_session, now=NOW, recent=recent)

    assert [target.match_id for target in plan.targets] == [other.id]
    assert plan.recent == [fresh.id]
    assert {fresh.id, other.id} <= recent.marked  # both are marked, so the next pass skips them too


def test_a_run_plans_at_most_twelve_matches(sync_session) -> None:
    home, away = _mapped_pair(sync_session)
    for hour in range(1, 20):
        new_match(sync_session, kickoff_at=NOW + timedelta(hours=hour), home_team_id=home.id, away_team_id=away.id)

    plan = plan_targets(sync_session, now=NOW, recent=MemoryRecentFetches())

    assert len(plan.targets) == 12
    assert plan.targets == sorted(plan.targets, key=lambda target: (target.kickoff_at, target.match_id))


def test_the_plan_keeps_its_coverage_for_the_next_run_log() -> None:
    """The plan's mapped/unmapped counts reach the first run's ``import_runs.log`` (T071)."""
    from app.workers.config import get_worker_settings

    client = redis.Redis.from_url(get_worker_settings().broker_url, decode_responses=True)
    client.delete("lstv:plan:last")
    try:
        store_plan_log({"planned": 2, "mapped": 9, "unmapped": 1, "unmapped_sample": ["أ × ب"]}, client=client)
        assert last_plan_log(client=client) == {
            "planned": 2,
            "mapped": 9,
            "unmapped": 1,
            "unmapped_sample": ["أ × ب"],
        }
        client.set("lstv:plan:last", "not json")
        assert last_plan_log(client=client) is None
    finally:
        client.delete("lstv:plan:last")
        client.close()


def test_no_targets_is_an_empty_plan_with_no_fetch(sync_session) -> None:
    plan = plan_targets(sync_session, now=NOW, recent=MemoryRecentFetches())
    assert plan.targets == []
    assert plan.unmapped == []
    assert plan.log_payload()["planned"] == 0
