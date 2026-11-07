"""What may still go out, and which types are on (FR-017, FR-019, FR-021, research R9/R10).

Pure: the dispatcher asks one question per row, before its first page, and only acts on the answer.
The limits are FR-019's; "older" counts from ``due_at``, so a row's own hold is not its age.
"""

from __future__ import annotations

import logging
from collections.abc import Mapping
from dataclasses import dataclass
from datetime import datetime, timedelta
from typing import Any

log = logging.getLogger("madar.notifications")

LATE = "late"
MATCH_FINISHED = "match_finished"
SCORE_FELL = "score_fell"
TYPE_OFF = "type_off"

GOAL_MAX_AGE = timedelta(minutes=15)
MATCH_STARTED_MAX_AGE = timedelta(minutes=15)
FINAL_MAX_AGE = timedelta(hours=2)
ANNOUNCEMENT_MAX_AGE = timedelta(hours=2)

FINISHED = "finished"
SIDES = ("home", "away")

# SD §6.8's defaults. A type added later is on unless it appears here, as the audience query's
# COALESCE does; ``match_started`` stays off because a fan who followed a team did not ask to be
# woken at kickoff.
DEFAULT_ON: dict[str, bool] = {
    "kickoff_reminder": True,
    "match_started": False,
    "goal": True,
    "final_score": True,
    "channels_updated": True,
    "frequency_changed": True,
    "announcement": True,
}
KNOWN_TYPES = frozenset(DEFAULT_ON)


@dataclass(frozen=True, slots=True)
class Send:
    """The row is still true and useful, so it goes out."""


@dataclass(frozen=True, slots=True)
class Cancel:
    """The row must not go out; ``reason`` lands in ``notification_outbox.error`` for A15."""

    reason: str


Decision = Send | Cancel


def default_on(row_type: str) -> bool:
    """The type switch's default when the device never stored one (FR-017)."""
    return DEFAULT_ON.get(row_type, True)


def parse_types_off(value: str) -> frozenset[str]:
    """The names in ``PUSH_TYPES_OFF`` that this build knows. An unknown name is an error and ignored.

    ``PUSH_TYPES_OFF=goal,match_started`` in VPS-2's ``.env`` cancels those types' rows at dispatch
    with ``type_off``; the setting is read by the dispatcher alone, so one host covers every producer
    (FR-021, research R10). ``kickoff_reminder`` can be listed too.
    """
    names = {item.strip().lower() for item in value.split(",") if item.strip()}
    unknown = names - KNOWN_TYPES
    if unknown:
        log.error("push_types_off_unknown", extra={"names": sorted(unknown)})
    return frozenset(names & KNOWN_TYPES)


def decide(
    row_type: str,
    due_at: datetime,
    now: datetime,
    match_status: str | None,
    payload: Mapping[str, Any] | None = None,
    current_score: tuple[int, int] | None = None,
    scheduled: bool = False,
    is_test: bool = False,
) -> Decision:
    """Whether a claimed row may still go out, and if not, the short reason to store.

    A test send never goes late: the admin is watching for it (FR-016). A correction is a ``goal``
    row with ``payload.kind = "correction"``, so it reads the goal switch and has no score to fall
    behind — replacing a wrong score is its whole point (FR-009, research R4).
    """
    if is_test:
        return Send()

    data = payload or {}
    if row_type == "goal":
        if data.get("kind") == "correction":
            return Cancel(LATE) if _older_than(now, due_at, FINAL_MAX_AGE) else Send()
        if _older_than(now, due_at, GOAL_MAX_AGE):
            return Cancel(LATE)
        if match_status == FINISHED:
            return Cancel(MATCH_FINISHED)
        side = data.get("side")
        value = data.get(side) if isinstance(side, str) else None
        if (
            isinstance(side, str)
            and side in SIDES
            and isinstance(value, int)
            and current_score is not None
            and current_score[SIDES.index(side)] < value
        ):
            return Cancel(SCORE_FELL)
        return Send()

    if row_type == "match_started":
        if _older_than(now, due_at, MATCH_STARTED_MAX_AGE):
            return Cancel(LATE)
        if match_status == FINISHED:
            return Cancel(MATCH_FINISHED)
        return Send()

    if row_type == "final_score":
        return Cancel(LATE) if _older_than(now, due_at, FINAL_MAX_AGE) else Send()

    if row_type == "channels_updated":
        return Cancel(MATCH_FINISHED) if match_status == FINISHED else Send()

    if row_type == "announcement":
        if scheduled and _older_than(now, due_at, ANNOUNCEMENT_MAX_AGE):
            return Cancel(LATE)
        return Send()

    if row_type == "kickoff_reminder":
        # Today's rule: the kickoff cancels the reminder. ``due_at`` is kickoff − lead, so the
        # kickoff is read from the payload the scheduler stored (scheduler._UPSERT).
        kickoff = _kickoff(data)
        if kickoff is not None and kickoff <= now:
            return Cancel(LATE)
        return Send()

    return Send()


def _older_than(now: datetime, due_at: datetime, limit: timedelta) -> bool:
    return now - due_at > limit


def _kickoff(payload: Mapping[str, Any]) -> datetime | None:
    value = payload.get("kickoff_at")
    if not isinstance(value, str):
        return None
    try:
        return datetime.fromisoformat(value)
    except ValueError:
        return None
