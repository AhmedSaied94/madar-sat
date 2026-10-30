"""``/admin/api/media``: image and audio uploads (contracts/admin-api.md#media, research R10)."""

from __future__ import annotations

from collections.abc import Callable, Coroutine
from typing import Annotated, Any, Literal

from fastapi import APIRouter, Depends, File, Form, Request, Response, UploadFile
from fastapi.routing import APIRoute

from app.api.admin import _docs
from app.api.admin._common import Db
from app.api.envelope import Envelope, ok
from app.api.errors import file_too_large
from app.auth.roles import require_editor
from app.schemas import admin as a
from app.services.admin import uploads


class CappedUploadRoute(APIRoute):
    """Refuses an oversized request before FastAPI parses the multipart body (research R10).

    A ``Content-Length`` above the biggest cap plus the multipart framing is refused unread. Without one
    (chunked), the body is read with the same hard cap, so memory stays bounded either way.
    """

    def get_route_handler(self) -> Callable[[Request], Coroutine[Any, Any, Response]]:
        original = super().get_route_handler()

        async def handler(request: Request) -> Response:
            declared = request.headers.get("content-length", "")
            if declared.isdigit() and int(declared) > uploads.MAX_REQUEST_BYTES:
                raise file_too_large(uploads.IMAGE_MAX_BYTES)
            body = bytearray()
            async for chunk in request.stream():
                body += chunk
                if len(body) > uploads.MAX_REQUEST_BYTES:
                    raise file_too_large(uploads.IMAGE_MAX_BYTES)
            request._body = bytes(body)  # noqa: SLF001 - hands the capped body to FastAPI's parser
            return await original(request)

        return handler


router = APIRouter(
    prefix="/admin/api/media",
    tags=["media"],
    dependencies=[Depends(require_editor)],
    route_class=CappedUploadRoute,
)


@router.post(
    "",
    status_code=201,
    response_model=Envelope[a.MediaAsset],
    responses={
        201: {"description": "A new asset", **_docs.example(media_ok=_docs.MEDIA_OK)},
        200: {
            "model": Envelope[a.MediaAsset],
            "description": "The same bytes were stored already: the existing asset",
            **_docs.example(media_ok=_docs.MEDIA_OK),
        },
        **_docs.AUTHED,
        413: _docs.FILE_TOO_LARGE,
        415: _docs.UNSUPPORTED_MEDIA_TYPE,
        422: _docs.merged("Validation error, or the file won't decode", _docs.VALIDATION, _docs.MEDIA_INVALID),
    },
    summary="Upload an image (≤ 2 MB) or a voice clip (≤ 1 MB)",
)
async def upload_media(
    kind: Annotated[Literal["image", "audio"], Form()],
    file: Annotated[
        UploadFile, File(description="PNG, JPEG or WebP; or MP3, M4A/AAC, OGG or WAV. Judged by magic bytes.")
    ],
    response: Response,
    session: Db,
) -> Envelope[a.MediaAsset]:
    # One byte over the cap is enough to refuse; the rest is never read.
    data = await file.read(uploads.MAX_BYTES[kind] + 1)
    asset, created = await uploads.store(session, kind, data)
    await session.commit()
    response.status_code = 201 if created else 200
    return ok(uploads.view(asset))
