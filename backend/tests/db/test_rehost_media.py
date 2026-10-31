"""Media rehosting: allowlist, redirects, size caps, encoding, dedupe, idempotency (T015, README rule 16)."""

from __future__ import annotations

import hashlib
import io
import shutil
import subprocess
import wave
from collections.abc import Iterator
from pathlib import Path
from typing import Any

import httpx
import pytest
from PIL import Image
from sqlalchemy import text
from sqlalchemy.orm import Session

from app.etl.media import MAX_BYTES, RehostError, Target, download_and_encode, fetch_media, rehost
from app.etl.report import Report
from app.etl.snapshot import load
from app.etl.types import read_snapshot

SNAPSHOT_DIR = str(Path(__file__).resolve().parents[1] / "fixtures" / "snapshot")

ALLOWED = ["allowed.example"]
R2 = "pub-01ffc6064b9b435aa726a53a561a6f53.r2.dev"
SNAPSHOT_HOSTS = [R2, "imgs.ysscores.com"]


def _png(color: tuple[int, int, int], size: tuple[int, int] = (800, 600)) -> bytes:
    buf = io.BytesIO()
    Image.new("RGB", size, color).save(buf, "PNG")
    return buf.getvalue()


def _wav(seconds: float, rate: int = 8000) -> bytes:
    buf = io.BytesIO()
    with wave.open(buf, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(rate)
        w.writeframes(b"\x00\x00" * int(rate * seconds))
    return buf.getvalue()


def _client(handler: Any) -> httpx.Client:
    return httpx.Client(transport=httpx.MockTransport(handler))


class _CountingStream(httpx.SyncByteStream):
    """A response body that records how many bytes the client pulled."""

    def __init__(self, chunks: int, chunk_size: int = 1024 * 1024) -> None:
        self.chunks = chunks
        self.chunk_size = chunk_size
        self.sent = 0

    def __iter__(self) -> Iterator[bytes]:
        for _ in range(self.chunks):
            self.sent += self.chunk_size
            yield b"x" * self.chunk_size


# --- fetch_media ---------------------------------------------------------------


def test_fetch_allowlisted_host():
    with _client(lambda request: httpx.Response(200, content=b"data")) as client:
        assert fetch_media(client, "https://allowed.example/x.png", ALLOWED) == b"data"


def test_fetch_other_host_rejected_without_a_request():
    def handler(request):
        raise AssertionError("must not be called")

    with _client(handler) as client:
        with pytest.raises(RehostError) as e:
            fetch_media(client, "https://evil.example/x.png", ALLOWED)
    assert e.value.reason == "host_not_allowed"


def test_fetch_redirect_refused():
    with _client(lambda request: httpx.Response(302, headers={"Location": "https://evil.example/x.png"})) as client:
        with pytest.raises(RehostError) as e:
            fetch_media(client, "https://allowed.example/x.png", ALLOWED)
    assert e.value.reason == "redirect_off_host"


def test_fetch_too_large_by_content_length_reads_no_body():
    stream = _CountingStream(chunks=8)

    def handler(request):
        return httpx.Response(200, headers={"Content-Length": str(8 * 1024 * 1024)}, stream=stream)

    with _client(handler) as client:
        with pytest.raises(RehostError) as e:
            fetch_media(client, "https://allowed.example/x.png", ALLOWED)
    assert e.value.reason == "too_large"
    assert stream.sent == 0


def test_fetch_too_large_streamed_body_is_aborted():
    stream = _CountingStream(chunks=64)  # 64 MB, no Content-Length

    with _client(lambda request: httpx.Response(200, stream=stream)) as client:
        with pytest.raises(RehostError) as e:
            fetch_media(client, "https://allowed.example/x.png", ALLOWED)
    assert e.value.reason == "too_large"
    assert stream.sent <= MAX_BYTES + stream.chunk_size  # stopped right after the cap


# --- Encoding --------------------------------------------------------------------


def _encode(kind: str, body: bytes) -> dict[str, Any]:
    with _client(lambda request: httpx.Response(200, content=body)) as client:
        fields, reason = download_and_encode(Target(kind, "https://allowed.example/x", "t", "k", "c"), ALLOWED, client)
    assert reason is None and fields is not None
    return fields


def test_image_reencoded_to_webp_without_exif():
    exif = Image.Exif()
    exif[0x010F] = "MadarFixtureCam"  # Make
    exif[0x0112] = 6  # Orientation: rotate 90° CW
    buf = io.BytesIO()
    Image.new("RGB", (900, 600), (10, 200, 30)).save(buf, "JPEG", exif=exif.tobytes())
    source = buf.getvalue()
    assert b"Exif" in source and b"MadarFixtureCam" in source  # the input really carries EXIF

    fields = _encode("logo", source)
    encoded = fields["encoded"]
    assert fields["mime"] == "image/webp"
    assert b"Exif" not in encoded and b"MadarFixtureCam" not in encoded
    out = Image.open(io.BytesIO(encoded))
    assert out.format == "WEBP"
    assert "exif" not in out.info and len(out.getexif()) == 0
    # The orientation was applied before stripping it: 900×600 rotated → portrait, ≤ 512 px.
    assert (fields["width"], fields["height"]) == out.size == (341, 512)


def test_image_keeps_transparency():
    img = Image.new("RGBA", (64, 64), (255, 0, 0, 255))
    img.putpixel((0, 0), (0, 0, 0, 0))
    buf = io.BytesIO()
    img.save(buf, "PNG")

    out = Image.open(io.BytesIO(_encode("logo", buf.getvalue())["encoded"]))
    assert out.mode == "RGBA"
    assert out.getpixel((0, 0))[3] == 0
    assert out.getpixel((32, 32))[3] == 255


def test_opaque_image_has_no_alpha_channel():
    out = Image.open(io.BytesIO(_encode("logo", _png((1, 2, 3)))["encoded"]))
    assert out.mode == "RGB"


@pytest.mark.skipif(shutil.which("ffmpeg") is None, reason="ffmpeg is installed in CI and the image")
def test_audio_reencoded_to_aac_and_cut_to_30_s(tmp_path):
    fields = _encode("audio", _wav(seconds=35))
    assert fields["mime"] == "audio/mp4"
    assert 29_000 <= fields["duration_ms"] <= 30_000
    out = tmp_path / "clip.mp4"
    out.write_bytes(fields["encoded"])
    codec = subprocess.run(
        [
            "ffprobe",
            "-v",
            "error",
            "-select_streams",
            "a:0",
            "-show_entries",
            "stream=codec_name",
            "-of",
            "csv=p=0",
            out,
        ],
        check=True,
        capture_output=True,
        text=True,
    ).stdout.strip()
    assert codec == "aac"


def test_undecodable_image_fails_cleanly():
    with _client(lambda request: httpx.Response(200, content=b"not an image")) as client:
        fields, reason = download_and_encode(
            Target("logo", "https://allowed.example/x", "t", "k", "c"), ALLOWED, client
        )
    assert fields is None and reason == "decode_error"


# --- Full rehost over the loaded fixture ------------------------------------------


SAME_BYTES = {"/fixture/team-zamalek.png", "/fixture/sat-turksat.png"}  # two URLs, identical bytes


class _Server:
    """Serves the fixture's media URLs and records every request."""

    def __init__(self) -> None:
        self.requests: list[str] = []

    def __call__(self, request: httpx.Request) -> httpx.Response:
        self.requests.append(str(request.url))
        path = request.url.path
        if path == "/fixture/right-1.png":
            return httpx.Response(404)
        if path.endswith(".mp3"):
            return httpx.Response(200, content=_wav(seconds=2 if "audio-1" in path else 3))  # distinct clips
        if path in SAME_BYTES:
            return httpx.Response(200, content=_png((7, 7, 7)))
        digest = hashlib.sha256(path.encode()).digest()
        return httpx.Response(200, content=_png((digest[0], digest[1], digest[2])))


def _asset(s: Session, sql: str) -> Any:
    return s.execute(text(sql)).scalar_one()


def _versions(s: Session) -> dict[str, int]:
    return dict(s.execute(text("SELECT name, version FROM dataset_versions")).all())


@pytest.mark.skipif(shutil.which("ffmpeg") is None, reason="ffmpeg is installed in CI and the image")
def test_rehost_fixture_sets_every_rule_16_column(sync_session, tmp_path):
    s = sync_session
    snapshot = read_snapshot(SNAPSHOT_DIR)
    load(s, snapshot, Report("load-snapshot", SNAPSHOT_DIR))
    s.commit()
    versions_before = _versions(s)

    server = _Server()
    report = Report("rehost-media", SNAPSHOT_DIR)
    with _client(server) as client:
        rehost(s, snapshot, report, str(tmp_path), SNAPSHOT_HOSTS, client=client)
    s.commit()
    media = report.media
    assert media is not None

    # Counts reconcile (contracts/load-report.md "media").
    assert media["urls_total"] == media["already_hosted"] + media["rehosted"] + media["deduplicated"] + media["failed"]
    assert sum(media["fail_reasons"].values()) == media["failed"]
    assert sum(media["hosts"].values()) == media["urls_total"]
    assert media["fail_reasons"] == {"host_not_allowed": 1, "http_404": 1}
    assert media["deduplicated"] == 1
    assert report.reconciled is True
    assert media["hosts"]["imgs.ysscores.com"] == 1

    # Off-allowlist hosts are never fetched; each URL is fetched once.
    assert not any("not-allowed" in url for url in server.requests)
    assert len(server.requests) == len(set(server.requests)) == media["urls_total"] - 1

    # Every README rule-16 source.
    def set_(sql: str) -> int:
        value = _asset(s, sql)
        assert value is not None, sql
        return int(value)

    set_("SELECT logo_asset_id FROM satellites WHERE legacy_id = 'sat-turksat'")
    set_("SELECT logo_asset_id FROM competitions WHERE legacy_id = 'comp-1'")
    cyr = set_("SELECT logo_asset_id FROM channels WHERE legacy_id = 'ch-cyr'")
    assert set_("SELECT logo_asset_id FROM channels WHERE legacy_id = 'ch-nosr'") == cyr  # same URL, two rows
    set_("SELECT logo_asset_id FROM channels WHERE legacy_id = 'ch-nilesat-free'")  # imgs.ysscores.com
    zamalek = set_("SELECT logo_asset_id FROM teams WHERE legacy_id = 'team-zamalek'")
    assert set_("SELECT logo_asset_id FROM satellites WHERE legacy_id = 'sat-turksat'") == zamalek  # same bytes
    set_("SELECT logo_asset_id FROM teams WHERE legacy_id = 'team-ahly-eg'")
    set_("SELECT photo_asset_id FROM commentators WHERE name = 'معلق تجريبي'")
    set_("SELECT audio_asset_id FROM commentators WHERE name = 'معلق تجريبي'")
    # Commentators found only on matches take their media from the match copies.
    set_("SELECT photo_asset_id FROM commentators WHERE name = 'معلق على القناة فقط'")  # channelCommentators
    set_("SELECT audio_asset_id FROM commentators WHERE name = 'معلق على القناة فقط'")
    set_("SELECT photo_asset_id FROM commentators WHERE name = 'معلق ثان على المباراة'")  # commentatorImage2
    set_("SELECT logo_asset_id FROM broadcast_presets WHERE name = 'ON Sport 1'")
    set_(
        "SELECT b.logo_asset_id FROM match_custom_broadcasts b JOIN matches m ON m.id = b.match_id "
        "WHERE m.legacy_id = 'm-1' AND b.slot = 1"
    )
    set_(
        "SELECT b.logo_asset_id FROM match_custom_broadcasts b JOIN matches m ON m.id = b.match_id "
        "WHERE m.legacy_id = 'm-1' AND b.slot = 2"
    )
    set_("SELECT home_logo_asset_id FROM matches WHERE legacy_id = 'm-1'")  # logo1 differs from the team's

    # Rule 6 and the "same as the team" rule: these stay NULL.
    assert _asset(s, "SELECT away_logo_asset_id FROM matches WHERE legacy_id = 'm-1'") is None  # "⚽"
    assert _asset(s, "SELECT home_logo_asset_id FROM matches WHERE legacy_id = 'm-today'") is None
    # Failures leave the column NULL and are logged.
    assert _asset(s, "SELECT logo_asset_id FROM channels WHERE legacy_id = 'ch-badr-enc'") is None
    assert _asset(s, "SELECT logo_asset_id FROM rights_holders WHERE legacy_id = 'right-1'") is None
    failed = {(d["legacy_id"], d["reason"]) for d in report.details if d["collection"] == "media"}
    assert failed == {
        ("https://cdn.not-allowed.example/fixture/badr.png", "host_not_allowed"),
        (f"https://{R2}/fixture/right-1.png", "http_404"),
    }

    # Files are content-addressed under the media root; one row per SHA-256.
    rows = s.execute(text("SELECT sha256, kind, path, mime, original_url FROM media_assets")).all()
    assert len(rows) == media["rehosted"]
    for sha, kind, path, mime, original_url in rows:
        ext = "webp" if mime == "image/webp" else "mp4"
        assert path == f"{kind}/{sha[:2]}/{sha}.{ext}"
        assert hashlib.sha256((tmp_path / path).read_bytes()).hexdigest() == sha
        assert original_url.startswith("https://")
    assert {r.kind for r in rows} == {"logo", "photo", "audio"}

    # Asset changes bump the datasets of the rows that reference them.
    bumped = {k for k, v in _versions(s).items() if v != versions_before[k]}
    assert bumped == {"satellites", "competitions", "channels", "teams", "commentators", "matches", "broadcast_presets"}

    # Re-run: nothing is downloaded again and nothing changes.
    server.requests.clear()
    versions_mid = _versions(s)
    report2 = Report("rehost-media", SNAPSHOT_DIR)
    with _client(server) as client:
        rehost(s, snapshot, report2, str(tmp_path), SNAPSHOT_HOSTS, client=client)
    assert report2.media is not None
    assert server.requests == [f"https://{R2}/fixture/right-1.png"]  # only the failed URL is retried
    assert report2.media["already_hosted"] == media["rehosted"] + media["deduplicated"]
    assert report2.media["failed"] == 2
    assert _asset(s, "SELECT count(*) FROM media_assets") == media["rehosted"]
    assert _versions(s) == versions_mid
    assert report2.reconciled is True
