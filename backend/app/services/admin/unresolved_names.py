"""A13's queue: names the importers couldn't match wait here for an editor (research R8–R10).

Suggestions never apply themselves: they are a query an editor reads. Exact normalized matches come
first, then ``pg_trgm`` similarity. Trigrams can't cross scripts, so a Latin name with no same-script
candidate honestly gets no suggestion (R9).
"""

from __future__ import annotations

from collections.abc import Sequence
from datetime import datetime
from typing import Any

from sqlalchemy import BigInteger, Text, column, func, literal, or_, select, true, tuple_, values
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.errors import EntityNotFound, alias_conflict, edit_conflict, validation_failed
from app.auth.roles import AuthedAdmin
from app.db.models import (
    Channel,
    ChannelAlias,
    Competition,
    CompetitionAlias,
    Satellite,
    Team,
    TeamAlias,
    UnresolvedName,
)
from app.schemas import admin_queue as q
from app.services.admin import lists, versions, writer

ENTITY = "unresolved_name"
NOT_FOUND = "unresolved_name_not_found"
DATASETS = ("unresolved_names",)
DEFAULT_LIMIT = 50
MAX_LIMIT = 100
SUGGESTION_LIMIT = 3
SIMILARITY_THRESHOLD = 0.3
SPORT = "football"  # Every importer is football-only; a row has no sport of its own.

TARGET_NOT_FOUND = {
    "team": "team_not_found",
    "competition": "competition_not_found",
    "channel": "channel_not_found",
}


def _decode_cursor(raw: str) -> tuple[datetime, int]:
    seen_at, row_id = lists.decode_cursor(raw, 2)
    try:
        if isinstance(seen_at, str) and isinstance(row_id, int):
            return datetime.fromisoformat(seen_at), row_id
    except ValueError:
        pass
    raise validation_failed([{"loc": ["query", "cursor"], "type": "invalid_cursor"}])


async def list_names(
    session: AsyncSession,
    *,
    source: str | None,
    kind: str | None,
    state: str,
    cursor: str | None,
    limit: int,
) -> tuple[list[q.UnresolvedNameRow], str | None, int]:
    """``(rows, next_cursor, open_count)``, newest sighting first. ``open_count`` ignores the filters."""
    query = select(UnresolvedName).where(UnresolvedName.state == state)
    if source is not None:
        query = query.where(UnresolvedName.source == source)
    if kind is not None:
        query = query.where(UnresolvedName.kind == kind)
    if cursor is not None:
        seen_at, last_id = _decode_cursor(cursor)
        query = query.where(tuple_(UnresolvedName.last_seen_at, UnresolvedName.id) < (seen_at, last_id))
    query = query.order_by(UnresolvedName.last_seen_at.desc(), UnresolvedName.id.desc()).limit(limit + 1)
    found = list((await session.scalars(query)).all())
    rows = found[:limit]
    next_cursor = lists.encode_cursor([rows[-1].last_seen_at.isoformat(), rows[-1].id]) if len(found) > limit else None

    suggestions = await _suggestions(session, rows)
    open_count = await session.scalar(
        select(func.count()).select_from(UnresolvedName).where(UnresolvedName.state == "open")
    )
    return [to_row(row, suggestions.get(row.id, [])) for row in rows], next_cursor, int(open_count or 0)


def to_row(row: UnresolvedName, suggestions: list[q.UnresolvedSuggestion]) -> q.UnresolvedNameRow:
    return q.UnresolvedNameRow(
        id=row.id,
        source=row.source,
        kind=row.kind,
        name=row.name,
        context=q.UnresolvedContext.model_validate(row.context or {}),
        seen_count=row.seen_count,
        last_seen_at=row.last_seen_at,
        state=row.state,
        etag=versions.unresolved_version(row),
        suggestions=suggestions,
    )


# --- Suggestions --------------------------------------------------------------------------------


def _candidates(model: Any, names: Any, *conditions: Any) -> Any:
    """Up to three of ``model`` for one name of the ``VALUES`` list: a ``LATERAL``, so one query per kind."""
    norm = names.c.norm
    similarity = func.similarity(model.name_norm, norm)
    exact = model.name_norm == norm
    return (
        select(model.id.label("target"), model.name.label("name"), similarity.label("sim"), exact.label("exact"))
        .where(or_(exact, similarity >= SIMILARITY_THRESHOLD), *conditions)
        .order_by(exact.desc(), similarity.desc(), model.id)
        .limit(SUGGESTION_LIMIT)
        .correlate(names)
        .lateral("candidate")
    )


async def _suggestions_of(
    session: AsyncSession, kind: str, rows: Sequence[UnresolvedName]
) -> dict[int, list[q.UnresolvedSuggestion]]:
    names = values(column("id", BigInteger), column("norm", Text), name="names").data(
        [(row.id, row.name_norm) for row in rows]
    )
    if kind == "team":
        candidate = _candidates(Team, names, Team.sport == SPORT)
        query = (
            select(names.c.id, candidate, Competition.name)
            .select_from(names)
            .join(candidate, true())
            .outerjoin(Team, Team.id == candidate.c.target)
            .outerjoin(Competition, Competition.id == Team.primary_competition_id)
        )
    elif kind == "competition":
        candidate = _candidates(Competition, names, Competition.sport == SPORT)
        query = select(names.c.id, candidate, literal(None, Text)).select_from(names).join(candidate, true())
    else:
        candidate = _candidates(Channel, names, Channel.deleted_at.is_(None), Channel.placeholder_source.is_(None))
        query = (
            select(names.c.id, candidate, Satellite.name_ar)
            .select_from(names)
            .join(candidate, true())
            .outerjoin(Channel, Channel.id == candidate.c.target)
            .outerjoin(Satellite, Satellite.id == Channel.satellite_id)
        )
    found: dict[int, list[q.UnresolvedSuggestion]] = {}
    ordered = query.order_by(names.c.id, candidate.c.exact.desc(), candidate.c.sim.desc(), candidate.c.target)
    for row_id, target, name, similarity, exact, detail_text in (await session.execute(ordered)).all():
        found.setdefault(row_id, []).append(
            q.UnresolvedSuggestion(
                id=target, name=name, detail=detail_text, confidence=round(similarity * 100), exact=exact
            )
        )
    return found


async def _suggestions(
    session: AsyncSession, rows: Sequence[UnresolvedName]
) -> dict[int, list[q.UnresolvedSuggestion]]:
    """Open rows only: a decided row has nothing left to suggest."""
    found: dict[int, list[q.UnresolvedSuggestion]] = {}
    for kind in TARGET_NOT_FOUND:
        of_kind = [row for row in rows if row.kind == kind and row.state == "open"]
        if of_kind:
            found.update(await _suggestions_of(session, kind, of_kind))
    return found


# --- Decisions ----------------------------------------------------------------------------------


async def _lock_open(session: AsyncSession, row_id: int, if_match: str | None) -> UnresolvedName:
    row = await writer.lock_and_check(session, UnresolvedName, row_id, NOT_FOUND, ENTITY, if_match)
    if row.state != "open":
        changed_by, changed_at = await writer.last_change(session, ENTITY, row.id)
        raise edit_conflict(versions.unresolved_version(row), changed_by, changed_at)
    return row


def _resolve(row: UnresolvedName, admin: AuthedAdmin, state: str, target_id: int | None, now: datetime) -> None:
    row.state = state
    row.target_id = target_id
    row.resolved_by = admin.id
    row.resolved_at = now


async def _write_team_alias(
    session: AsyncSession, row: UnresolvedName, admin: AuthedAdmin, team_id: int, scope: bool
) -> None:
    shared = await session.scalar(
        select(func.count()).select_from(Team).where(Team.name_norm == row.name_norm, Team.sport == SPORT)
    )
    if int(shared or 0) > 1 and not (scope and row.competition_norm):
        raise validation_failed([{"loc": ["body", "scope_to_competition"], "type": "scope_required"}])

    key = (row.source, row.name_norm, row.competition_norm if scope else "")
    existing = await session.get(TeamAlias, key)
    if existing is None:
        session.add(
            TeamAlias(source=key[0], alias_norm=key[1], competition_norm=key[2], team_id=team_id, created_by=admin.id)
        )
    elif existing.team_id != team_id:
        raise alias_conflict()


async def _write_named_alias(
    session: AsyncSession, model: Any, target_column: str, row: UnresolvedName, admin: AuthedAdmin, target_id: int
) -> None:
    existing = await session.get(model, (row.source, row.name_norm))
    if existing is None:
        session.add(
            model(source=row.source, alias_norm=row.name_norm, created_by=admin.id, **{target_column: target_id})
        )
    elif getattr(existing, target_column) != target_id:
        raise alias_conflict()


async def _target_exists(session: AsyncSession, kind: str, target_id: int) -> bool:
    if kind == "team":
        return await session.get(Team, target_id) is not None
    if kind == "competition":
        return await session.get(Competition, target_id) is not None
    channel = await session.get(Channel, target_id)
    return channel is not None and channel.deleted_at is None


async def map_name(
    session: AsyncSession,
    admin: AuthedAdmin,
    row_id: int,
    body: q.UnresolvedMap,
    if_match: str | None,
    now: datetime,
) -> q.UnresolvedNameRow:
    row = await _lock_open(session, row_id, if_match)
    if not await _target_exists(session, row.kind, body.target_id):
        raise EntityNotFound(TARGET_NOT_FOUND[row.kind])

    before = versions.row_state(row)
    if row.kind == "team":
        await _write_team_alias(session, row, admin, body.target_id, body.scope_to_competition)
    elif row.kind == "competition":
        await _write_named_alias(session, CompetitionAlias, "competition_id", row, admin, body.target_id)
    else:
        await _write_named_alias(session, ChannelAlias, "channel_id", row, admin, body.target_id)

    _resolve(row, admin, "created" if body.created else "mapped", body.target_id, now)
    await writer.save_update(session, admin, entity=ENTITY, row=row, before=before, datasets=DATASETS, now=now)
    return to_row(row, [])


async def ignore_name(
    session: AsyncSession, admin: AuthedAdmin, row_id: int, if_match: str | None, now: datetime
) -> q.UnresolvedNameRow:
    row = await _lock_open(session, row_id, if_match)
    before = versions.row_state(row)
    _resolve(row, admin, "ignored", None, now)
    await writer.save_update(session, admin, entity=ENTITY, row=row, before=before, datasets=DATASETS, now=now)
    return to_row(row, [])
