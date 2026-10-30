"""Shared parts of the admin routers: path ids, the ``If-Match`` header, injected parts and OpenAPI response docs."""

from __future__ import annotations

from datetime import datetime
from typing import Annotated, Any

from fastapi import Depends, Header, Path, Response
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.deps import get_now
from app.api.errors import validator_headers
from app.auth.roles import AuthedAdmin, require_editor
from app.db.session import get_session

# None of these appear in the OpenAPI document: they are injected, not sent.
Db = Annotated[AsyncSession, Depends(get_session)]
Editor = Annotated[AuthedAdmin, Depends(require_editor)]
Now = Annotated[datetime, Depends(get_now)]


def set_etag(response: Response, etag: str) -> None:
    """The headers every entity ``200``/``201`` carries: the strong version to send back as ``If-Match``."""
    response.headers.update(validator_headers(etag))


# Every id column is a PostgreSQL ``bigint``: a larger id is a 422, never a database error.
ID_MAX = 2**63 - 1

IdPath = Annotated[int, Path(ge=1, le=ID_MAX)]

# Optional in the schema on purpose: a missing header must reach the handler and get
# ``428 precondition_required``, not FastAPI's generic 422.
IfMatch = Annotated[
    str | None,
    Header(
        alias="If-Match",
        description='The entity\'s current ETag, e.g. `"3f9a…"`. Required: without it the answer is `428`.',
    ),
]

ETAG_HEADER: dict[str, Any] = {
    "headers": {
        "ETag": {
            "description": "The entity's strong version (first 32 hex of its SHA-256), quoted. Send it as `If-Match`.",
            "schema": {"type": "string"},
        }
    }
}
