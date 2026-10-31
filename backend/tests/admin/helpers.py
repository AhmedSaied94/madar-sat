"""Shared helpers for the admin write tests."""

from __future__ import annotations

import hashlib
from typing import Any

from sqlalchemy import select

from app.db.models import AuditLog, DatasetVersion, MediaAsset

ADMIN = "/admin/api"


async def dataset_versions(session) -> dict[str, int]:
    rows = await session.execute(select(DatasetVersion.name, DatasetVersion.version))
    return dict(rows.all())


async def audit_rows(session, entity: str, entity_id: int | None = None) -> list[AuditLog]:
    query = select(AuditLog).where(AuditLog.entity == entity).order_by(AuditLog.id)
    if entity_id is not None:
        query = query.where(AuditLog.entity_id == entity_id)
    result = await session.scalars(query.execution_options(populate_existing=True))
    return list(result.all())


def if_match(etag: str) -> dict[str, str]:
    return {"If-Match": etag}


async def create(client, path: str, body: dict[str, Any]) -> dict[str, Any]:
    """POST and return ``data`` plus the ``ETag`` under ``_etag``."""
    resp = await client.post(path, json=body)
    assert resp.status_code == 201, resp.text
    return {**resp.json()["data"], "_etag": resp.headers["etag"]}


async def make_asset(session, name: str = "logo-1", kind: str = "logo") -> int:
    """A ``media_assets`` row (no file behind it) for tests that only need an id and a URL."""
    asset = MediaAsset(
        sha256=hashlib.sha256(name.encode()).hexdigest(),
        kind=kind,
        path=f"{'audio' if kind == 'audio' else 'logos'}/{name}",
        mime="audio/mp4" if kind == "audio" else "image/webp",
        bytes=10,
        width=None if kind == "audio" else 64,
        height=None if kind == "audio" else 64,
        duration_ms=1000 if kind == "audio" else None,
    )
    session.add(asset)
    await session.flush()
    return asset.id


KICKOFF = "2026-10-31T18:00:00Z"  # 20:00 in Cairo, still 31 October


def match_body(**overrides: Any) -> dict[str, Any]:
    body: dict[str, Any] = {
        "kickoff_at": KICKOFF,
        "match_date": "2026-10-31",
        "home": {"name": "فريق أ"},
        "away": {"name": "فريق ب"},
        "competition_name": "بطولة اختبار",
    }
    return {**body, **overrides}


async def new_match(client, **overrides: Any) -> dict[str, Any]:
    """Create a manual match; returns its ``AdminMatch`` data plus ``_etag``."""
    return await create(client, f"{ADMIN}/matches", match_body(**overrides))


async def patch_match(client, match: dict[str, Any], body: dict[str, Any]):
    """PATCH with the match's remembered ETag."""
    return await client.patch(f"{ADMIN}/matches/{match['id']}", json=body, headers=if_match(match["_etag"]))


async def changed_datasets(session, before: dict[str, int]) -> set[str]:
    """The datasets whose version moved since ``before``."""
    after = await dataset_versions(session)
    return {name for name, version in after.items() if version != before.get(name)}


# A match created through the API locks the fields the editor supplied (B1-R1-4), so an edit's
# lock list starts from these.
LOCKED_ON_CREATE = frozenset(
    {
        "kickoff_at",
        "competition_id",
        "competition_name",
        "home_team_id",
        "home_team_name",
        "away_team_id",
        "away_team_name",
    }
)


def locks(*added: str) -> list[str]:
    """The locks a created match has, plus the ones this edit adds."""
    return sorted(LOCKED_ON_CREATE | set(added))
