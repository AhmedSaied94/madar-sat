"""Re-encoding media into the two stored formats (README rule 16, research R10).

Images become WebP at most 512 px on a side, with no EXIF, ICC or XMP. Audio becomes AAC in
MP4, trimmed to 30 s. Both the snapshot rehoster and the admin upload route use this code, so a
file is judged the same way wherever it comes from.
"""

from __future__ import annotations

import hashlib
import io
import shutil
import subprocess
import tempfile
import warnings
from pathlib import Path
from typing import Any, Protocol

import httpx
from PIL import Image, ImageOps

from app.media.errors import RehostError
from app.media.fetch import fetch_media

MAX_ASSET_BYTES = 2 * 1024 * 1024  # ck_media_assets_bytes
MAX_IMAGE_PX = 512
MAX_IMAGE_PIXELS = 40_000_000  # decompression-bomb guard (research R10)
MAX_AUDIO_S = 30

Image.MAX_IMAGE_PIXELS = MAX_IMAGE_PIXELS
# Pillow warns about a probable bomb before ``encode_image`` refuses it with the explicit pixel check below.
warnings.filterwarnings("ignore", category=Image.DecompressionBombWarning)


class MediaSource(Protocol):
    """What ``download_and_encode`` needs from a rehost target."""

    @property
    def kind(self) -> str: ...

    @property
    def url(self) -> str: ...


def encode_image(data: bytes) -> tuple[bytes, int, int]:
    """Decode, drop all metadata and re-encode as WebP ≤ 512 px. Returns ``(bytes, width, height)``."""
    try:
        with Image.open(io.BytesIO(data)) as src:
            if src.width * src.height > MAX_IMAGE_PIXELS:
                raise RehostError("decode_error")
            # Apply the EXIF orientation before the metadata is dropped.
            img = ImageOps.exif_transpose(src)
            has_alpha = img.mode in ("RGBA", "LA", "PA") or "transparency" in img.info
            img = img.convert("RGBA" if has_alpha else "RGB")  # WebP keeps the alpha channel
            img.thumbnail((MAX_IMAGE_PX, MAX_IMAGE_PX))
            img.info.clear()  # no EXIF, ICC or XMP in the output
            out = io.BytesIO()
            img.save(out, format="WEBP")
            return out.getvalue(), img.width, img.height
    except RehostError:
        raise
    except Exception as e:
        raise RehostError("decode_error") from e


def encode_audio(data: bytes) -> tuple[bytes, int]:
    """Re-encode to AAC in MP4, at most 30 s, with no metadata. Returns ``(bytes, duration_ms)``."""
    ffmpeg = shutil.which("ffmpeg")
    if ffmpeg is None:
        raise RehostError("decode_error")
    with tempfile.TemporaryDirectory(prefix="madar-audio-") as tmp:
        src, dst = Path(tmp) / "in", Path(tmp) / "out.mp4"
        src.write_bytes(data)
        try:
            subprocess.run(
                [ffmpeg, "-nostdin", "-y", "-i", str(src), "-t", str(MAX_AUDIO_S), "-vn", "-map_metadata", "-1"]
                + ["-c:a", "aac", str(dst)],
                check=True,
                capture_output=True,
                timeout=60,
            )
        except (subprocess.SubprocessError, OSError) as e:
            raise RehostError("decode_error") from e
        encoded = dst.read_bytes() if dst.exists() else b""
        if not encoded:
            raise RehostError("decode_error")
        return encoded, audio_duration_ms(dst)


def audio_duration_ms(path: Path) -> int:
    """Duration from ffprobe, clamped into ck_media_assets_audio's 1–30000 ms."""
    ffprobe = shutil.which("ffprobe")
    if ffprobe is None:
        raise RehostError("decode_error")
    try:
        out = subprocess.run(
            [ffprobe, "-v", "error", "-show_entries", "format=duration", "-of", "default=noprint_wrappers=1:nokey=1"]
            + [str(path)],
            check=True,
            capture_output=True,
            text=True,
            timeout=10,
        ).stdout.strip()
        ms = int(float(out) * 1000)
    except (subprocess.SubprocessError, OSError, ValueError) as e:
        raise RehostError("decode_error") from e
    return min(max(ms, 1), MAX_AUDIO_S * 1000)


def encode_media(kind: str, data: bytes) -> dict[str, Any]:
    """Encode ``data`` for a ``media_assets`` row of ``kind`` (``logo``, ``photo`` or ``audio``).

    Returns the row's fields plus ``encoded`` (the bytes to store). Raises ``RehostError``.
    """
    if kind == "audio":
        encoded, duration = encode_audio(data)
        fields: dict[str, Any] = {
            "kind": "audio",
            "mime": "audio/mp4",
            "width": None,
            "height": None,
            "duration_ms": duration,
        }
    else:
        encoded, width, height = encode_image(data)
        stored_kind = kind if kind in ("logo", "photo") else "logo"
        fields = {"kind": stored_kind, "mime": "image/webp", "width": width, "height": height, "duration_ms": None}
    if len(encoded) > MAX_ASSET_BYTES:
        raise RehostError("too_large")
    fields.update(sha256=hashlib.sha256(encoded).hexdigest(), bytes=len(encoded), encoded=encoded)
    return fields


def download_and_encode(
    target: MediaSource, allowed_hosts: list[str], client: httpx.Client
) -> tuple[dict[str, Any] | None, str | None]:
    """Download + encode one URL. Returns (fields, failure_reason)."""
    try:
        return encode_media(target.kind, fetch_media(client, target.url, allowed_hosts)), None
    except RehostError as e:
        return None, e.reason
