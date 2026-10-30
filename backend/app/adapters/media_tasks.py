"""The media worker: rehost one importer-found logo (T075, R20, FR-024).

It runs on VPS-1 next to ``/srv/media``, so the file lands where Caddy serves it and no transfer
crosses the VCN. VPS-2's import workers only queue ``adapters.rehost_logo`` on the ``media`` queue.

Rules (R20), all tested in ``tests/adapters/test_rehost_logo.py``:

- an allowlisted host only, no redirect, 5 MB cap, re-encoded to WebP ≤ 512 px with no metadata;
- the same bytes reuse their ``media_assets`` row (content-addressed);
- the logo is set with ``UPDATE … WHERE id = :id AND logo_asset_id IS NULL``, so an editor's logo,
  or one set while the task ran, is never replaced;
- the change is audited with ``source`` set and bumps ``teams``/``competitions`` and ``matches``;
- a bad host, an oversize file or a decode failure is logged and dropped with the logo still NULL;
  a network error or a 5xx raises ``Retryable`` so Celery backs off.
"""

from __future__ import annotations

import hashlib
import logging
from dataclasses import dataclass
from typing import Any, cast

import httpx
from sqlalchemy import update
from sqlalchemy.engine import CursorResult

from app.adapters.tasks import redis_client
from app.workers import task
from app.workers.base import Retryable
from app.workers.locks import redis_lock

log = logging.getLogger(__name__)

MEDIA_LOCK_TTL = 10 * 60  # one rehost per URL at a time (data-model §Redis keys)
DROP_REASONS = frozenset({"host_not_allowed", "redirect_off_host", "too_large", "decode_error"})


@dataclass(frozen=True, slots=True)
class LogoSource:
    """What ``download_and_encode`` needs from one logo: its kind and URL."""

    url: str

    @property
    def kind(self) -> str:
        return "logo"


def lock_name(url: str) -> str:
    return f"lock:media:{hashlib.sha256(url.encode('utf-8')).hexdigest()}"


def should_retry(reason: str) -> bool:
    """A network error or a 5xx is transient; everything else means the file itself is unusable."""
    return reason in {"timeout", "http_error"} or reason.startswith("http_5")


@task(name="adapters.rehost_logo")
def rehost_logo(self: Any, entity: str, entity_id: int, url: str, source: str) -> dict[str, Any]:
    """Download, encode and store one logo into an empty ``logo_asset_id`` (R20)."""
    # Imported here: the fetch host never runs this task, so it never loads app.settings or app.db.
    from app.db.models import AuditLog, Competition, DatasetVersion, Team
    from app.db.session import SyncSession
    from app.media.encode import download_and_encode
    from app.media.store import get_or_create_asset
    from app.settings import get_settings

    if entity not in {"teams", "competitions"}:
        raise ValueError(f"rehost_logo takes teams or competitions, not {entity!r}")

    with redis_lock(lock_name(url), MEDIA_LOCK_TTL, client=redis_client()) as acquired:
        if not acquired:
            log.info("skipped", extra={"task": "adapters.rehost_logo", "url": url, "why": "lock_held"})
            return {"url": url, "skipped": True}

        settings = get_settings()
        with httpx.Client(follow_redirects=False, timeout=10.0) as client:
            fields, failure = download_and_encode(LogoSource(url=url), settings.media_rehost_allowed_hosts, client)
        if fields is None:
            reason = failure or "decode_error"
            if should_retry(reason):
                raise Retryable(f"logo fetch failed for {url}: {reason}")
            log.warning("logo_dropped", extra={"url": url, "why": reason, "source": source})
            return {"url": url, "filled": False, "reason": reason}

        model = Team if entity == "teams" else Competition
        with SyncSession() as session:
            asset, _created = get_or_create_asset(session, settings.media_root, fields, original_url=url)
            asset_id = asset.id
            result = cast(
                CursorResult[Any],
                session.execute(
                    update(model)
                    .where(model.id == entity_id, model.logo_asset_id.is_(None))
                    .values(logo_asset_id=asset.id)
                ),
            )
            if result.rowcount == 0:
                # An editor, or an earlier run, already set it: never replace a logo. Leaving the
                # block without a commit drops the asset row; the file stays content-addressed and
                # is reused by the next run.
                log.info("logo_already_set", extra={"entity": entity, "id": entity_id, "source": source})
                return {"url": url, "filled": False, "reason": "already_set"}
            session.add(
                AuditLog(
                    admin_user_id=None,
                    source=source,
                    entity=entity,
                    entity_id=entity_id,
                    action="update",
                    diff={"logo_asset_id": [None, asset_id]},
                )
            )
            session.execute(
                update(DatasetVersion)
                .where(DatasetVersion.name.in_([entity, "matches"]))
                .values(version=DatasetVersion.version + 1)
            )
            session.commit()

        # `expire_on_commit` makes `asset` stale here; keep the id as a plain value.
        log.info(
            "logo_filled",
            extra={"entity": entity, "id": entity_id, "asset": asset_id, "source": source},
        )
        return {"url": url, "filled": True, "asset_id": asset_id}
