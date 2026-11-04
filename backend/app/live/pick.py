"""Which matches get a match page this cycle (SD §6.7, Requests). Pure."""

from __future__ import annotations

from collections.abc import Iterable
from dataclasses import dataclass
from datetime import datetime

from app.live.robots import is_allowed

_NO_PRIORITY = 1 << 30


@dataclass(frozen=True, slots=True)
class SlotCandidate:
    match_id: int
    path: str | None
    priority: int | None
    kickoff_at: datetime
    has_slot: bool = False


def pick_slots(candidates: Iterable[SlotCandidate], *, host: str, cap: int) -> list[SlotCandidate]:
    """Existing slots first, then ``competitions.priority`` (lowest first, as served), then the kickoff."""
    allowed = [item for item in candidates if item.path and is_allowed(host, item.path)]
    allowed.sort(
        key=lambda item: (
            not item.has_slot,
            item.priority if item.priority is not None else _NO_PRIORITY,
            item.kickoff_at,
            item.match_id,
        )
    )
    return allowed[:cap]
