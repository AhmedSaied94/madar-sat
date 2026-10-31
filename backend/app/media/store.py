"""Content-addressed media storage under ``MEDIA_ROOT`` (README rule 16, research R10).

One ``media_assets`` row and one file per SHA-256 of the encoded bytes: storing the same
bytes twice returns the existing row and writes nothing.
"""

from __future__ import annotations

import os
import tempfile
from pathlib import Path
from typing import Any

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import Session

from app.db.models import MediaAsset


def relative_path(fields: dict[str, Any]) -> str:
    """``<kind>/<sha[:2]>/<sha>.<ext>``, the path stored in ``media_assets.path``."""
    sha = fields["sha256"]
    ext = "webp" if fields["mime"] == "image/webp" else "mp4"
    return f"{fields['kind']}/{sha[:2]}/{sha}.{ext}"


def write_file(media_root: str | Path, rel_path: str, data: bytes) -> None:
    """Write atomically (temp file, then rename), so a reader never sees half a file."""
    target = Path(media_root) / rel_path
    target.parent.mkdir(parents=True, exist_ok=True)
    fd, tmp = tempfile.mkstemp(dir=target.parent, prefix=".upload-")
    try:
        with os.fdopen(fd, "wb") as handle:
            handle.write(data)
        Path(tmp).replace(target)
    except BaseException:
        Path(tmp).unlink(missing_ok=True)
        raise


def _new_asset(fields: dict[str, Any], rel_path: str, original_url: str | None) -> MediaAsset:
    return MediaAsset(
        sha256=fields["sha256"],
        kind=fields["kind"],
        path=rel_path,
        mime=fields["mime"],
        bytes=fields["bytes"],
        width=fields["width"],
        height=fields["height"],
        duration_ms=fields["duration_ms"],
        original_url=original_url,
    )


def get_or_create_asset(
    session: Session, media_root: str | Path, fields: dict[str, Any], original_url: str | None = None
) -> tuple[MediaAsset, bool]:
    """Return ``(asset, created)`` for encoded ``fields`` (from ``encode_media``)."""
    existing = session.execute(select(MediaAsset).where(MediaAsset.sha256 == fields["sha256"])).scalar_one_or_none()
    if existing is not None:
        return existing, False
    rel_path = relative_path(fields)
    write_file(media_root, rel_path, fields["encoded"])
    asset = _new_asset(fields, rel_path, original_url)
    session.add(asset)
    session.flush()
    return asset, True


async def aget_or_create_asset(
    session: AsyncSession, media_root: str | Path, fields: dict[str, Any], original_url: str | None = None
) -> tuple[MediaAsset, bool]:
    """``get_or_create_asset`` for an async session. The file write is quick; callers keep it off the loop."""
    result = await session.execute(select(MediaAsset).where(MediaAsset.sha256 == fields["sha256"]))
    existing = result.scalar_one_or_none()
    if existing is not None:
        return existing, False
    rel_path = relative_path(fields)
    write_file(media_root, rel_path, fields["encoded"])
    asset = _new_asset(fields, rel_path, original_url)
    session.add(asset)
    await session.flush()
    return asset, True
