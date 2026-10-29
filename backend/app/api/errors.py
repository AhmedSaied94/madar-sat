"""Exception hierarchy and handlers that turn every error into the envelope.

Codes are stable (contracts/public-api-v1.md#errors). No response body ever contains
a traceback: unhandled errors are logged with a request id and answered with a bare
``internal_error``.
"""

from __future__ import annotations

import logging
import uuid
from typing import Any

from fastapi import FastAPI, Request
from fastapi.exceptions import RequestValidationError
from fastapi.responses import JSONResponse
from starlette.exceptions import HTTPException as StarletteHTTPException
from starlette.middleware.base import BaseHTTPMiddleware, RequestResponseEndpoint
from starlette.responses import Response

from app.api.envelope import fail

logger = logging.getLogger("madar.api")


class ApiError(Exception):
    """An error with a stable code, mapped to the envelope by the handler."""

    def __init__(self, status_code: int, code: str, message: str = "", meta: dict[str, Any] | None = None) -> None:
        super().__init__(message or code)
        self.status_code = status_code
        self.code = code
        self.message = message or code
        self.meta = meta or {}


class EntityNotFound(ApiError):
    def __init__(self, code: str, message: str = "") -> None:
        super().__init__(404, code, message)


class NotModified(Exception):
    """Raised by the ETag dependency to short-circuit to a 304 with no body."""

    def __init__(self, etag: str) -> None:
        super().__init__(etag)
        self.etag = etag


def validator_headers(etag: str) -> dict[str, str]:
    """The headers every ETag-bearing ``200`` and ``304`` carry (research R4)."""
    return {"ETag": etag, "Cache-Control": "no-cache", "Vary": "Accept-Encoding"}


def _request_id(request: Request) -> str:
    return getattr(request.state, "request_id", "?")


def register_exception_handlers(app: FastAPI) -> None:
    @app.exception_handler(ApiError)
    async def _api_error(request: Request, exc: ApiError) -> JSONResponse:
        logger.info("api_error request_id=%s code=%s", _request_id(request), exc.code)
        return JSONResponse(status_code=exc.status_code, content=fail(exc.code, exc.message, exc.meta).model_dump())

    @app.exception_handler(StarletteHTTPException)
    async def _http_error(request: Request, exc: StarletteHTTPException) -> JSONResponse:
        if exc.status_code == 404:
            return JSONResponse(status_code=404, content=fail("not_found", "route not found").model_dump())
        if exc.status_code == 405:
            return JSONResponse(status_code=405, content=fail("method_not_allowed", "method not allowed").model_dump())
        return JSONResponse(status_code=exc.status_code, content=fail("http_error", str(exc.detail)).model_dump())

    @app.exception_handler(RequestValidationError)
    async def _validation_error(request: Request, exc: RequestValidationError) -> JSONResponse:
        errors = [{"loc": list(err.get("loc", [])), "type": err.get("type", "value_error")} for err in exc.errors()]
        logger.info("validation_error request_id=%s errors=%s", _request_id(request), errors)
        return JSONResponse(
            status_code=422,
            content=fail("validation_error", "invalid request", {"errors": errors}).model_dump(),
        )

    @app.exception_handler(NotModified)
    async def _not_modified(request: Request, exc: NotModified) -> Response:
        # A 304 has no body and no envelope, but repeats the validator headers.
        return Response(status_code=304, headers=validator_headers(exc.etag))

    @app.exception_handler(Exception)
    async def _unhandled(request: Request, exc: Exception) -> JSONResponse:
        logger.exception("internal_error request_id=%s", _request_id(request))
        return JSONResponse(status_code=500, content=fail("internal_error", "internal error").model_dump())


class RequestIdMiddleware(BaseHTTPMiddleware):
    async def dispatch(self, request: Request, call_next: RequestResponseEndpoint) -> Response:
        request.state.request_id = uuid.uuid4().hex
        return await call_next(request)
