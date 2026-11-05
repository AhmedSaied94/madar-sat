"""The shapes the poller's pure parts share (005 contracts/live-pipeline.md, The pure interfaces)."""

from __future__ import annotations

from collections.abc import Mapping
from dataclasses import dataclass, field
from datetime import datetime
from typing import Any, Literal

# The order is a preference: for a status at the same stage, and for events and lineups (FR-017).
SOURCES = ("filgoal", "goal", "yallakora")
GOAL_TYPES = frozenset({"goal", "own_goal", "penalty"})
FINAL_STATUSES = frozenset({"finished", "cancelled", "abandoned"})


class LayoutChanged(Exception):
    """A page didn't have what the parser expects. That source stops being used (SD §6.7, Validation)."""


@dataclass(frozen=True, slots=True)
class Score:
    home: int
    away: int
    home_pen: int | None = None
    away_pen: int | None = None

    @property
    def is_nil(self) -> bool:
        return self == Score(0, 0)

    @property
    def goals(self) -> Score:
        return Score(self.home, self.away)

    @property
    def has_penalties(self) -> bool:
        return self.home_pen is not None and self.away_pen is not None


@dataclass(frozen=True, slots=True)
class Event:
    external_id: str
    type: str
    side: str
    minute: str
    player: str | None = None


@dataclass(frozen=True, slots=True)
class LineupSide:
    formation: str | None
    players: tuple[dict[str, Any], ...]


@dataclass(frozen=True, slots=True)
class Lineups:
    home: LineupSide | None
    away: LineupSide | None


@dataclass(frozen=True, slots=True)
class SourceReading:
    """One source's view of one match. Structured facts only, never written commentary."""

    source: str
    external_id: str
    home: str
    away: str
    competition: str | None
    kickoff_at: datetime | None
    status: str | None
    period: str | None
    minute: str | None
    score: Score | None
    events: tuple[Event, ...] | None = None  # None: this page doesn't carry them
    lineups: Lineups | None = None
    status_label: str | None = None
    page_path: str | None = None  # the match page, when the list row links to it
    ignored_event_types: tuple[str, ...] = ()  # names the parser doesn't map, for the run log
    unknown_status: str | None = None  # a status nobody has seen: status, period and minute stay empty (FR-001)
    stats: tuple[dict[str, Any], ...] | None = None  # ``{type, home, away}`` rows, from Goal.com only


@dataclass(frozen=True, slots=True)
class SideInput:
    """``valid(reading)``, ``not_covering`` (up, but no such match) or ``unavailable`` (down or invalid)."""

    kind: Literal["valid", "not_covering", "unavailable"]
    reading: SourceReading | None = None

    @classmethod
    def valid(cls, reading: SourceReading) -> SideInput:
        return cls("valid", reading)

    @classmethod
    def not_covering(cls) -> SideInput:
        return cls("not_covering")

    @classmethod
    def unavailable(cls) -> SideInput:
        return cls("unavailable")


@dataclass(frozen=True, slots=True)
class Peak:
    """The highest match minute one source has shown for a match, and the period it was in (research R4)."""

    minute: int
    period: str | None


@dataclass(frozen=True, slots=True)
class LiveState:
    """What ``decide`` remembers about a match between cycles."""

    match_id: int
    status: str
    period: str | None
    minute: str | None = None
    status_label: str | None = None
    confirmed: Score | None = None
    drop_since: datetime | None = None
    status_drop_since: datetime | None = None
    score_first_source: str | None = None
    score_changed_at: datetime | None = None
    fulltime_source: str | None = None
    fulltime_since: datetime | None = None
    finish_wait_since: datetime | None = None
    disagreement_since: datetime | None = None
    peaks: Mapping[str, Peak] = field(default_factory=dict)


@dataclass(frozen=True, slots=True)
class Decision:
    """What one poll means. Every memory field is the value to store next, changed or not."""

    fallback: bool = False  # every enabled source unusable: back to the clock estimate
    write_status: bool = False
    status: str | None = None
    period: str | None = None
    minute: str | None = None
    status_label: str | None = None
    confirm: Score | None = None
    drop_since: datetime | None = None
    status_drop_since: datetime | None = None
    score_first_source: str | None = None
    score_changed_at: datetime | None = None
    fulltime_source: str | None = None
    fulltime_since: datetime | None = None
    finish_wait_since: datetime | None = None
    disagreement_since: datetime | None = None
    open_problems: tuple[str, ...] = ()
    close_problems: tuple[str, ...] = ()
