"""Entity resolution v0, without guessing (T072, R17, FR-023).

In order:

* competition — a known external id, then an exact ``(sport, name_norm)`` match;
* team — a known external id, exactly one team with the same normalized name and sport, or,
  among several, the highest competition similarity (≥ 0.5, no tie), using a Python port of
  ``competitionSimilarity`` from ``../old_app/src/utils/arabicMatch.js``.

Anything else keeps its text name, gets no id, and is listed in ``run.json``. Teams are never
created here.
"""

from __future__ import annotations

import re
from dataclasses import dataclass
from typing import Literal

from sqlalchemy import select
from sqlalchemy.orm import Session

from app.db.models import (
    Competition,
    CompetitionExternalId,
    Team,
    TeamCompetition,
    TeamExternalId,
)
from app.domain.arabic import ar_normalize

MIN_SIMILARITY = 0.5

Reason = Literal["external_id", "name", "competition_similarity", "tie", "unresolved"]

# The JS list, verbatim (`STOP_WORDS` in arabicMatch.js), with the English entries kept.
STOP_WORDS = frozenset(
    {
        "ال",
        "دور",
        "دوري",
        "الدوري",
        "كاس",
        "الكاس",
        "بطول",
        "بطوله",
        "البطوله",
        "ممتاز",
        "الممتاز",
        "درج",
        "درجه",
        "الدرجه",
        "اول",
        "الاول",
        "اولي",
        "الاولي",
        "كره",
        "الكره",
        "قدم",
        "القدم",
        "لكره",
        "مجموعات",
        "موسم",
        "عام",
        "محلي",
        "league",
        "cup",
        "division",
        "premier",
        "first",
        "the",
        "of",
        "liga",
        "serie",
    }
)

_LEADING_AL = re.compile(r"^ال")
_TRAILING = re.compile(r"(يه|يا|ات|ين|ون|ه|ي)$")


def strip_arabic_affixes(value: str) -> str:
    """The JS ``stripArabicAffixes``: drop a leading «ال» and one trailing ending."""
    return _TRAILING.sub("", _LEADING_AL.sub("", value))


def tokenize(value: str | None) -> list[str]:
    """The JS ``tokenize``: normalize, split, drop stop words, strip affixes, keep ≥ 2 chars."""
    tokens = [t for t in ar_normalize(value).split(" ") if t and t not in STOP_WORDS]
    stripped = [strip_arabic_affixes(t) for t in tokens]
    return [t for t in stripped if len(t) >= 2 and t not in STOP_WORDS]


def competition_similarity(league: str | None, candidate: str | None) -> float:
    """The JS ``competitionSimilarity``, including its prefix rule (``مصر`` matches ``مصري``)."""
    left = ar_normalize(league)
    right = ar_normalize(candidate)
    if not left or not right:
        return 0.0
    if left == right:
        return 1.0
    a = tokenize(league)
    b = tokenize(candidate)
    if not a or not b:
        return 0.0

    def similar(x: str, y: str) -> bool:
        return x == y or (len(x) >= 3 and y.startswith(x)) or (len(y) >= 3 and x.startswith(y))

    hits = sum(1 for token in a if any(similar(token, other) for other in b))
    return hits / min(len(a), len(b))


@dataclass(frozen=True, slots=True)
class ResolveResult:
    entity_id: int | None
    name: str | None
    reason: Reason


def resolve_competition(
    session: Session,
    *,
    external_id: str | None,
    name: str | None,
    sport: str = "football",
    source: str = "ysscores",
) -> ResolveResult:
    if external_id:
        hit = session.execute(
            select(CompetitionExternalId.competition_id).where(
                CompetitionExternalId.source == source,
                CompetitionExternalId.external_id == external_id,
            )
        ).scalar_one_or_none()
        if hit is not None:
            return ResolveResult(hit, name, "external_id")
    normalized = ar_normalize(name)
    if normalized:
        rows = (
            session.execute(
                select(Competition.id).where(Competition.sport == sport, Competition.name_norm == normalized)
            )
            .scalars()
            .all()
        )
        if len(rows) == 1:
            return ResolveResult(rows[0], name, "name")
    return ResolveResult(None, name, "unresolved")


def resolve_team(
    session: Session,
    *,
    external_id: str | None,
    name: str | None,
    sport: str = "football",
    competition_name: str | None = None,
    source: str = "ysscores",
) -> ResolveResult:
    if external_id:
        hit = session.execute(
            select(TeamExternalId.team_id).where(
                TeamExternalId.source == source,
                TeamExternalId.external_id == external_id,
            )
        ).scalar_one_or_none()
        if hit is not None:
            return ResolveResult(hit, name, "external_id")

    normalized = ar_normalize(name)
    if not normalized:
        return ResolveResult(None, name, "unresolved")
    candidates = (
        session.execute(select(Team.id).where(Team.sport == sport, Team.name_norm == normalized)).scalars().all()
    )
    if not candidates:
        return ResolveResult(None, name, "unresolved")
    if len(candidates) == 1:
        return ResolveResult(candidates[0], name, "name")

    scores = {team_id: _competition_score(session, team_id, competition_name) for team_id in candidates}
    best = max(scores.values())
    winners = [team_id for team_id, score in scores.items() if score == best]
    if best < MIN_SIMILARITY:
        return ResolveResult(None, name, "unresolved")
    if len(winners) > 1:
        return ResolveResult(None, name, "tie")
    return ResolveResult(winners[0], name, "competition_similarity")


def _competition_score(session: Session, team_id: int, competition_name: str | None) -> float:
    if not competition_name:
        return 0.0
    primary = session.execute(select(Team.primary_competition_id).where(Team.id == team_id)).scalar_one()
    linked = (
        session.execute(select(TeamCompetition.competition_id).where(TeamCompetition.team_id == team_id))
        .scalars()
        .all()
    )
    ids = {cid for cid in (primary, *linked) if cid is not None}
    if not ids:
        return 0.0
    names = session.execute(select(Competition.name).where(Competition.id.in_(ids))).scalars().all()
    return max((competition_similarity(competition_name, candidate) for candidate in names), default=0.0)
