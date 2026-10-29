"""Shared query-parameter parsing for the public routers."""

from __future__ import annotations

from typing import Annotated

from fastapi import Path, Query

from app.api.errors import ApiError

MAX_IDS = 32
# Every id column is a PostgreSQL ``bigint``: a larger id is a 422, never a DB error.
ID_MAX = 2**63 - 1

IdPath = Annotated[int, Path(ge=1, le=ID_MAX)]
IdQuery = Annotated[int | None, Query(ge=1, le=ID_MAX)]


def query_error(name: str, error_type: str, message: str) -> ApiError:
    """A ``validation_error`` with the same ``meta.errors`` shape FastAPI's handler emits."""
    return ApiError(422, "validation_error", message, {"errors": [{"loc": ["query", name], "type": error_type}]})


def parse_id_list(value: str | None, name: str) -> tuple[int, ...]:
    """Parse a comma-separated integer list (≤ 32 entries, each a valid id)."""
    if not value:
        return ()
    parts = [p.strip() for p in value.split(",") if p.strip()]
    if len(parts) > MAX_IDS:
        raise query_error(name, "too_long", "id list exceeds 32 entries")
    try:
        ids = tuple(int(p) for p in parts)
    except ValueError:
        raise query_error(name, "int_parsing", "id list must be integers") from None
    if any(not 1 <= i <= ID_MAX for i in ids):
        raise query_error(name, "out_of_range", "id out of range")
    return ids
