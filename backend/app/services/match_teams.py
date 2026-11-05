"""Empty team ids on matches whose text name an editor has just decided (A13's queue, ``repair-matches``).

A linker compares ids, so a match holding only a text name can't link however many aliases exist, and a card
for it looks like a fixture nobody holds. The name and the competition together are the editor's decision: the
same words in another competition may be another club, so they're left alone.
"""

from __future__ import annotations

from collections.abc import Iterator
from datetime import datetime

from sqlalchemy import Update, exists, func, or_, update
from sqlalchemy.orm import aliased

from app.db.models import Match
from app.live.links import KICKOFF_TOLERANCE
from app.live.types import FINAL_STATUSES
from app.services.live import FEED_WINDOW_BEFORE

SIDES = (("home_team_id", "home_team_name"), ("away_team_id", "away_team_name"))


def empty_team_updates(
    name_norm: str, competition_norm: str, team_id: int, now: datetime
) -> Iterator[tuple[str, Update]]:
    """``(column, UPDATE … RETURNING id)`` per side. A name with no competition proves nothing, so none are made."""
    if not competition_norm:
        return
    earliest = now - FEED_WINDOW_BEFORE
    other = aliased(Match)
    for (id_column, name_column), (other_id_column, _) in zip(SIDES, reversed(SIDES), strict=True):
        # Two rows with the same teams can't link at all, so the one with the channels would lose its feed.
        clashes = exists().where(
            other.id != Match.id,
            getattr(other, id_column) == team_id,
            getattr(other, other_id_column) == getattr(Match, other_id_column),
            other.kickoff_at.between(Match.kickoff_at - KICKOFF_TOLERANCE, Match.kickoff_at + KICKOFF_TOLERANCE),
        )
        yield (
            id_column,
            update(Match)
            .where(
                getattr(Match, id_column).is_(None),
                func.ar_normalize(getattr(Match, name_column)) == name_norm,
                func.ar_normalize(Match.competition_name) == competition_norm,
                Match.status.not_in(sorted(FINAL_STATUSES)),
                or_(Match.kickoff_at.is_(None), Match.kickoff_at >= earliest),
                ~Match.locked_fields.contains([id_column]),
                ~clashes,
            )
            .values({id_column: team_id, "updated_at": now})
            .returning(Match.id)
            .execution_options(synchronize_session=False),
        )
