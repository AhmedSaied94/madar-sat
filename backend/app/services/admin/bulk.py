"""Bulk actions on matches: all or nothing (research R8, FR-008, FR-009).

Every item carries the ETag the editor saw. The rows are locked in id order (no deadlocks between two
bulk requests), every version is checked, and only then is anything changed. One stale item refuses the
whole request with ``409 edit_conflict`` and ``meta.stale_ids``. Each changed match gets its own
``audit_log`` row with ``action = 'bulk'``.
"""

from __future__ import annotations

from collections.abc import Sequence
from datetime import datetime
from typing import Any

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.errors import EntityNotFound, edit_conflict, forbidden, precondition_required, validation_failed
from app.auth.roles import AuthedAdmin
from app.db.models import Competition, Match
from app.domain.lockable import MATCH_LOCKABLE
from app.schemas import admin as a
from app.services.admin import match_links, refs, versions, writer
from app.services.admin.match_view import ENTITY, NOT_FOUND
from app.services.common import hidden_names


async def _lock_in_order(session: AsyncSession, ids: Sequence[int]) -> list[Match]:
    rows = (
        await session.scalars(
            select(Match)
            .where(Match.id.in_(ids))
            .order_by(Match.id)
            .with_for_update()
            .execution_options(populate_existing=True)
        )
    ).all()
    if len(rows) != len(set(ids)):
        raise EntityNotFound(NOT_FOUND)
    return list(rows)


async def _check_versions(session: AsyncSession, matches: Sequence[Match], sent: dict[int, str]) -> None:
    """``409`` naming every stale id, with the first stale match's current version and last change."""
    stale: list[tuple[Match, str]] = []
    for match in matches:
        current = await versions.match_version(session, match)
        if not versions.matches_etag(sent[match.id], current):
            stale.append((match, current))
    if stale:
        first, current = stale[0]
        changed_by, changed_at = await writer.last_change(session, ENTITY, first.id)
        raise edit_conflict(current, changed_by, changed_at, stale_ids=[match.id for match, _ in stale])


async def run(
    session: AsyncSession, admin: AuthedAdmin, body: a.BulkChangeCompetition | a.BulkRemoveChannels, now: datetime
) -> a.BulkResult:
    if isinstance(body, a.BulkRemoveChannels) and not admin.covers("admin"):
        raise forbidden("admin")

    ids = [item.id for item in body.items]
    if len(set(ids)) != len(ids):
        raise validation_failed([refs.field_error(["items"], "duplicate")])
    if any(item.etag is None for item in body.items):
        raise precondition_required()
    sent = {item.id: item.etag for item in body.items if item.etag is not None}

    competition: Competition | None = None
    if isinstance(body, a.BulkChangeCompetition):
        competition = await session.get(Competition, body.competition_id)
        if competition is None:
            raise validation_failed([refs.field_error(["competition_id"], "not_found")])

    matches = await _lock_in_order(session, ids)
    await _check_versions(session, matches, sent)

    changed_any = False
    for match in matches:
        before = versions.row_state(match)
        extra: dict[str, Any] = {}
        if isinstance(body, a.BulkChangeCompetition) and competition is not None:
            match.competition_id, match.competition_name = competition.id, competition.name
            if "competition_stage" in body.model_fields_set:
                match.competition_stage = body.competition_stage
        elif isinstance(body, a.BulkRemoveChannels):
            links = await match_links.remove_all_visible(session, match.id, body.channel_ids, hidden_names())
            if links:
                extra["channels"] = links
        changed_any |= await writer.save_update(
            session,
            admin,
            entity=ENTITY,
            row=match,
            before=before,
            datasets=(),  # bumped once below, not once per match
            now=now,
            lockable=MATCH_LOCKABLE,
            extra_diff=extra,
            action="bulk",
        )

    if changed_any:
        await writer.bump_datasets(session, ("matches",))
    return a.BulkResult(
        updated=[a.BulkUpdated(id=match.id, etag=await versions.match_version(session, match)) for match in matches]
    )
