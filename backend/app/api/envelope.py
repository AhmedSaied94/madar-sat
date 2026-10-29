"""The response envelope ``{success, data, error, meta}`` (constitution VI).

Every non-304 response uses it. ``error`` carries a stable ``code`` and a
``message`` that is for logs only — clients map ``code`` to Arabic copy.
"""

from __future__ import annotations

from datetime import UTC, datetime
from typing import Any, Generic, TypeVar

from pydantic import BaseModel

T = TypeVar("T")


def utcnow_iso() -> str:
    return datetime.now(UTC).isoformat().replace("+00:00", "Z")


class ErrorBody(BaseModel):
    code: str
    message: str


class Envelope(BaseModel, Generic[T]):
    success: bool
    data: T | None
    error: ErrorBody | None
    meta: dict[str, Any]


def ok(data: T, meta: dict[str, Any] | None = None) -> Envelope[T]:
    merged = {"generated_at": utcnow_iso()}
    if meta:
        merged.update(meta)
    return Envelope[T](success=True, data=data, error=None, meta=merged)


def fail(code: str, message: str, meta: dict[str, Any] | None = None) -> Envelope[None]:
    return Envelope[None](success=False, data=None, error=ErrorBody(code=code, message=message), meta=meta or {})
