"""The media worker: one logo, never replaced, allowlisted, retried when transient (T065, R20)."""

from __future__ import annotations

import hashlib
import io
from pathlib import Path

import httpx
import pytest
import redis
from PIL import Image
from sqlalchemy import func, select
from sqlalchemy.orm import Session

from app.adapters.media_tasks import rehost_logo
from app.db.models import AuditLog, DatasetVersion, Match, MediaAsset, Team
from app.workers.base import Retryable
from app.workers.config import get_worker_settings

HOST = "imgs.ysscores.com"
URL = f"https://{HOST}/teams/64/logo.png"


def _png(color: tuple[int, int, int] = (200, 30, 30), size: tuple[int, int] = (800, 600)) -> bytes:
    buf = io.BytesIO()
    Image.new("RGB", size, color).save(buf, "PNG")
    return buf.getvalue()


@pytest.fixture
def redis_client() -> redis.Redis:
    client = redis.Redis.from_url(get_worker_settings().broker_url, decode_responses=True)
    client.flushdb()
    yield client
    client.flushdb()
    client.close()


@pytest.fixture
def media_root(tmp_path: Path) -> Path:
    return tmp_path / "media"


@pytest.fixture
def wire(monkeypatch: pytest.MonkeyPatch, media_root: Path, sync_session: Session):
    """Point the task at the test session, a temp media root and a mock HTTP transport."""
    import app.db.session as db_session
    from app.settings import get_settings

    # A new session on the test's connection, exactly how the task makes one: a commit inside it
    # releases a savepoint, so the task's work joins the test's rolled-back transaction.
    def factory() -> Session:
        return Session(bind=sync_session.connection(), join_transaction_mode="create_savepoint")

    monkeypatch.setattr(db_session, "SyncSession", factory)
    monkeypatch.setattr(get_settings(), "media_root", str(media_root))
    return monkeypatch


def _serve(monkeypatch: pytest.MonkeyPatch, handler) -> list[httpx.Request]:
    import app.adapters.media_tasks as module

    calls: list[httpx.Request] = []
    real_client = httpx.Client

    def record(request: httpx.Request) -> httpx.Response:
        calls.append(request)
        return handler(request)

    def factory(**kwargs) -> httpx.Client:
        kwargs.pop("follow_redirects", None)
        return real_client(transport=httpx.MockTransport(record), follow_redirects=False)

    monkeypatch.setattr(module.httpx, "Client", factory)
    return calls


def _team(session: Session, legacy_id: str = "team-city") -> Team:
    return session.execute(select(Team).where(Team.legacy_id == legacy_id)).scalar_one()


def _fresh(session: Session) -> Session:
    """The task used its own session on the same connection; start from a clean identity map."""
    session.expunge_all()
    return session


def _versions(session: Session) -> dict[str, int]:
    return dict(session.execute(select(DatasetVersion.name, DatasetVersion.version)).all())


def test_an_allowlisted_logo_fills_an_empty_field_and_is_audited(
    wire, sync_session: Session, loaded_snapshot, redis_client: redis.Redis
) -> None:
    team = _team(sync_session)
    assert team.logo_asset_id is None
    _serve(wire, lambda request: httpx.Response(200, content=_png()))
    before = _versions(sync_session)

    result = rehost_logo.apply(args=("teams", team.id, URL, "ysscores")).get()

    assert result["filled"] is True
    sync_session.expunge_all()
    updated = sync_session.execute(select(Team).where(Team.id == team.id)).scalar_one()
    assert updated.logo_asset_id == result["asset_id"]

    asset = sync_session.execute(select(MediaAsset).where(MediaAsset.id == result["asset_id"])).scalar_one()
    assert asset.kind == "logo" and asset.mime == "image/webp"
    assert asset.original_url == URL
    assert (Path(wire_media_root(asset))).exists() or asset.path

    audit = (
        sync_session.execute(select(AuditLog).where(AuditLog.entity == "teams", AuditLog.entity_id == team.id))
        .scalars()
        .all()
    )
    assert audit and audit[-1].source == "ysscores" and audit[-1].admin_user_id is None
    assert audit[-1].diff == {"logo_asset_id": [None, asset.id]}

    after = _versions(sync_session)
    assert after["teams"] == before["teams"] + 1
    assert after["matches"] == before["matches"] + 1


def wire_media_root(asset: MediaAsset) -> str:
    from app.settings import get_settings

    return str(Path(get_settings().media_root) / asset.path)


def test_an_existing_logo_is_never_replaced(
    wire, sync_session: Session, loaded_snapshot, redis_client: redis.Redis
) -> None:
    team_id = _team(sync_session, "team-zamalek").id
    asset = MediaAsset(
        sha256="a" * 64, kind="logo", path="logo/aa/keep.webp", mime="image/webp", bytes=9, width=64, height=64
    )
    sync_session.add(asset)
    sync_session.flush()
    sync_session.execute(__import__("sqlalchemy").update(Team).where(Team.id == team_id).values(logo_asset_id=asset.id))
    sync_session.flush()

    _serve(wire, lambda request: httpx.Response(200, content=_png()))
    result = rehost_logo.apply(args=("teams", team_id, URL, "ysscores")).get()

    assert result == {"url": URL, "filled": False, "reason": "already_set"}
    sync_session = _fresh(sync_session)
    assert sync_session.execute(select(Team.logo_asset_id).where(Team.id == team_id)).scalar_one() == asset.id


@pytest.mark.parametrize(
    ("handler", "reason"),
    [
        (lambda request: httpx.Response(404), "http_404"),
        (lambda request: httpx.Response(302, headers={"location": "https://evil.example/x"}), "redirect_off_host"),
        (lambda request: httpx.Response(200, content=b"not an image"), "decode_error"),
        (lambda request: httpx.Response(200, content=b"x" * (5 * 1024 * 1024 + 10)), "too_large"),
    ],
)
def test_a_bad_file_is_dropped_with_the_logo_still_empty(
    wire, sync_session: Session, loaded_snapshot, redis_client: redis.Redis, handler, reason: str
) -> None:
    team = _team(sync_session)
    _serve(wire, handler)
    result = rehost_logo.apply(args=("teams", team.id, URL, "ysscores")).get()

    assert result["filled"] is False
    assert result["reason"] == reason
    sync_session = _fresh(sync_session)
    assert sync_session.execute(select(Team.logo_asset_id).where(Team.id == team.id)).scalar_one() is None
    assert sync_session.execute(select(func.count()).select_from(MediaAsset)).scalar_one() == 0


def test_a_host_outside_the_allowlist_is_refused_without_a_request(
    wire, sync_session: Session, loaded_snapshot, redis_client: redis.Redis
) -> None:
    team = _team(sync_session)
    calls = _serve(wire, lambda request: httpx.Response(200, content=_png()))
    result = rehost_logo.apply(args=("teams", team.id, "https://evil.example/logo.png", "ysscores")).get()
    assert result["reason"] == "host_not_allowed"
    assert calls == []


@pytest.mark.parametrize("status", [500, 503])
def test_a_5xx_is_retryable(
    wire, sync_session: Session, loaded_snapshot, redis_client: redis.Redis, status: int
) -> None:
    team = _team(sync_session)
    _serve(wire, lambda request: httpx.Response(status))
    with pytest.raises(Retryable):
        rehost_logo.apply(args=("teams", team.id, URL, "ysscores")).get()


def test_a_network_error_is_retryable(wire, sync_session: Session, loaded_snapshot, redis_client: redis.Redis) -> None:
    team = _team(sync_session)

    def broken(request: httpx.Request) -> httpx.Response:
        raise httpx.ConnectError("no route", request=request)

    _serve(wire, broken)
    with pytest.raises(Retryable):
        rehost_logo.apply(args=("teams", team.id, URL, "ysscores")).get()


def test_the_same_bytes_reuse_the_media_asset(
    wire, sync_session: Session, loaded_snapshot, redis_client: redis.Redis
) -> None:
    first = _team(sync_session, "team-city")
    second = _team(sync_session, "team-zamalek")
    body = _png((10, 120, 200))
    _serve(wire, lambda request: httpx.Response(200, content=body))

    one = rehost_logo.apply(args=("teams", first.id, URL, "ysscores")).get()
    two = rehost_logo.apply(args=("teams", second.id, f"https://{HOST}/other.png", "ysscores")).get()
    sync_session = _fresh(sync_session)

    assert one["asset_id"] == two["asset_id"]
    assert sync_session.execute(select(func.count()).select_from(MediaAsset)).scalar_one() == 1


def test_a_duplicate_in_flight_is_dropped_by_its_lock(
    wire, sync_session: Session, loaded_snapshot, redis_client: redis.Redis
) -> None:
    from app.adapters.media_tasks import lock_name

    team = _team(sync_session)
    redis_client.set(lock_name(URL), "other", ex=60)
    calls = _serve(wire, lambda request: httpx.Response(200, content=_png()))
    result = rehost_logo.apply(args=("teams", team.id, URL, "ysscores")).get()
    assert result == {"url": URL, "skipped": True}
    assert calls == []


def test_the_lock_name_is_the_url_hash() -> None:
    from app.adapters.media_tasks import lock_name

    assert lock_name(URL) == f"lock:media:{hashlib.sha256(URL.encode()).hexdigest()}"


def test_a_competition_logo_fills_and_bumps_competitions(
    wire, sync_session: Session, loaded_snapshot, redis_client: redis.Redis
) -> None:
    from app.db.models import Competition

    competition = sync_session.execute(select(Competition).where(Competition.legacy_id == "comp-2")).scalar_one()
    before = _versions(sync_session)
    _serve(wire, lambda request: httpx.Response(200, content=_png((0, 200, 0))))
    result = rehost_logo.apply(args=("competitions", competition.id, URL, "ysscores")).get()
    assert result["filled"] is True
    sync_session = _fresh(sync_session)
    after = _versions(sync_session)
    assert after["competitions"] == before["competitions"] + 1
    assert after["matches"] == before["matches"] + 1


def test_the_logo_is_served_from_the_media_root_not_the_source(
    wire, sync_session: Session, loaded_snapshot, redis_client: redis.Redis
) -> None:
    team = _team(sync_session)
    _serve(wire, lambda request: httpx.Response(200, content=_png()))
    rehost_logo.apply(args=("teams", team.id, URL, "ysscores")).get()
    sync_session = _fresh(sync_session)
    asset = sync_session.execute(select(MediaAsset)).scalar_one()
    stored = Path(wire_media_root(asset))
    assert stored.is_file()
    with Image.open(stored) as image:
        assert max(image.size) <= 512
    assert "ysscores" not in asset.path


def test_a_match_is_not_touched_by_the_logo(
    wire, sync_session: Session, loaded_snapshot, redis_client: redis.Redis
) -> None:
    team_id = _team(sync_session).id
    matches = sync_session.execute(select(func.count()).select_from(Match)).scalar_one()
    _serve(wire, lambda request: httpx.Response(200, content=_png()))
    rehost_logo.apply(args=("teams", team_id, URL, "ysscores")).get()
    sync_session = _fresh(sync_session)
    assert sync_session.execute(select(func.count()).select_from(Match)).scalar_one() == matches
