"""``repair-matches``: folding a copy into the row it copied, and filling teams already decided in A13.

YallaKora's first runs on 05 Nov 2026 added 74 copies of fixtures we held, under other spellings, before the
importer learned to wait. The copies have the score and the links, and the originals have the channels, so fans
see half a match twice.

A merge takes pairs a person reviewed, never a guess. The constitution says matches are never deleted and a
trigger enforces it. The owner approved one exception on 2026-11-05: these copies, empty once merged and hours
old, aren't history, and each audit row keeps what its copy held. So a merge refuses any row outside that
incident, and the trigger is off only inside its transaction, where a rollback restores it. Delete this module's
merge once it has run.
"""

from __future__ import annotations

from collections.abc import Sequence
from dataclasses import dataclass, field
from datetime import UTC, datetime, timedelta
from typing import Any

from sqlalchemy import delete, exists, select, text, update
from sqlalchemy.orm import Session, aliased

from app.adapters.health import bump_datasets
from app.db.models import (
    AuditLog,
    DeviceFollow,
    Feed,
    LiveProblem,
    Match,
    MatchChannel,
    MatchCustomBroadcast,
    MatchEvent,
    MatchExternalId,
    MatchLineup,
    MatchLiveState,
    MatchSourceReading,
    MatchStats,
    UnresolvedName,
)
from app.services.match_teams import empty_team_updates

COPYING_SOURCE = "yallakora"
# The exception the owner approved: the runs that made the copies, and nothing created before or after them.
COPIES_FROM = datetime(2026, 11, 5, 13, 46, tzinfo=UTC)
COPIES_UNTIL = datetime(2026, 11, 5, 14, 21, tzinfo=UTC)
# Waiting for the lock on ``matches`` stops every writer behind us, so give up rather than queue for long.
LOCK_TIMEOUT = "10s"
# A kickoff can differ between sources, as PSG v Troyes does by 20 minutes, but a fixture doesn't move further.
MOST_KICKOFF_GAP = timedelta(hours=3)
LIVE_FIELDS = (
    "is_live",
    "status",
    "period",
    "minute",
    "home_score",
    "away_score",
    "home_pen",
    "away_pen",
    "status_source",
    "status_label",
    "status_updated_at",
)
FILLED_IF_EMPTY = (
    "home_team_id",
    "away_team_id",
    "competition_id",
    "home_logo_asset_id",
    "away_logo_asset_id",
    "local_broadcaster_eg",
)
KEPT_IN_THE_AUDIT = (
    "source",
    "kickoff_at",
    "competition_name",
    "home_team_id",
    "home_team_name",
    "away_team_id",
    "away_team_name",
    *(name for name in LIVE_FIELDS if name != "is_live"),
    "local_broadcaster_eg",
)
# (table, the columns that clash on the kept row). A clash means the kept row already has that fact.
MOVED_ROWS: tuple[tuple[Any, tuple[str, ...]], ...] = (
    (MatchChannel, ("channel_id",)),
    (MatchCustomBroadcast, ("slot",)),
    (MatchEvent, ("source", "external_id")),
    (MatchLineup, ("side",)),
    (MatchStats, ("source",)),
    (MatchSourceReading, ("source",)),
    (DeviceFollow, ("device_id", "team_id", "competition_id", "channel_id", "commentator_id")),
)


class RepairRefused(Exception):
    """This pair isn't what a merge is for. The caller rolls everything back."""


@dataclass(frozen=True, slots=True)
class MergeResult:
    keep_id: int
    drop_id: int
    filled: dict[str, Any]
    live_copied: bool
    differs: dict[str, list[Any]]


@dataclass(slots=True)
class FillResult:
    filled: list[tuple[int, str, int]] = field(default_factory=list)
    ambiguous: list[tuple[str, str]] = field(default_factory=list)


def _json_value(value: Any) -> Any:
    return value.isoformat() if isinstance(value, datetime) else value


def _locked_pair(session: Session, keep_id: int, drop_id: int) -> tuple[Match, Match]:
    if keep_id == drop_id:
        raise RepairRefused(f"{keep_id} can't be merged into itself")
    # In id order, so two runs can't deadlock on the same pair.
    rows = session.scalars(
        select(Match).where(Match.id.in_((keep_id, drop_id))).order_by(Match.id).with_for_update()
    ).all()
    found = {row.id: row for row in rows}
    if keep_id not in found or drop_id not in found:
        raise RepairRefused(f"no such pair: {keep_id}, {drop_id}")
    return found[keep_id], found[drop_id]


def _check_it_is_a_copy(keep: Match, drop: Match) -> None:
    if drop.source != COPYING_SOURCE:
        raise RepairRefused(f"{drop.id} came from {drop.source}, not {COPYING_SOURCE}")
    if not COPIES_FROM <= drop.created_at < COPIES_UNTIL:
        raise RepairRefused(f"{drop.id} wasn't made by the runs of 05 Nov 2026, so it isn't covered by the exception")
    if keep.kickoff_at is None or drop.kickoff_at is None:
        raise RepairRefused(f"{keep.id} and {drop.id} need a kickoff each to compare")
    if abs(keep.kickoff_at - drop.kickoff_at) > MOST_KICKOFF_GAP:
        raise RepairRefused(f"{keep.id} and {drop.id} kick off more than {MOST_KICKOFF_GAP} apart")


def _move_rows(session: Session, model: Any, clashes: tuple[str, ...], keep_id: int, drop_id: int) -> None:
    other = aliased(model)
    same = [getattr(other, name).is_not_distinct_from(getattr(model, name)) for name in clashes]
    taken = exists().where(other.match_id == keep_id, *same)
    session.execute(
        update(model)
        .where(model.match_id == drop_id, ~taken)
        .values(match_id=keep_id)
        .execution_options(synchronize_session=False)
    )
    session.execute(delete(model).where(model.match_id == drop_id).execution_options(synchronize_session=False))


def _drop_older_readings(session: Session, keep_id: int, drop_id: int) -> None:
    """Per source, the newer reading is the one the next poll compares with."""
    newer = aliased(MatchSourceReading)
    is_newer = exists().where(
        newer.match_id == drop_id,
        newer.source == MatchSourceReading.source,
        newer.read_at > MatchSourceReading.read_at,
    )
    session.execute(
        delete(MatchSourceReading)
        .where(MatchSourceReading.match_id == keep_id, is_newer)
        .execution_options(synchronize_session=False)
    )


def _copy_live(session: Session, keep: Match, drop: Match) -> bool:
    """A polled copy knows the match, and the row with channels is still on the clock. An editor's status wins."""
    if drop.status_source != "feed" or keep.status_source != "clock" or "status" in (keep.locked_fields or []):
        session.execute(delete(MatchLiveState).where(MatchLiveState.match_id == drop.id))
        return False
    for name in LIVE_FIELDS:
        setattr(keep, name, getattr(drop, name))
    session.execute(delete(MatchLiveState).where(MatchLiveState.match_id == keep.id))
    session.execute(update(MatchLiveState).where(MatchLiveState.match_id == drop.id).values(match_id=keep.id))
    return True


def _fill_empty(keep: Match, drop: Match) -> tuple[dict[str, Any], dict[str, list[Any]]]:
    filled: dict[str, Any] = {}
    differs: dict[str, list[Any]] = {}
    for name in FILLED_IF_EMPTY:
        kept, copied = getattr(keep, name), getattr(drop, name)
        if copied is None or kept == copied:
            continue
        if kept is not None:
            differs[name] = [kept, copied]
        elif name not in (keep.locked_fields or []):
            setattr(keep, name, copied)
            filled[name] = [None, copied]
    return filled, differs


def _audit(session: Session, entity_id: int, action: str, diff: dict[str, Any]) -> None:
    session.add(
        AuditLog(admin_user_id=None, source=None, entity="matches", entity_id=entity_id, action=action, diff=diff)
    )


def merge_pairs(session: Session, pairs: Sequence[tuple[int, int]], now: datetime) -> list[MergeResult]:
    """Every ``(keep, drop)`` pair, or the caller rolls all of it back, which also restores the trigger."""
    session.execute(text("SELECT set_config('lock_timeout', :timeout, true)"), {"timeout": LOCK_TIMEOUT})
    session.execute(text("ALTER TABLE matches DISABLE TRIGGER matches_forbid_delete"))
    results = [_merge_pair(session, keep_id=keep_id, drop_id=drop_id, now=now) for keep_id, drop_id in pairs]
    session.execute(text("ALTER TABLE matches ENABLE TRIGGER matches_forbid_delete"))
    return results


def _merge_pair(session: Session, *, keep_id: int, drop_id: int, now: datetime) -> MergeResult:
    keep, drop = _locked_pair(session, keep_id, drop_id)
    _check_it_is_a_copy(keep, drop)
    held = {name: _json_value(getattr(drop, name)) for name in KEPT_IN_THE_AUDIT}

    session.execute(update(MatchExternalId).where(MatchExternalId.match_id == drop_id).values(match_id=keep_id))
    session.execute(update(Feed).where(Feed.match_id == drop_id).values(match_id=keep_id))
    _drop_older_readings(session, keep_id, drop_id)
    for model, clashes in MOVED_ROWS:
        _move_rows(session, model, clashes, keep_id, drop_id)
    live_copied = _copy_live(session, keep, drop)
    filled, differs = _fill_empty(keep, drop)
    keep.updated_at = now
    session.execute(
        update(LiveProblem)
        .where(LiveProblem.key.in_((f"stale:{drop_id}", f"disagree:{drop_id}", f"stuck:{drop_id}")))
        .where(LiveProblem.closed_at.is_(None))
        .values(closed_at=now)
    )
    session.flush()

    session.expunge(drop)
    session.execute(delete(Match).where(Match.id == drop_id))
    _audit(session, keep_id, "update", {"merged_from": drop_id, **filled, "live_copied": live_copied})
    _audit(session, drop_id, "delete", {"merged_into": keep_id, **held})
    session.flush()
    bump_datasets(session, ["matches", "live"])
    return MergeResult(keep_id, drop_id, filled, live_copied, differs)


def fill_teams(session: Session, now: datetime) -> FillResult:
    """What ``map_name`` now does at once, for names decided before it did. A name decided two ways is left."""
    result = FillResult()
    rows = session.execute(
        select(UnresolvedName.name_norm, UnresolvedName.competition_norm, UnresolvedName.target_id)
        .where(
            UnresolvedName.kind == "team",
            UnresolvedName.state.in_(("mapped", "created")),
            UnresolvedName.target_id.is_not(None),
        )
        .distinct()
    ).all()
    decided: dict[tuple[str, str], set[int]] = {}
    for name_norm, competition_norm, target_id in rows:
        assert target_id is not None  # filtered above
        decided.setdefault((name_norm, competition_norm), set()).add(target_id)
    for (name_norm, competition_norm), targets in sorted(decided.items()):
        if len(targets) > 1:
            result.ambiguous.append((name_norm, competition_norm))
            continue
        team_id = next(iter(targets))
        for side, statement in empty_team_updates(name_norm, competition_norm, team_id, now):
            for match_id in session.scalars(statement).all():
                result.filled.append((match_id, side, team_id))
                _audit(session, match_id, "update", {side: [None, team_id]})
    if result.filled:
        session.flush()
        bump_datasets(session, ["matches"])
    return result
