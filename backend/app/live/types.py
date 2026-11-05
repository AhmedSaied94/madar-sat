"""The shapes the poller's pure parts share (005 contracts/live-pipeline.md, The pure interfaces)."""

from __future__ import annotations

from dataclasses import dataclass
from datetime import datetime
from typing import Any, Literal

SOURCES = ("filgoal", "yallakora")
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
class Candidate:
    """A new score seen but not yet confirmed (data-model ``match_live_state``)."""

    score: Score
    source: str
    first_seen_at: datetime
    polls: int

    def as_json(self) -> dict[str, Any]:
        return {
            "home": self.score.home,
            "away": self.score.away,
            "home_pen": self.score.home_pen,
            "away_pen": self.score.away_pen,
            "source": self.source,
            "first_seen_at": self.first_seen_at.isoformat(),
            "polls": self.polls,
        }

    @classmethod
    def from_json(cls, value: dict[str, Any]) -> Candidate:
        return cls(
            score=Score(value["home"], value["away"], value.get("home_pen"), value.get("away_pen")),
            source=value["source"],
            first_seen_at=datetime.fromisoformat(value["first_seen_at"]),
            polls=value["polls"],
        )


@dataclass(frozen=True, slots=True)
class LiveState:
    """What ``decide`` remembers about a match between cycles."""

    match_id: int
    status: str
    period: str | None
    confirmed: Score | None = None
    candidate: Candidate | None = None
    disagreement_since: datetime | None = None
    previous_status: tuple[str | None, str | None] | None = None  # (status, period) of the last poll's primary
    previous_primary: str | None = None  # the source status and minute came from in the last poll


@dataclass(frozen=True, slots=True)
class Decision:
    fallback: bool = False  # both sources unusable: back to the clock estimate
    write_status: bool = False
    status: str | None = None
    period: str | None = None
    minute: str | None = None
    status_label: str | None = None
    status_reading: SourceReading | None = None
    confirm: Score | None = None
    candidate: Candidate | None = None
    disagreement_since: datetime | None = None
    hold_goal_events: bool = False
    open_problems: tuple[str, ...] = ()
    close_problems: tuple[str, ...] = ()
