"""Which matches get a page this cycle (T025)."""

from __future__ import annotations

from datetime import UTC, datetime, timedelta

from app.live.pick import SlotCandidate, pick_slots
from app.live.robots import FILGOAL_HOST, YALLAKORA_HOST

KICKOFF = datetime(2026, 11, 4, 20, 0, tzinfo=UTC)


def item(match_id, *, priority=None, minutes=0, slot=False, path="/matches/1/coverage/"):
    return SlotCandidate(match_id, path, priority, KICKOFF + timedelta(minutes=minutes), slot)


def ids(found):
    return [candidate.match_id for candidate in found]


def test_existing_slots_then_priority_then_the_earlier_kickoff_up_to_the_cap():
    found = pick_slots(
        [
            item(1, priority=9, slot=True),
            item(2, priority=1, minutes=30),
            item(3, priority=1, minutes=0),
            item(4, priority=None),
            item(5, priority=2),
        ],
        host=FILGOAL_HOST,
        cap=4,
    )

    assert ids(found) == [1, 3, 2, 5]


def test_a_match_keeps_its_slot_when_a_more_important_one_arrives():
    found = pick_slots([item(1, priority=50, slot=True), item(2, priority=1)], host=FILGOAL_HOST, cap=1)

    assert ids(found) == [1]


def test_a_blocked_path_or_no_path_gets_no_slot():
    found = pick_slots(
        [item(1, path="/champions/1/match/1/"), item(2, path=None), item(3, path="/egypt-cup/1/match/3/")],
        host=YALLAKORA_HOST,
        cap=5,
    )

    assert ids(found) == [3]


def test_a_cap_of_zero_gets_none():
    assert pick_slots([item(1)], host=FILGOAL_HOST, cap=0) == []
