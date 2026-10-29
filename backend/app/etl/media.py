"""Media rehosting (README rule 16, FR-006, research R10).

Downloads logos, photos and voice clips from allowlisted hosts only, re-encodes them
(images → WebP ≤ 512 px with metadata stripped; audio → AAC in MP4 ≤ 30 s), stores them
content-addressed (one ``media_assets`` row per SHA-256) and sets every referencing
``*_asset_id`` column. A URL whose content is already hosted is never downloaded again.
Downloads run concurrently; DB writes are serialized on the caller's session, and the
datasets of the rows that changed are bumped last (data-model "dataset_versions").
"""

from __future__ import annotations

import hashlib
import io
import shutil
import subprocess
import tempfile
from collections.abc import Iterable
from concurrent.futures import ThreadPoolExecutor
from dataclasses import dataclass
from pathlib import Path
from typing import Any
from urllib.parse import urlsplit

import httpx
from sqlalchemy import select
from sqlalchemy.orm import Session, aliased

from app.db.models import (
    BroadcastPreset,
    Channel,
    Commentator,
    Competition,
    Match,
    MatchCustomBroadcast,
    MediaAsset,
    RightsHolder,
    Satellite,
    Team,
)
from app.domain.arabic import ar_normalize
from app.etl.report import Report
from app.etl.snapshot import bump_dataset_versions, run_checks
from app.etl.types import Snapshot

MAX_BYTES = 5 * 1024 * 1024  # download cap
MAX_ASSET_BYTES = 2 * 1024 * 1024  # ck_media_assets_bytes
TIMEOUT_S = 10.0
WORKERS = 4
MAX_IMAGE_PX = 512
MAX_AUDIO_S = 30

_PLACEHOLDERS = {"⚽"}  # README rule 6
_NOT_LISTED = ar_normalize("غير مدرج")

# Target.table → (model, dataset bumped when one of its asset columns changes).
_TABLES: dict[str, tuple[Any, str | None]] = {
    "satellite": (Satellite, "satellites"),
    "competition": (Competition, "competitions"),
    "channel": (Channel, "channels"),
    "team": (Team, "teams"),
    "rights_holder": (RightsHolder, "rights_holders"),
    "match": (Match, "matches"),
    "match_custom_broadcast": (MatchCustomBroadcast, "matches"),
    "commentator": (Commentator, "commentators"),
    "broadcast": (BroadcastPreset, None),  # admin-only picker, no public dataset
}


class RehostError(Exception):
    def __init__(self, reason: str) -> None:
        super().__init__(reason)
        self.reason = reason


@dataclass(frozen=True)
class Target:
    kind: str  # logo | photo | audio
    url: str
    table: str  # a _TABLES key
    key: str  # legacy_id, name, or "<match legacy_id>#<slot>" for custom broadcasts
    column: str


def _host(url: str) -> str:
    return urlsplit(url).netloc


def fetch_media(client: httpx.Client, url: str, allowed_hosts: list[str]) -> bytes:
    """Fetch one media URL, enforcing the allowlist, redirect policy and size cap.

    The body is streamed and abandoned as soon as it passes ``MAX_BYTES`` (or when the
    declared ``Content-Length`` already does), so an oversized file is never fully read.
    """
    if _host(url) not in allowed_hosts:
        raise RehostError("host_not_allowed")
    body = bytearray()
    try:
        with client.stream("GET", url, follow_redirects=False, timeout=TIMEOUT_S) as response:
            if response.is_redirect:
                raise RehostError("redirect_off_host")
            if response.status_code != 200:
                raise RehostError(f"http_{response.status_code}")
            declared = response.headers.get("Content-Length", "")
            if declared.isdigit() and int(declared) > MAX_BYTES:
                raise RehostError("too_large")
            for chunk in response.iter_bytes():
                body.extend(chunk)
                if len(body) > MAX_BYTES:
                    raise RehostError("too_large")
    except httpx.TimeoutException as e:
        raise RehostError("timeout") from e
    except httpx.HTTPError as e:
        raise RehostError("http_error") from e
    if not body:
        raise RehostError("decode_error")
    return bytes(body)


def _encode_image(data: bytes) -> tuple[bytes, int, int]:
    from PIL import Image, ImageOps

    try:
        with Image.open(io.BytesIO(data)) as src:
            # Apply the EXIF orientation before the metadata is dropped.
            img = ImageOps.exif_transpose(src)
            has_alpha = img.mode in ("RGBA", "LA", "PA") or "transparency" in img.info
            img = img.convert("RGBA" if has_alpha else "RGB")  # WebP keeps the alpha channel
            img.thumbnail((MAX_IMAGE_PX, MAX_IMAGE_PX))
            img.info.clear()  # no EXIF, ICC or XMP in the output
            out = io.BytesIO()
            img.save(out, format="WEBP")
            return out.getvalue(), img.width, img.height
    except Exception as e:
        raise RehostError("decode_error") from e


def _encode_audio(data: bytes) -> tuple[bytes, int]:
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
        return encoded, _audio_duration_ms(dst)


def _audio_duration_ms(path: Path) -> int:
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


def download_and_encode(
    target: Target, allowed_hosts: list[str], client: httpx.Client
) -> tuple[dict[str, Any] | None, str | None]:
    """Download + encode one URL. Returns (fields, failure_reason)."""
    try:
        data = fetch_media(client, target.url, allowed_hosts)
        if target.kind == "audio":
            encoded, duration = _encode_audio(data)
            fields: dict[str, Any] = {
                "kind": "audio",
                "mime": "audio/mp4",
                "width": None,
                "height": None,
                "duration_ms": duration,
            }
        else:
            encoded, width, height = _encode_image(data)
            kind = target.kind if target.kind in ("logo", "photo") else "logo"
            fields = {"kind": kind, "mime": "image/webp", "width": width, "height": height, "duration_ms": None}
        if len(encoded) > MAX_ASSET_BYTES:
            raise RehostError("too_large")
        fields.update(sha256=hashlib.sha256(encoded).hexdigest(), bytes=len(encoded), encoded=encoded)
        return fields, None
    except RehostError as e:
        return None, e.reason


# --- Targets (README rule 16) ---------------------------------------------------


def _url(value: Any) -> str | None:
    """A media URL, or None for empty values and placeholders (README rule 6)."""
    url = str(value or "").strip()
    return url if url and url not in _PLACEHOLDERS else None


def _commentator_targets(name: Any, image: Any, audio: Any) -> list[Target]:
    name = str(name or "").strip()
    if ar_normalize(name) in ("", _NOT_LISTED):
        return []
    targets = []
    if image_url := _url(image):
        targets.append(Target("photo", image_url, "commentator", name, "photo_asset_id"))
    if audio_url := _url(audio):
        targets.append(Target("audio", audio_url, "commentator", name, "audio_asset_id"))
    return targets


def collect_targets(snapshot: Snapshot, match_teams: dict[str, tuple[str | None, str | None]]) -> list[Target]:
    """Enumerate every media URL in the snapshot with its referencing row and column.

    ``match_teams`` maps each loaded match's legacy id to its (home, away) team legacy ids:
    a match logo is kept only when it differs from its team's logo (NULL = use the team's).
    Merged listings have no row, so their match-level logos are skipped.
    """
    targets: list[Target] = []

    def add(kind: str, value: Any, table: str, key: str, column: str) -> None:
        if url := _url(value):
            targets.append(Target(kind, url, table, key, column))

    for s in snapshot.satellites:
        add("logo", s.get("logo"), "satellite", s["id"], "logo_asset_id")
    for c in snapshot.competitions:
        add("logo", c.get("logo"), "competition", c["id"], "logo_asset_id")
    for c in snapshot.channels:
        add("logo", c.get("logo"), "channel", c["id"], "logo_asset_id")
    team_logo: dict[str, str | None] = {}
    for t in snapshot.teams:
        team_logo[t["id"]] = _url(t.get("logo"))
        add("logo", t.get("logo"), "team", t["id"], "logo_asset_id")
    # The commentators list first: its copies win over the match copies (which never contradict it).
    for c in (snapshot.setting("commentators") or {}).get("list", []):
        targets += _commentator_targets(c.get("name"), c.get("image"), c.get("audio"))
    for b in (snapshot.setting("broadcasts") or {}).get("list", []):
        add("logo", b.get("logo"), "broadcast", b["name"], "logo_asset_id")
    for r in snapshot.rights:
        add("logo", r.get("channelLogo"), "rights_holder", r["id"], "logo_asset_id")

    for day in snapshot.match_days:
        for m in day.get("matches", []):
            targets += _commentator_targets(m.get("commentator"), m.get("commentatorImage"), m.get("commentatorAudio"))
            targets += _commentator_targets(
                m.get("commentator2"), m.get("commentatorImage2"), m.get("commentatorAudio2")
            )
            for entry in (m.get("channelCommentators") or {}).values():
                entry = entry or {}
                targets += _commentator_targets(entry.get("name"), entry.get("image"), entry.get("audio"))
                targets += _commentator_targets(entry.get("name2"), entry.get("image2"), entry.get("audio2"))

            if m["id"] not in match_teams:
                continue
            home, away = match_teams[m["id"]]
            for value, team, column in (
                (m.get("logo1"), home, "home_logo_asset_id"),
                (m.get("logo2"), away, "away_logo_asset_id"),
            ):
                url = _url(value)
                if url and url != team_logo.get(team or ""):
                    targets.append(Target("logo", url, "match", m["id"], column))
            add("logo", m.get("broadcastLogo"), "match_custom_broadcast", f"{m['id']}#1", "logo_asset_id")
            add("logo", m.get("broadcastLogo2"), "match_custom_broadcast", f"{m['id']}#2", "logo_asset_id")
    return targets


def _match_teams(session: Session) -> dict[str, tuple[str | None, str | None]]:
    home, away = aliased(Team), aliased(Team)
    rows = session.execute(
        select(Match.legacy_id, home.legacy_id, away.legacy_id)
        .outerjoin(home, home.id == Match.home_team_id)
        .outerjoin(away, away.id == Match.away_team_id)
        .where(Match.legacy_id.is_not(None))
    )
    return {legacy_id: (h, a) for legacy_id, h, a in rows if legacy_id is not None}


def _find_row(session: Session, target: Target) -> Any:
    model, _ = _TABLES[target.table]
    if target.table == "commentator":
        where = [Commentator.name_norm == ar_normalize(target.key)]
    elif target.table == "broadcast":
        where = [BroadcastPreset.name == target.key]
    elif target.table == "match_custom_broadcast":
        legacy_id, slot = target.key.rsplit("#", 1)
        match_id = select(Match.id).where(Match.legacy_id == legacy_id).scalar_subquery()
        where = [MatchCustomBroadcast.match_id == match_id, MatchCustomBroadcast.slot == int(slot)]
    else:
        where = [model.legacy_id == target.key]
    return session.execute(select(model).where(*where)).scalar_one_or_none()


def _apply(session: Session, targets: Iterable[Target], asset_id: int) -> set[str]:
    """Set the asset on every row that references the URL and has no asset yet.

    Returns the datasets whose rows changed.
    """
    touched: set[str] = set()
    for target in targets:
        row = _find_row(session, target)
        if row is not None and getattr(row, target.column) is None:
            setattr(row, target.column, asset_id)
            dataset = _TABLES[target.table][1]
            if dataset is not None:
                touched.add(dataset)
    return touched


def _nothing_to_set(session: Session, targets: list[Target]) -> bool:
    """True when the URL's rows exist and already have their asset (e.g. deduplicated on a
    previous run, whose ``original_url`` is the other URL's)."""
    rows = [(t, _find_row(session, t)) for t in targets]
    present = [(t, row) for t, row in rows if row is not None]
    return bool(present) and all(getattr(row, t.column) is not None for t, row in present)


def _hosted_assets(session: Session, urls: list[str]) -> dict[str, int]:
    """``original_url`` → asset id for URLs already in ``media_assets``."""
    found: dict[str, int] = {}
    for i in range(0, len(urls), 1000):
        rows = session.execute(
            select(MediaAsset.original_url, MediaAsset.id).where(MediaAsset.original_url.in_(urls[i : i + 1000]))
        )
        for url, asset_id in rows:
            if url is not None:
                found.setdefault(url, asset_id)
    return found


def rehost(
    session: Session,
    snapshot: Snapshot,
    report: Report,
    media_root: str,
    allowed_hosts: list[str],
    client: httpx.Client | None = None,
) -> None:
    """Rehost every snapshot media URL. Idempotent: hosted URLs are skipped before any download."""
    by_url: dict[str, list[Target]] = {}
    for t in collect_targets(snapshot, _match_teams(session)):
        by_url.setdefault(t.url, []).append(t)

    media: dict[str, Any] = {
        "urls_total": len(by_url),
        "already_hosted": 0,
        "rehosted": 0,
        "deduplicated": 0,
        "failed": 0,
        "fail_reasons": {},
        "hosts": {},
    }
    for url in by_url:
        media["hosts"][_host(url)] = media["hosts"].get(_host(url), 0) + 1

    touched: set[str] = set()
    hosted = _hosted_assets(session, list(by_url))
    pending: list[str] = []
    for url, targets in by_url.items():
        if url in hosted:
            media["already_hosted"] += 1
            touched |= _apply(session, targets, hosted[url])
        elif _nothing_to_set(session, targets):
            media["already_hosted"] += 1
        else:
            pending.append(url)

    own_client = client is None
    http = client or httpx.Client()
    root = Path(media_root)

    def work(url: str) -> tuple[str, tuple[dict[str, Any] | None, str | None]]:
        return url, download_and_encode(by_url[url][0], allowed_hosts, http)

    try:
        with ThreadPoolExecutor(max_workers=WORKERS) as pool:
            # Results arrive in order on this thread, so the session is only used here.
            for url, (fields, reason) in pool.map(work, pending):
                if fields is None:
                    reason = reason or "decode_error"
                    media["failed"] += 1
                    media["fail_reasons"][reason] = media["fail_reasons"].get(reason, 0) + 1
                    report.detail("media", url, "skip", reason)
                    continue

                sha = fields["sha256"]
                asset = session.execute(select(MediaAsset).where(MediaAsset.sha256 == sha)).scalar_one_or_none()
                if asset is not None:
                    media["deduplicated"] += 1
                else:
                    ext = "webp" if fields["mime"] == "image/webp" else "mp4"
                    rel_path = f"{fields['kind']}/{sha[:2]}/{sha}.{ext}"
                    abs_path = root / rel_path
                    abs_path.parent.mkdir(parents=True, exist_ok=True)
                    abs_path.write_bytes(fields["encoded"])
                    asset = MediaAsset(
                        sha256=sha,
                        kind=fields["kind"],
                        path=rel_path,
                        mime=fields["mime"],
                        bytes=fields["bytes"],
                        width=fields["width"],
                        height=fields["height"],
                        duration_ms=fields["duration_ms"],
                        original_url=url,
                    )
                    session.add(asset)
                    session.flush()
                    media["rehosted"] += 1
                touched |= _apply(session, by_url[url], asset.id)
    finally:
        if own_client:
            http.close()

    report.media = media
    run_checks(session, report)
    # Asset changes bump the datasets of the rows that reference them (data-model).
    bump_dataset_versions(session, touched)
