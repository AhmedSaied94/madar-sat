"""POST /admin/api/media: magic bytes, caps, re-encoding and dedupe (T028, R10)."""

from __future__ import annotations

import io
import shutil
import struct
import wave
import zlib
from pathlib import Path

import pytest
from PIL import Image
from sqlalchemy import func, select

from app.db.models import MediaAsset
from app.services.admin import uploads
from app.settings import get_settings
from tests.admin.helpers import ADMIN, changed_datasets, create, dataset_versions

MEDIA = f"{ADMIN}/media"
NEEDS_FFMPEG = pytest.mark.skipif(shutil.which("ffmpeg") is None, reason="ffmpeg is installed in CI and the image")


def png(size=(800, 600), color=(200, 30, 30)) -> bytes:
    buf = io.BytesIO()
    Image.new("RGB", size, color).save(buf, "PNG")
    return buf.getvalue()


def jpeg_with_exif(size=(1000, 800)) -> bytes:
    exif = Image.Exif()
    exif[0x010F] = "Camera Maker"  # Make
    exif[0x0112] = 1  # Orientation
    buf = io.BytesIO()
    Image.new("RGB", size, (10, 120, 200)).save(buf, "JPEG", exif=exif)
    return buf.getvalue()


def webp(size=(300, 300)) -> bytes:
    buf = io.BytesIO()
    Image.new("RGB", size, (30, 200, 30)).save(buf, "WEBP")
    return buf.getvalue()


def wav(seconds: float, rate: int = 8000) -> bytes:
    buf = io.BytesIO()
    with wave.open(buf, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(rate)
        w.writeframes(b"\x00\x00" * int(rate * seconds))
    return buf.getvalue()


def bomb_png(side: int = 7000) -> bytes:
    """A valid grayscale PNG of ``side`` x ``side`` pixels: a few dozen KB that decode to ~49 MB."""

    def chunk(kind: bytes, payload: bytes) -> bytes:
        return struct.pack(">I", len(payload)) + kind + payload + struct.pack(">I", zlib.crc32(kind + payload))

    header = struct.pack(">IIBBBBB", side, side, 8, 0, 0, 0, 0)
    pixels = zlib.compress((b"\x00" + b"\x00" * side) * side, 9)
    return b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", header) + chunk(b"IDAT", pixels) + chunk(b"IEND", b"")


async def upload(client, data: bytes, kind: str = "image", name: str = "file.bin", content_type: str = "image/png"):
    return await client.post(MEDIA, data={"kind": kind}, files={"file": (name, data, content_type)})


@pytest.fixture
def media_root(tmp_path, monkeypatch) -> Path:
    monkeypatch.setattr(get_settings(), "media_root", str(tmp_path))
    return tmp_path


# --- magic signatures ---------------------------------------------------------------------------------------


@pytest.mark.parametrize("make", [png, jpeg_with_exif, webp], ids=["png", "jpeg", "webp"])
async def test_each_image_signature_is_accepted_and_stored_as_a_small_webp(editor_client, media_root, make):
    resp = await upload(editor_client, make())

    assert resp.status_code == 201, resp.text
    data = resp.json()["data"]
    assert set(data) == {"id", "kind", "url", "width", "height", "duration_ms", "bytes"}
    assert data["kind"] == "image"
    assert data["duration_ms"] is None
    assert 0 < data["width"] <= 512 and 0 < data["height"] <= 512
    assert data["url"].startswith(get_settings().media_base_url + "/")
    assert data["bytes"] == (media_root / data["url"].removeprefix(get_settings().media_base_url + "/")).stat().st_size
    assert "etag" not in resp.headers  # an asset is immutable and content-addressed: nothing to version


@pytest.mark.parametrize(
    "head",
    [
        b"ID3\x03\x00\x00\x00\x00\x00\x00",  # MP3 with an ID3 tag
        b"\xff\xfb\x90\x00" + b"\x00" * 8,  # an MP3 frame sync
        b"\xff\xf3\x90\x00" + b"\x00" * 8,  # an MPEG-2 frame sync
        b"\x00\x00\x00\x18ftypM4A \x00\x00\x00\x00",  # M4A/AAC
        b"OggS\x00\x02\x00\x00\x00\x00\x00\x00",  # OGG
    ],
    ids=["mp3-id3", "mp3-sync", "mp3-mpeg2", "m4a", "ogg"],
)
async def test_each_audio_signature_gets_past_the_type_check(editor_client, media_root, head):
    """The bytes after the signature aren't audio, so the answer is 422 (can't decode), not 415."""
    resp = await upload(editor_client, head + b"\x00" * 200, kind="audio", content_type="audio/mpeg")

    assert resp.status_code == 422
    assert resp.json()["error"]["code"] == "media_invalid"


@NEEDS_FFMPEG
async def test_a_wav_is_accepted_and_stored_as_aac_in_mp4(editor_client, media_root):
    resp = await upload(editor_client, wav(2), kind="audio", content_type="audio/wav")

    assert resp.status_code == 201, resp.text
    data = resp.json()["data"]
    assert data["kind"] == "audio"
    assert (data["width"], data["height"]) == (None, None)
    assert 1500 <= data["duration_ms"] <= 2500
    assert data["url"].endswith(".mp4")


@pytest.mark.parametrize(
    ("data", "kind"),
    [
        (b"\x89PNG\r\n\x1a\n", "image"),
        (b"\xff\xd8\xff\xe0", "image"),
        (b"RIFF\x00\x00\x00\x00WEBP", "image"),
        (b"RIFF\x00\x00\x00\x00WAVE", "audio"),
        (b"ID3\x04", "audio"),
        (b"\xff\xfb\x90", "audio"),
        (b"\x00\x00\x00\x18ftypisom", "audio"),
        (b"OggS\x00", "audio"),
    ],
)
def test_sniff_reads_the_signature_only(data, kind):
    assert uploads.sniff(data + b"\x00" * 16) == kind


@pytest.mark.parametrize(
    "data", [b"", b"hello world", b"<svg></svg>", b"GIF89a", b"%PDF-1.4", b"PK\x03\x04", b"\xff\x00"]
)
def test_sniff_refuses_everything_else(data):
    assert uploads.sniff(data + b"\x00" * 16) is None


# --- type, size and decoding errors -------------------------------------------------------------------------


async def test_a_text_file_named_png_with_an_image_content_type_is_415(editor_client, media_root):
    resp = await upload(editor_client, b"just some text, not an image", name="logo.png", content_type="image/png")

    assert resp.status_code == 415
    assert resp.json()["error"]["code"] == "unsupported_media_type"


async def test_the_kind_must_match_the_bytes(editor_client, media_root):
    image_as_audio = await upload(editor_client, png(), kind="audio", content_type="audio/mpeg")
    audio_as_image = await upload(editor_client, wav(1), kind="image", content_type="image/png")

    assert image_as_audio.status_code == 415
    assert audio_as_image.status_code == 415


@pytest.mark.parametrize("data", [b"<svg xmlns='http://www.w3.org/2000/svg'/>", b"GIF89a....", b"%PDF-1.7"])
async def test_other_formats_are_415(editor_client, media_root, data):
    assert (await upload(editor_client, data)).status_code == 415


async def test_an_image_over_2_mb_is_413_with_the_cap(editor_client, media_root):
    big = b"\x89PNG\r\n\x1a\n" + b"\x00" * (3 * 1024 * 1024)

    resp = await upload(editor_client, big)

    assert resp.status_code == 413
    assert resp.json()["error"]["code"] == "file_too_large"
    assert resp.json()["meta"] == {"max_bytes": 2 * 1024 * 1024}
    assert list(media_root.iterdir()) == []


async def test_an_image_just_over_the_cap_is_413_after_parsing(editor_client, media_root):
    """Under the request limit (cap + 64 KB), so it is read, then refused by its own cap."""
    resp = await upload(editor_client, b"\x89PNG\r\n\x1a\n" + b"\x00" * (2 * 1024 * 1024 + 100))

    assert resp.status_code == 413
    assert resp.json()["meta"]["max_bytes"] == 2 * 1024 * 1024


async def test_audio_over_1_mb_is_413_with_its_own_cap(editor_client, media_root):
    resp = await upload(
        editor_client, b"ID3\x03" + b"\x00" * (1024 * 1024 + 10), kind="audio", content_type="audio/mpeg"
    )

    assert resp.status_code == 413
    assert resp.json()["meta"] == {"max_bytes": 1024 * 1024}


async def test_a_request_far_over_the_limit_is_refused_from_content_length(editor_client, media_root, monkeypatch):
    seen: list[str] = []
    original = uploads.store

    async def spy(*args, **kwargs):
        seen.append("parsed")
        return await original(*args, **kwargs)

    monkeypatch.setattr(uploads, "store", spy)

    resp = await upload(editor_client, b"\x89PNG" + b"\x00" * (5 * 1024 * 1024))

    assert resp.status_code == 413
    assert seen == []  # the handler never ran: the body was not parsed


# Pillow warns before the pixel check refuses the file.
@pytest.mark.filterwarnings("ignore::PIL.Image.DecompressionBombWarning")
async def test_a_decompression_bomb_is_422(editor_client, media_root):
    bomb = bomb_png()
    assert len(bomb) < uploads.IMAGE_MAX_BYTES  # small on the wire, huge once decoded

    resp = await upload(editor_client, bomb)

    assert resp.status_code == 422
    assert resp.json()["error"]["code"] == "media_invalid"


async def test_a_file_that_will_not_decode_is_422(editor_client, media_root):
    resp = await upload(editor_client, b"\x89PNG\r\n\x1a\n" + b"this is not a real png" * 20)

    assert resp.status_code == 422
    assert resp.json()["error"]["code"] == "media_invalid"
    assert list(media_root.iterdir()) == []


# --- dedupe, re-encoding ------------------------------------------------------------------------------------


async def test_the_same_bytes_twice_give_the_same_asset(editor_client, media_root, session):
    first = await upload(editor_client, png(color=(1, 2, 3)))
    second = await upload(editor_client, png(color=(1, 2, 3)))

    assert (first.status_code, second.status_code) == (201, 200)
    assert first.json()["data"] == second.json()["data"]
    rows = await session.scalar(
        select(func.count()).select_from(MediaAsset).where(MediaAsset.id == first.json()["data"]["id"])
    )
    assert rows == 1
    assert len([p for p in media_root.rglob("*") if p.is_file()]) == 1


async def test_an_image_comes_back_as_webp_up_to_512_px_without_exif(editor_client, media_root):
    resp = await upload(editor_client, jpeg_with_exif((1000, 800)), content_type="image/jpeg")

    data = resp.json()["data"]
    stored = media_root / data["url"].removeprefix(get_settings().media_base_url + "/")
    with Image.open(stored) as image:
        assert image.format == "WEBP"
        assert max(image.size) == 512 and image.size == (data["width"], data["height"])
        assert not image.getexif()
        assert "exif" not in image.info


@NEEDS_FFMPEG
async def test_45_seconds_of_audio_come_back_trimmed_to_30(editor_client, media_root):
    clip = wav(45)
    assert len(clip) < uploads.AUDIO_MAX_BYTES

    resp = await upload(editor_client, clip, kind="audio", content_type="audio/wav")

    assert resp.status_code == 201, resp.text
    assert 29000 <= resp.json()["data"]["duration_ms"] <= 30000


async def test_an_upload_alone_bumps_no_dataset_and_the_asset_is_usable(editor_client, media_root, session):
    before = await dataset_versions(session)
    asset = (await upload(editor_client, png(color=(9, 9, 9)))).json()["data"]

    assert await changed_datasets(session, before) == set()
    team = await create(editor_client, f"{ADMIN}/teams", {"name": "فريق بشعار مرفوع", "logo_asset_id": asset["id"]})
    assert team["logo"] == asset["url"]


async def test_an_audio_asset_cannot_be_a_logo(editor_client, session):
    audio = MediaAsset(
        sha256="a" * 64, kind="audio", path="audio/aa/x.mp4", mime="audio/mp4", bytes=5, duration_ms=1000
    )
    session.add(audio)
    await session.flush()

    resp = await editor_client.post(f"{ADMIN}/teams", json={"name": "فريق", "logo_asset_id": audio.id})

    assert resp.status_code == 422
    assert {"loc": ["body", "logo_asset_id"], "type": "wrong_kind"} in resp.json()["meta"]["errors"]


# --- request shape and auth ----------------------------------------------------------------------------------


async def test_a_missing_or_unknown_kind_or_file_is_422(editor_client):
    no_file = await editor_client.post(MEDIA, data={"kind": "image"})
    no_kind = await editor_client.post(MEDIA, files={"file": ("a.png", png(), "image/png")})
    bad_kind = await editor_client.post(MEDIA, data={"kind": "video"}, files={"file": ("a.png", png(), "image/png")})

    assert {no_file.status_code, no_kind.status_code, bad_kind.status_code} == {422}


async def test_an_upload_needs_a_token(anon_admin_client):
    resp = await anon_admin_client.post(MEDIA, data={"kind": "image"}, files={"file": ("a.png", png(), "image/png")})

    assert resp.status_code == 401
