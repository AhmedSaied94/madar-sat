"""Checks that the ids an admin request names exist, before any row is written.

A foreign key that points nowhere would surface as a database error (a 500). These checks turn it
into a ``422 validation_error`` that names the field, in the same ``{"loc", "type"}`` shape as the
request validator.
"""

from __future__ import annotations

from collections.abc import Iterable, Sequence
from typing import Any

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.errors import validation_failed
from app.db.models import Base, MediaAsset

IMAGE_KINDS = ("logo", "photo")
AUDIO_KINDS = ("audio",)

Ref = tuple[type[Base], Iterable[int | None], Sequence[str | int]]
Error = dict[str, Any]


def _error(loc: Sequence[str | int], reason: str) -> Error:
    return {"loc": ["body", *loc], "type": reason}


async def missing_refs(session: AsyncSession, refs: Iterable[Ref]) -> list[Error]:
    """One ``not_found`` error per id that no row of its table has."""
    errors: list[Error] = []
    for model, ids, loc in refs:
        wanted = {i for i in ids if i is not None}
        if not wanted:
            continue
        found = set((await session.scalars(select(model.id).where(model.id.in_(wanted)))).all())  # type: ignore[attr-defined]
        errors.extend(_error(loc, "not_found") for _ in sorted(wanted - found))
    return errors


async def missing_assets(
    session: AsyncSession, assets: Iterable[tuple[int | None, Sequence[str], Sequence[str | int]]]
) -> list[Error]:
    """Each ``(asset_id, allowed_kinds, loc)`` must be an existing asset of one of those kinds."""
    errors: list[Error] = []
    for asset_id, kinds, loc in assets:
        if asset_id is None:
            continue
        kind = await session.scalar(select(MediaAsset.kind).where(MediaAsset.id == asset_id))
        if kind is None:
            errors.append(_error(loc, "not_found"))
        elif kind not in kinds:
            errors.append(_error(loc, "wrong_kind"))
    return errors


def raise_if_any(errors: Sequence[Error]) -> None:
    if errors:
        raise validation_failed(list(errors))


def field_error(loc: Sequence[str | int], reason: str) -> Error:
    """An error the service finds itself, for ``validation_failed``."""
    return _error(loc, reason)
