"""``MatchDetail.events``, ``.lineups`` and ``local_broadcaster_eg`` (T003, contracts/public-api.md)."""

from __future__ import annotations

from datetime import timedelta

from app.db.models import MatchEvent, MatchLineup, MatchLiveState


async def _feed_match(make_match, session, now, **fields):
    bag = await make_match(now, kickoff_in=timedelta(minutes=-30), status="live", status_source="feed", links=False)
    bag.match.period = "1H"
    bag.match.minute = "30"
    bag.match.home_score = 1
    bag.match.away_score = 0
    for key, value in fields.items():
        setattr(bag.match, key, value)
    await session.flush()
    return bag.match


def _event(
    match_id: int,
    ext: str,
    type_: str,
    minute: str,
    side: str = "home",
    player: str | None = "لاعب",
    source: str = "filgoal",
) -> MatchEvent:
    return MatchEvent(
        match_id=match_id, side=side, type=type_, minute=minute, player_name=player, source=source, external_id=ext
    )


async def test_events_and_lineups_come_from_stored_rows_in_minute_order(public_client, session, make_match, frozen_now):
    match = await _feed_match(make_match, session, frozen_now)
    session.add_all(
        [
            _event(match.id, "c", "red_card", "90+2", side="away"),
            _event(match.id, "a", "goal", "9"),
            _event(match.id, "b", "goal", "45+1", player=None),
            MatchLineup(
                match_id=match.id,
                side="home",
                formation="4-3-3",
                players=[{"name": "حارس", "number": 1, "position": "GK", "is_starter": True}],
                source="filgoal",
            ),
        ]
    )
    await session.flush()

    data = (await public_client.get(f"/v1/matches/{match.id}")).json()["data"]

    assert data["events"] == [
        {"type": "goal", "side": "home", "minute": "9", "player": "لاعب"},
        {"type": "goal", "side": "home", "minute": "45+1", "player": None},
        {"type": "red_card", "side": "away", "minute": "90+2", "player": "لاعب"},
    ]
    assert data["lineups"] == {
        "home": {
            "formation": "4-3-3",
            "players": [{"name": "حارس", "number": 1, "position": "GK", "is_starter": True}],
        },
        "away": None,
    }


async def test_none_stored_gives_an_empty_list_and_null(public_client, session, make_match, frozen_now):
    match = await _feed_match(make_match, session, frozen_now)

    data = (await public_client.get(f"/v1/matches/{match.id}")).json()["data"]

    assert data["events"] == []
    assert data["lineups"] is None


async def test_an_estimated_match_shows_neither(public_client, session, make_match, frozen_now):
    bag = await make_match(frozen_now, kickoff_in=timedelta(minutes=-30), links=False)
    session.add_all(
        [
            _event(bag.match.id, "a", "goal", "9"),
            MatchLineup(match_id=bag.match.id, side="home", formation=None, players=[], source="filgoal"),
        ]
    )
    await session.flush()

    data = (await public_client.get(f"/v1/matches/{bag.match.id}")).json()["data"]

    assert data["estimated"] is True
    assert data["events"] == []
    assert data["lineups"] is None


async def test_goal_events_stay_during_a_drop_and_with_an_old_candidate(public_client, session, make_match, frozen_now):
    """A rise has no pending state now, and a false score's goal goes with the score, not before it."""
    match = await _feed_match(make_match, session, frozen_now)
    session.add_all(
        [
            _event(match.id, "a", "goal", "9"),
            _event(match.id, "b", "own_goal", "10"),
            _event(match.id, "c", "penalty", "11"),
            _event(match.id, "d", "missed_penalty", "12"),
            _event(match.id, "e", "red_card", "13"),
            MatchLiveState(
                match_id=match.id,
                candidate={"home": 2, "away": 0, "source": "filgoal", "polls": 1},
                drop_since=frozen_now,
            ),
        ]
    )
    await session.flush()

    data = (await public_client.get(f"/v1/matches/{match.id}")).json()["data"]

    assert [event["type"] for event in data["events"]] == ["goal", "own_goal", "penalty", "missed_penalty", "red_card"]


async def test_events_come_from_filgoal_when_it_has_any_and_never_from_both(
    public_client, session, make_match, frozen_now
):
    match = await _feed_match(make_match, session, frozen_now)
    session.add_all(
        [
            _event(match.id, "a", "goal", "9", player="من فيلجول"),
            _event(match.id, "x", "goal", "9", player="من جول", source="goal"),
            _event(match.id, "y", "red_card", "40", source="goal"),
        ]
    )
    await session.flush()

    data = (await public_client.get(f"/v1/matches/{match.id}")).json()["data"]

    assert data["events"] == [{"type": "goal", "side": "home", "minute": "9", "player": "من فيلجول"}]


async def test_events_come_from_goal_com_when_filgoal_has_none(public_client, session, make_match, frozen_now):
    match = await _feed_match(make_match, session, frozen_now)
    session.add(_event(match.id, "x", "goal", "9", player="من جول", source="goal"))
    await session.flush()

    data = (await public_client.get(f"/v1/matches/{match.id}")).json()["data"]

    assert data["events"] == [{"type": "goal", "side": "home", "minute": "9", "player": "من جول"}]


async def test_local_broadcaster_is_returned_when_stored(public_client, session, make_match, frozen_now):
    match = await _feed_match(make_match, session, frozen_now, local_broadcaster_eg="أون تايم سبورت")

    data = (await public_client.get(f"/v1/matches/{match.id}")).json()["data"]

    assert data["local_broadcaster_eg"] == "أون تايم سبورت"
