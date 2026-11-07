"""The outbox log, the composer, reach and the test device (contracts/admin-api.md "Notifications").

Every row here is an ``notification_outbox`` row; the dispatcher sends it. The composer never takes a
route as text: it is built from the chosen target, so a push can only open a screen the app knows
(public-api "Routes and tags"). Reach wraps the dispatcher's audience conditions in ``count(*)``,
because a pending row shows what it would reach right now (research R7, R20).
"""

from __future__ import annotations

import uuid
from collections.abc import Iterable
from datetime import datetime
from typing import Any

from sqlalchemy import Select, and_, func, or_, select, text
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.errors import ApiError, EntityNotFound, validation_failed
from app.auth.roles import AuthedAdmin
from app.db.models import (
    AdminUser,
    Channel,
    Competition,
    Device,
    Match,
    NotificationOutbox,
    Team,
)
from app.domain.content import find_card_sharing_label
from app.schemas import admin as a
from app.services.admin import versions, writer

MATCH_AUDIENCES = ("match_followers", "match_core", "match_only")
LIST_TYPES = (
    "kickoff_reminder",
    "match_started",
    "goal",
    "final_score",
    "channels_updated",
    "frequency_changed",
    "announcement",
)
ANNOUNCEMENT_TYPE = "announcement"
# Announcements are read inside 15 s; the bucket is what brings new rows without a dataset bump.
BUCKET_S = 15

# The dispatcher's audience conditions, with parameters a kind doesn't use staying NULL. Fixed text
# and bound parameters only: no fragment is ever assembled from a request (constitution V).
_REACH_FOLLOWS = """
SELECT count(DISTINCT d.id)
  FROM devices d
  JOIN device_follows f ON f.device_id = d.id
 WHERE d.push_token IS NOT NULL
   AND btrim(d.push_token) <> ''
   AND (f.match_id = CAST(:match_id AS bigint)
        OR f.competition_id = CAST(:competition_id AS bigint)
        OR f.team_id IN (CAST(:home_team_id AS bigint), CAST(:away_team_id AS bigint))
        OR f.channel_id = CAST(:channel_id AS bigint))
   AND COALESCE((d.prefs ->> 'enabled')::boolean, true)
   AND COALESCE((d.prefs -> 'types' -> CAST(:type AS text) ->> 'on')::boolean, :default_on)
"""

_REACH_ALL = """
SELECT count(*)
  FROM devices d
 WHERE d.push_token IS NOT NULL
   AND btrim(d.push_token) <> ''
   AND COALESCE((d.prefs ->> 'enabled')::boolean, true)
   AND COALESCE((d.prefs -> 'types' -> CAST(:type AS text) ->> 'on')::boolean, :default_on)
"""

# ``match_started`` is off by default; every other type is on (push-pipeline "Audiences").
DEFAULT_ON: dict[str, bool] = {"match_started": False}


def _default_on(row_type: str) -> bool:
    return DEFAULT_ON.get("goal" if row_type == "correction" else row_type, True)


def _screen(*texts: str) -> None:
    """No free text that reaches a device may name a card-sharing service (content rule, admin-api)."""
    if any(find_card_sharing_label(text) is not None for text in texts):
        raise ApiError(422, "text_not_allowed")


def _no_id(field: str) -> ApiError:
    return validation_failed([{"loc": ["body", field, "id"], "type": "missing"}])


# --- Reach ---------------------------------------------------------------------------------------


async def reach(session: AsyncSession, *, kind: str, target_id: int | None, row_type: str = "announcement") -> int:
    """How many devices the audience reaches now, with the type's own switch applied."""
    params: dict[str, Any] = {
        "match_id": None,
        "competition_id": None,
        "home_team_id": None,
        "away_team_id": None,
        "channel_id": None,
        "type": row_type,
        "default_on": _default_on(row_type),
    }
    if kind == "all":
        statement = text(_REACH_ALL)
    else:
        if target_id is None:
            return 0
        # The outbox kinds and the reach kinds differ only in these three names (admin-api).
        kind = {"match_followers": "match", "match_core": "match", "match_only": "match"}.get(kind, kind)
        if kind == "match":
            params["match_id"] = target_id
        elif kind == "team":
            params["home_team_id"] = target_id
        elif kind == "competition":
            params["competition_id"] = target_id
        elif kind == "channel":
            params["channel_id"] = target_id
        else:
            return 0
        statement = text(_REACH_FOLLOWS)
    return int((await session.execute(statement, params)).scalar_one())


# --- The log ---------------------------------------------------------------------------------------


def _audience_target_id(audience: dict[str, Any]) -> int | None:
    for key in ("match_id", "channel_id", "team_id", "competition_id", "device_id"):
        if audience.get(key) is not None:
            return int(audience[key])
    return None


async def _labels(session: AsyncSession, audiences: Iterable[dict[str, Any]]) -> dict[tuple[str, int], str]:
    """``(kind, id) -> label`` for one page of rows, in at most four queries."""
    wanted: dict[str, set[int]] = {}
    for audience in audiences:
        kind = audience.get("kind")
        target_id = _audience_target_id(audience)
        if kind in MATCH_AUDIENCES and target_id is not None:
            wanted.setdefault("match", set()).add(target_id)
        elif kind in ("channel", "team", "competition") and target_id is not None:
            wanted.setdefault(kind, set()).add(target_id)

    labels: dict[tuple[str, int], str] = {}
    if wanted.get("match"):
        match_rows = await session.execute(
            select(Match.id, Match.home_team_name, Match.away_team_name).where(Match.id.in_(wanted["match"]))
        )
        for match_id, home, away in match_rows:
            labels[("match", match_id)] = f"{home} × {away}"
    if wanted.get("channel"):
        channel_rows = await session.execute(
            select(Channel.id, func.coalesce(Channel.display_name, Channel.name)).where(
                Channel.id.in_(wanted["channel"])
            )
        )
        labels.update({("channel", channel_id): name for channel_id, name in channel_rows})
    if wanted.get("team"):
        team_rows = await session.execute(select(Team.id, Team.name).where(Team.id.in_(wanted["team"])))
        labels.update({("team", team_id): name for team_id, name in team_rows})
    if wanted.get("competition"):
        competition_rows = await session.execute(
            select(Competition.id, Competition.name).where(Competition.id.in_(wanted["competition"]))
        )
        labels.update({("competition", competition_id): name for competition_id, name in competition_rows})
    return labels


def _target(audience: dict[str, Any], labels: dict[tuple[str, int], str]) -> a.NotificationTarget:
    kind = str(audience.get("kind", "all"))
    target_id = _audience_target_id(audience)
    if kind in MATCH_AUDIENCES:
        return a.NotificationTarget(
            kind=kind,
            label=labels.get(("match", target_id or 0)),
            id=target_id,
        )
    if kind in ("channel", "team", "competition"):
        return a.NotificationTarget(kind=kind, label=labels.get((kind, target_id or 0)), id=target_id)
    return a.NotificationTarget(kind=kind, label=None, id=target_id)


def _cursor_condition(cursor: list[Any]) -> Any:
    stamp = datetime.fromisoformat(str(cursor[0]))
    return or_(
        NotificationOutbox.created_at < stamp,
        and_(NotificationOutbox.created_at == stamp, NotificationOutbox.id < int(cursor[1])),
    )


async def list_log(
    session: AsyncSession,
    *,
    row_type: str | None,
    status: str | None,
    cursor: str | None,
    limit: int,
) -> tuple[list[a.NotificationRow], str | None]:
    """Newest first by ``(created_at, id)``; pending rows show the reach they have right now."""
    from app.services.admin.lists import decode_cursor, encode_cursor

    query: Select[Any] = select(NotificationOutbox)
    if row_type:
        query = query.where(NotificationOutbox.type == row_type)
    if status:
        query = query.where(NotificationOutbox.status == status)
    if cursor:
        query = query.where(_cursor_condition(decode_cursor(cursor, 2)))
    rows = list(
        (
            await session.scalars(
                query.order_by(NotificationOutbox.created_at.desc(), NotificationOutbox.id.desc()).limit(limit + 1)
            )
        ).all()
    )
    more = len(rows) > limit
    rows = rows[:limit]

    labels = await _labels(session, [row.audience or {} for row in rows])
    items = [await view(session, row, labels=labels) for row in rows]
    next_cursor = encode_cursor([rows[-1].created_at.isoformat(), rows[-1].id]) if more and rows else None
    return items, next_cursor


async def view(
    session: AsyncSession, row: NotificationOutbox, *, labels: dict[tuple[str, int], str] | None = None
) -> a.NotificationRow:
    """One row as A15 reads it: a pending row shows the reach it has right now (research R20)."""
    audience = row.audience or {}
    payload = row.payload or {}
    recipients = row.sent + row.failed
    if row.status not in ("sending", "sent", "failed", "cancelled"):
        recipients = await reach(
            session, kind=str(audience.get("kind", "all")), target_id=_audience_target_id(audience), row_type=row.type
        )
    if labels is None:
        labels = await _labels(session, [audience])
    return a.NotificationRow(
        id=row.id,
        type=row.type,
        status=row.status,
        error=row.error,
        target=_target(audience, labels),
        is_test=audience.get("kind") == "device",
        is_correction=payload.get("kind") == "correction",
        recipients=recipients,
        sent=row.sent,
        failed=row.failed,
        due_at=row.due_at,
        sent_at=row.sent_at,
        created_at=row.created_at,
    )


def row_version(row: NotificationOutbox) -> str:
    """The row's own version, for cancel's ``If-Match``."""
    return versions.etag_of(versions.row_state(row))


# --- Targets and audiences -------------------------------------------------------------------------


async def _route(session: AsyncSession, target: a.AnnouncementTarget) -> str:
    """The server builds the route; no free text ever becomes a link (public-api "Routes and tags")."""
    if target.type == "none":
        return "/"
    if target.id is None:
        raise _no_id("target")
    if target.type == "match":
        if await session.get(Match, target.id) is None:
            raise EntityNotFound("match_not_found")
        return f"/match/{target.id}"
    if await session.get(Channel, target.id) is None:
        raise EntityNotFound("channel_not_found")
    return f"/channel/{target.id}"


async def _audience(session: AsyncSession, audience: a.AnnouncementAudience) -> dict[str, Any]:
    if audience.kind == "all":
        return {"kind": "all"}
    if audience.id is None:
        raise _no_id("audience")
    key = {
        "match": ("match_core", Match, "match_id", "match_not_found"),
        "team": ("team", Team, "team_id", "team_not_found"),
        "competition": ("competition", Competition, "competition_id", "competition_not_found"),
        "channel": ("channel", Channel, "channel_id", "channel_not_found"),
    }[audience.kind]
    kind, model, field, not_found = key
    if await session.get(model, audience.id) is None:
        raise EntityNotFound(not_found)
    return {"kind": kind, field: audience.id}


# --- Composer ---------------------------------------------------------------------------------------


async def create_announcement(
    session: AsyncSession, admin: AuthedAdmin, body: a.AnnouncementCreate, now: datetime
) -> NotificationOutbox:
    _screen(body.title, body.body)
    if body.send_at is not None and body.send_at <= now:
        raise ApiError(422, "send_at_in_past")
    route = await _route(session, body.target)
    audience = await _audience(session, body.audience)

    row = NotificationOutbox(
        type=ANNOUNCEMENT_TYPE,
        dedupe_key=f"announcement:{uuid.uuid4()}",
        payload={"title": body.title, "body": body.body, "route": route},
        audience=audience,
        due_at=body.send_at or now,
        status="pending",
    )
    session.add(row)
    await session.flush()
    audit = writer.add_audit(
        session,
        admin,
        "notification_outbox",
        row.id,
        "create",
        {"title": [None, body.title], "type": [None, ANNOUNCEMENT_TYPE], "audience": [None, audience["kind"]]},
    )
    await session.flush()
    # A17 shows the push behind the save, so the row carries the audit id (research R20).
    row.audit_log_id = audit.id
    await session.flush()
    return row


async def cancel(
    session: AsyncSession, admin: AuthedAdmin, notification_id: int, if_match: str | None, now: datetime
) -> NotificationOutbox:
    if if_match is None:
        from app.api.errors import precondition_required

        raise precondition_required()
    row = await writer.lock_row(session, NotificationOutbox, notification_id, "notification_not_found")
    current = versions.etag_of(versions.row_state(row))
    if not versions.matches_etag(if_match, current):
        from app.api.errors import edit_conflict

        raise edit_conflict(current, None, None)
    if row.status != "pending" or row.type != ANNOUNCEMENT_TYPE or (row.audience or {}).get("kind") == "device":
        raise ApiError(409, "notification_not_cancellable")
    row.status = "cancelled"
    row.error = "admin"
    writer.add_audit(session, admin, "notification_outbox", row.id, "update", {"status": ["pending", "cancelled"]})
    await writer.bump_datasets(session, ("outbox",))
    return row


async def test_send(
    session: AsyncSession, admin: AuthedAdmin, body: a.TestSendCreate, now: datetime
) -> NotificationOutbox:
    _screen(body.title, body.body)
    account = await session.get(AdminUser, admin.id)
    device_id = account.test_device_id if account is not None else None
    if device_id is None:
        raise ApiError(422, "test_device_not_set")
    device = await session.get(Device, device_id)
    if device is None or not (device.push_token or "").strip():
        raise ApiError(422, "test_device_no_token")

    route = await _route(session, body.target)
    row = NotificationOutbox(
        type=ANNOUNCEMENT_TYPE,
        dedupe_key=f"test:{uuid.uuid4()}",
        payload={"title": body.title, "body": body.body, "route": route},
        audience={"kind": "device", "device_id": device_id},
        due_at=now,
        status="pending",
    )
    session.add(row)
    await session.flush()
    audit = writer.add_audit(
        session,
        admin,
        "notification_outbox",
        row.id,
        "create",
        {"type": [None, ANNOUNCEMENT_TYPE], "test": [None, True]},
    )
    await session.flush()
    row.audit_log_id = audit.id
    await session.flush()
    return row


# --- The test device --------------------------------------------------------------------------------


def test_device_version(account: AdminUser) -> str:
    """Only the saved device id is hashed, so a login doesn't make an open A15 stale (admin-api)."""
    return versions.etag_of({"test_device_id": account.test_device_id})


async def test_device(session: AsyncSession, admin: AuthedAdmin) -> a.TestDeviceRow | None:
    account = await session.get(AdminUser, admin.id)
    if account is None or account.test_device_id is None:
        return None
    device = await session.get(Device, account.test_device_id)
    if device is None:
        return None
    return a.TestDeviceRow(
        device_id=device.id,
        platform=device.platform,
        app_version=device.app_version,
        has_push_token=bool((device.push_token or "").strip()),
    )


async def set_test_device(
    session: AsyncSession, admin: AuthedAdmin, device_id: int, if_match: str | None, now: datetime
) -> tuple[AdminUser, str]:
    """``PUT``: ``428`` without ``If-Match``, ``409 edit_conflict`` when stale (constitution VI)."""
    from app.api.errors import edit_conflict, precondition_required

    if if_match is None:
        raise precondition_required()
    account = await session.get(AdminUser, admin.id, with_for_update=True, populate_existing=True)
    if account is None:
        raise EntityNotFound("admin_user_not_found")
    current = test_device_version(account)
    if not versions.matches_etag(if_match, current):
        raise edit_conflict(current, None, None)
    if await session.get(Device, device_id) is None:
        raise EntityNotFound("device_not_found")

    if account.test_device_id != device_id:
        before = account.test_device_id
        account.test_device_id = device_id
        writer.add_audit(session, admin, "admin_users", account.id, "update", {"test_device_id": [before, device_id]})
        await writer.bump_datasets(session, ("admin_users",))
        await writer.flush(session)
    return account, test_device_version(account)
