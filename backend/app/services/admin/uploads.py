"""Image and audio uploads (research R10, FR-012).

The type is decided by magic bytes, never by the file name or ``Content-Type``. Images become WebP at
most 512 px with no metadata and audio becomes AAC in MP4 of at most 30 s, by the same code the snapshot
rehoster uses (``app.media``). The result is content-addressed, so the same bytes twice give one asset.
"""

from __future__ import annotations

import asyncio
from typing import Literal

from sqlalchemy.ext.asyncio import AsyncSession

from app.api.errors import file_too_large, media_invalid, unsupported_media_type
from app.db.models import MediaAsset
from app.media.encode import encode_media
from app.media.errors import RehostError
from app.media.store import aget_or_create_asset
from app.schemas import admin as a
from app.services.common import media_url
from app.settings import get_settings

UploadKind = Literal["image", "audio"]

IMAGE_MAX_BYTES = 2 * 1024 * 1024
AUDIO_MAX_BYTES = 1 * 1024 * 1024
# Multipart framing around the file; a request larger than the biggest cap plus this is refused unread.
REQUEST_SLACK_BYTES = 64 * 1024
MAX_REQUEST_BYTES = IMAGE_MAX_BYTES + REQUEST_SLACK_BYTES
MAX_BYTES: dict[str, int] = {"image": IMAGE_MAX_BYTES, "audio": AUDIO_MAX_BYTES}


def sniff(data: bytes) -> UploadKind | None:
    """``image`` or ``audio`` when ``data`` starts with an allowed signature, else ``None``."""
    head = data[:12]
    if head[:4] == b"\x89PNG" or head[:3] == b"\xff\xd8\xff" or (head[:4] == b"RIFF" and head[8:12] == b"WEBP"):
        return "image"
    mp3_frame = len(head) >= 2 and head[0] == 0xFF and head[1] & 0xE0 == 0xE0
    if (
        head[:3] == b"ID3"
        or mp3_frame
        or head[4:8] == b"ftyp"
        or head[:4] == b"OggS"
        or (head[:4] == b"RIFF" and head[8:12] == b"WAVE")
    ):
        return "audio"
    return None


def view(asset: MediaAsset) -> a.MediaAsset:
    return a.MediaAsset(
        id=asset.id,
        kind="audio" if asset.kind == "audio" else "image",
        url=media_url(asset.path) or "",
        width=asset.width,
        height=asset.height,
        duration_ms=asset.duration_ms,
        bytes=asset.bytes,
    )


async def store(session: AsyncSession, kind: UploadKind, data: bytes) -> tuple[MediaAsset, bool]:
    """Validate, re-encode and store. Returns ``(asset, created)``; ``created`` is false for known bytes."""
    cap = MAX_BYTES[kind]
    if len(data) > cap:
        raise file_too_large(cap)
    if sniff(data) != kind:
        raise unsupported_media_type()

    try:
        # Pillow and ffmpeg block: keep them off the event loop.
        fields = await asyncio.to_thread(encode_media, "audio" if kind == "audio" else "logo", data)
    except RehostError as exc:
        if exc.reason == "too_large":
            raise file_too_large(cap) from None
        raise media_invalid() from None
    return await aget_or_create_asset(session, get_settings().media_root, fields)
