"""The push producers: they decide and insert ``notification_outbox`` rows, and never send (research R3).

Two callers: the live poller (``app/live/cycle.py``, inside the match's transaction, after
``apply_decision``) and an editor's save (``matches.update`` and ``channels.update``, through
``writer.save_update``'s ``then``). Every row is inserted with ``ON CONFLICT (dedupe_key) DO NOTHING``,
so a retry, an overlapping poll or a second save never sends twice (SC-003).

The poller's call runs inside ``session.begin_nested()``: an error here rolls back only the push work
and ``push_memory``, and the score still commits (FR-008). The next poll tries again.
"""

from __future__ import annotations

import logging
from collections.abc import Mapping, Sequence
from datetime import datetime, timedelta
from typing import Any

from sqlalchemy import select
from sqlalchemy.dialects.postgresql import insert
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import Session

from app.db.models import Channel, Match, MatchLiveState, NotificationOutbox
from app.notifications.goal_bar import Reading, evaluate
from app.services.admin import versions

log = logging.getLogger("madar.notifications.producers")

# A hold that batches channel and frequency changes before one push (FR-010, FR-014).
HOLD = timedelta(minutes=5)
# A match_started more than this after kickoff is not news any more (FR-003).
STARTED_WINDOW = timedelta(minutes=15)
IN_PLAY = ("live", "halftime", "extra_time", "penalties")
FINAL_STATUSES = ("finished", "cancelled", "abandoned")
# A score an editor set by hand or locked against importers is not the bar's to judge (FR-006).
SCORE_FIELDS = ("home_score", "away_score")


def _row(
    *,
    row_type: str,
    key: str,
    payload: Mapping[str, Any],
    audience: Mapping[str, Any],
    due_at: datetime,
    audit_log_id: int | None = None,
) -> dict[str, Any]:
    return {
        "type": row_type,
        "dedupe_key": key,
        "payload": dict(payload),
        "audience": dict(audience),
        "due_at": due_at,
        "status": "pending",
        "audit_log_id": audit_log_id,
    }


def _insert(session: Session, values: dict[str, Any]) -> bool:
    """``ON CONFLICT (dedupe_key) DO NOTHING``: ``True`` when this call wrote the row."""
    result = session.execute(
        insert(NotificationOutbox).values(**values).on_conflict_do_nothing(index_elements=["dedupe_key"])
    )
    return bool(getattr(result, "rowcount", 0))


async def _insert_async(session: AsyncSession, values: dict[str, Any]) -> bool:
    result = await session.execute(
        insert(NotificationOutbox).values(**values).on_conflict_do_nothing(index_elements=["dedupe_key"])
    )
    return bool(getattr(result, "rowcount", 0))


# --- The poller -------------------------------------------------------------------------------------


def _readings(readings: Sequence[Any]) -> list[Reading]:
    return [
        Reading(source=reading.source, home=reading.score.home, away=reading.score.away)
        for reading in readings
        if reading.score is not None
    ]


def _accepted(match: Match) -> tuple[int, int] | None:
    """The pushed score's reference: a real stored score, never a clock estimate (FR-006)."""
    if match.home_score is None or match.away_score is None:
        return None
    return int(match.home_score), int(match.away_score)


def _manual_or_locked(match: Match) -> bool:
    return match.status_source == "manual" or bool(set(match.locked_fields or ()) & set(SCORE_FIELDS))


def _sent_this_generation(session: Session, match_id: int, generation: int) -> bool:
    """A correction goes out only when followers heard the score it corrects (research R9)."""
    rows = session.execute(
        select(NotificationOutbox.dedupe_key).where(
            NotificationOutbox.type == "goal",
            NotificationOutbox.status == "sent",
            NotificationOutbox.dedupe_key.like(f"goal:{match_id}:{generation}:%"),
        )
    ).first()
    if rows is not None:
        return True
    return (
        session.execute(
            select(NotificationOutbox.id).where(
                NotificationOutbox.dedupe_key == f"final_score:{match_id}",
                NotificationOutbox.status == "sent",
            )
        ).first()
        is not None
    )


def record_poll(
    session: Session,
    match: Match,
    readings: Sequence[Any],
    now: datetime,
    *,
    status_before: str | None = None,
) -> int:
    """The poller's producer: match start, goals, corrections and the final score. Returns rows written.

    ``readings`` is what the poll saw, one per usable source; the bar never reads a shoot-out count.
    ``status_before`` is the row's status before this poll applied its decision: ``final_score`` is
    written only by the poll that moved the row to ``finished`` (FR-007), so a row the watchdog
    finished, or a finished row polled again, never gets one. ``None`` (unknown) writes none.
    """
    live = session.get(MatchLiveState, match.id)
    memory: dict[str, Any] = dict(live.push_memory or {}) if live is not None else {}
    was_empty = memory.get("home") is None or memory.get("away") is None
    written = 0

    # ``live_seen``: absent before the first evaluation, ``False`` once the producers saw the match
    # before it was in play, ``True`` once they saw it in play. Only a match whose first evaluation is
    # already in play is a silent baseline (B1-R1-1): a scheduled match has no score, so the score
    # baseline alone can't tell "first look" from "kickoff" (FR-003).
    in_play = match.status in IN_PLAY
    if in_play and match.status_source != "clock":
        kickoff = match.kickoff_at
        seen_before_kickoff = memory.get("live_seen") is False or (not was_empty and "live_seen" not in memory)
        due = (
            seen_before_kickoff
            and match.status_source == "feed"
            and kickoff is not None
            and now - kickoff <= STARTED_WINDOW
        )
        if due:
            written += int(
                _insert(
                    session,
                    _row(
                        row_type="match_started",
                        key=f"match_started:{match.id}",
                        payload={"match_id": match.id},
                        audience={"kind": "match_core", "match_id": match.id},
                        due_at=now,
                    ),
                )
            )
        memory["live_seen"] = True
    elif not in_play and match.status not in FINAL_STATUSES and "live_seen" not in memory:
        memory["live_seen"] = False

    accepted = None if match.status == "penalties" else _accepted(match)
    memory, messages = evaluate(
        memory,
        accepted,
        _readings(readings),
        now,
        manual=_manual_or_locked(match),
        status=match.status,
    )
    for message in messages:
        if message.kind == "correction":
            if not _sent_this_generation(session, match.id, message.generation):
                continue
            payload = {
                "match_id": match.id,
                "kind": "correction",
                "home": message.home,
                "away": message.away,
                "generation": message.generation,
            }
        else:
            payload = {
                "match_id": match.id,
                "side": message.side,
                "home": message.home,
                "away": message.away,
                "generation": message.generation,
            }
        written += int(
            _insert(
                session,
                _row(
                    row_type="goal",
                    key=message.dedupe_key(match.id),
                    payload=payload,
                    audience={"kind": "match_core", "match_id": match.id},
                    due_at=now,
                ),
            )
        )

    if live is not None:
        live.push_memory = memory

    if status_before is not None and status_before != "finished":
        written += _final_score(session, match, now)
    return written


def _final_score(session: Session, match: Match, now: datetime) -> int:
    """A real final score from the feed, from the poll that finished the row (FR-007)."""
    if match.status != "finished" or match.status_source != "feed" or _accepted(match) is None:
        return 0
    return int(
        _insert(
            session,
            _row(
                row_type="final_score",
                key=f"final_score:{match.id}",
                payload={"match_id": match.id},
                audience={"kind": "match_core", "match_id": match.id},
                due_at=now,
            ),
        )
    )


# --- An editor's save (async: the admin API) --------------------------------------------------------


async def record_editor_status(session: AsyncSession, match: Match, now: datetime) -> None:
    """Called from ``matches.update`` through ``then``, under the match's row lock (FR-009).

    A manual ``finished`` with a real score always adds ``final_score``, even before any poll stored a
    state row (FR-007). A score below what was pushed gives one correction with generation + 1, and any
    other score moves ``pushed`` and sends nothing; with no state row nothing was pushed, so there is
    nothing to correct.
    """
    accepted = _accepted(match)
    if accepted is None:
        return

    if match.status == "finished":
        await _insert_async(
            session,
            _row(
                row_type="final_score",
                key=f"final_score:{match.id}",
                payload={"match_id": match.id},
                audience={"kind": "match_core", "match_id": match.id},
                due_at=now,
            ),
        )

    live = await session.get(MatchLiveState, match.id, populate_existing=True)
    if live is None:
        return
    memory: dict[str, Any] = dict(live.push_memory or {})
    pushed_home = memory.get("home")
    pushed_away = memory.get("away")
    if pushed_home is None or pushed_away is None:
        live.push_memory = {**memory, "home": accepted[0], "away": accepted[1], "generation": 0}
        return

    generation = int(memory.get("generation") or 0)
    if accepted[0] < int(pushed_home) or accepted[1] < int(pushed_away):
        sent = await session.scalar(
            select(NotificationOutbox.id)
            .where(
                NotificationOutbox.type == "goal",
                NotificationOutbox.status == "sent",
                NotificationOutbox.dedupe_key.like(f"goal:{match.id}:{generation}:%"),
            )
            .limit(1)
        )
        final_sent = await session.scalar(
            select(NotificationOutbox.id).where(
                NotificationOutbox.dedupe_key == f"final_score:{match.id}",
                NotificationOutbox.status == "sent",
            )
        )
        if sent is not None or final_sent is not None:
            await _insert_async(
                session,
                _row(
                    row_type="goal",
                    key=f"goal_correction:{match.id}:{generation}",
                    payload={
                        "match_id": match.id,
                        "kind": "correction",
                        "home": accepted[0],
                        "away": accepted[1],
                        "generation": generation,
                    },
                    audience={"kind": "match_core", "match_id": match.id},
                    due_at=now,
                ),
            )
        generation += 1

    live.push_memory = {**memory, "home": accepted[0], "away": accepted[1], "generation": generation}


# --- Frequency changes (research R6) ----------------------------------------------------------------


def _tuning(state: Mapping[str, Any] | None) -> tuple[int, str, int] | None:
    if not isinstance(state, Mapping):
        return None
    mhz, polarization, symbol_rate = (
        state.get("frequency_mhz"),
        state.get("polarization"),
        state.get("symbol_rate"),
    )
    if mhz is None or polarization is None or symbol_rate is None:
        return None
    return int(mhz), str(polarization), int(symbol_rate)


def frequency_diff(before: Mapping[str, Any], after: Mapping[str, Any]) -> tuple[dict[str, Any], dict[str, Any]] | None:
    """Both sides complete and at least one of the three values different, else ``None``.

    A note-only edit, an empty side and a snapshot load never count (contracts/push-pipeline).
    """
    old = _tuning(before)
    new = _tuning(after)
    if old is None or new is None or old == new:
        return None
    return (
        {"mhz": old[0], "pol": old[1], "sr": old[2]},
        {"mhz": new[0], "pol": new[1], "sr": new[2]},
    )


def _frequency_row(channel: Channel, old: dict[str, Any], audit_id: int, now: datetime) -> dict[str, Any]:
    return _row(
        row_type="frequency_changed",
        key=f"frequency_changed:{channel.id}:{audit_id}",
        payload={"channel_id": channel.id, "old": old},
        audience={"kind": "channel", "channel_id": channel.id},
        due_at=now + HOLD,
        audit_log_id=audit_id,
    )


async def frequency_hold(
    session: AsyncSession, channel: Channel, before: Mapping[str, Any], audit_id: int, now: datetime
) -> int:
    """A8's save, through ``then``: one pending row per channel, keyed on the save's audit row."""
    pending = await session.scalar(
        select(NotificationOutbox.id).where(
            NotificationOutbox.type == "frequency_changed",
            NotificationOutbox.status == "pending",
            NotificationOutbox.audience["channel_id"].astext == str(channel.id),
        )
    )
    if pending is not None:
        return 0
    diff = frequency_diff(before, versions.row_state(channel))
    if diff is None:
        return 0
    return int(await _insert_async(session, _frequency_row(channel, diff[0], audit_id, now)))


def current_tuning(channel: Channel) -> dict[str, Any]:
    return {
        "frequency_mhz": channel.frequency_mhz,
        "polarization": channel.polarization,
        "symbol_rate": channel.symbol_rate,
    }


__all__ = [
    "HOLD",
    "current_tuning",
    "frequency_diff",
    "frequency_hold",
    "record_editor_status",
    "record_poll",
]
