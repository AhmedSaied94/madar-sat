"""A6/A7 ordering: one request sets the whole new order, each row carrying its version (R12, R22).

The server sets ``priority`` 1…n in the given order in one transaction: one stale item rejects all,
with ``meta.stale_ids`` naming them. Rows the editor didn't list keep their relative order, after
the listed ones. Each changed row gets an audit entry (no ``locked_fields``: no importer writes
``priority``), then the entity's datasets are bumped.
"""

from __future__ import annotations

from datetime import datetime
from typing import Any

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.errors import edit_conflict, precondition_required, validation_failed
from app.auth.roles import AuthedAdmin
from app.db.models import Competition, RightsHolder, Satellite
from app.schemas import admin as a
from app.services.admin import versions, writer

# Each target's model, the column holding its position and the datasets a new order changes.
TARGETS: dict[str, tuple[Any, str, tuple[str, ...]]] = {
    "competitions": (Competition, "priority", ("competitions", "matches")),
    "satellites": (Satellite, "priority", ("satellites",)),
    "rights_holders": (RightsHolder, "sort_order", ("rights_holders", "competitions")),
}


async def reorder(
    session: AsyncSession,
    admin: AuthedAdmin,
    entity: str,
    body: a.OrderRequest,
    now: datetime,
) -> a.BulkResult:
    """``entity`` is a key of ``TARGETS``."""
    model, column, datasets = TARGETS[entity]
    position_of = getattr(model, column)

    # Every row is locked before any version is compared: nothing changes when one item is stale.
    rows: dict[int, Any] = {}
    for item in body.items:
        row = await session.get(model, item.id, with_for_update=True, populate_existing=True)
        if row is None:
            raise validation_failed([{"loc": ["body", "items", item.id], "type": "unknown_id"}])
        rows[item.id] = row

    missing_header = [item.id for item in body.items if item.if_match is None]
    if missing_header:
        raise precondition_required()

    stale: list[int] = []
    current = {item.id: await versions.version_of(session, rows[item.id]) for item in body.items}
    for item in body.items:
        if not versions.matches_etag(item.if_match, current[item.id]):
            stale.append(item.id)
    if stale:
        raise edit_conflict(current[stale[0]], None, None, stale_ids=stale)

    changed: list[tuple[Any, int, int]] = []
    for position, item in enumerate(body.items, start=1):
        row = rows[item.id]
        if getattr(row, column) != position:
            changed.append((row, getattr(row, column), position))
            setattr(row, column, position)

    # Rows the editor didn't list keep their relative order, after the listed ones.
    listed = {item.id for item in body.items}
    others = list(
        (
            await session.scalars(
                select(model)
                .where(model.id.not_in(listed), position_of.is_not(None))
                .order_by(position_of.asc(), model.id)
                .with_for_update()
            )
        ).all()
    )
    for offset, row in enumerate(others, start=len(body.items) + 1):
        if getattr(row, column) != offset:
            changed.append((row, getattr(row, column), offset))
            setattr(row, column, offset)

    for row, before, after in changed:
        writer.add_audit(session, admin, entity.rstrip("s"), row.id, "update", {column: [before, after]})
        if hasattr(row, "updated_at"):
            row.updated_at = now
    await writer.bump_datasets(session, datasets)
    return a.BulkResult(
        updated=[
            a.BulkUpdated(id=item.id, etag=await versions.version_of(session, rows[item.id])) for item in body.items
        ]
    )
