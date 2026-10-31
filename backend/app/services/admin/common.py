"""Small helpers the admin services share."""

from __future__ import annotations

from collections.abc import Mapping, Sequence
from typing import Any

from pydantic import BaseModel
from sqlalchemy import CompoundSelect, Select, func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.errors import in_use
from app.services.common import media_url

# The base schema's domains: frequency_mhz and symbol_rate.
MHZ_RANGE = (2000, 13000)
SYMBOL_RATE_RANGE = (500, 60000)


def tuning_errors(frequency: Any, loc: Sequence[str | int]) -> list[dict[str, Any]]:
    """Errors for a ``Frequency`` outside the base domains (a database CHECK would answer with a 500 otherwise)."""
    if frequency is None:
        return []
    errors: list[dict[str, Any]] = []
    if not MHZ_RANGE[0] <= frequency.mhz <= MHZ_RANGE[1]:
        errors.append({"loc": ["body", *loc, "mhz"], "type": "out_of_range"})
    if not SYMBOL_RATE_RANGE[0] <= frequency.sr <= SYMBOL_RATE_RANGE[1]:
        errors.append({"loc": ["body", *loc, "sr"], "type": "out_of_range"})
    return errors


def sent(body: BaseModel) -> dict[str, Any]:
    """The fields of a PATCH body the client actually sent (a ``null`` is a value, not an absence)."""
    return {name: getattr(body, name) for name in body.model_fields_set}


async def asset_urls(session: AsyncSession, asset_ids: list[int | None]) -> dict[int, str | None]:
    """``{asset_id: absolute url}`` for the assets that exist."""
    from app.services.matches import fetch_media_paths

    paths = await fetch_media_paths(session, asset_ids)
    return {asset_id: media_url(path) for asset_id, path in paths.items()}


def url_of(urls: Mapping[int, str | None], asset_id: int | None) -> str | None:
    return urls.get(asset_id) if asset_id is not None else None


Rows = Select[Any] | CompoundSelect[Any]


async def count(session: AsyncSession, query: Rows) -> int:
    """The number of rows ``query`` selects."""
    return int(await session.scalar(select(func.count()).select_from(query.subquery())) or 0)


async def refuse_if_in_use(session: AsyncSession, usage: Mapping[str, Rows]) -> None:
    """``409 in_use`` with the non-zero counts when anything still references the entity."""
    counts = {name: await count(session, query) for name, query in usage.items()}
    used = {name: n for name, n in counts.items() if n}
    if used:
        raise in_use(used)
