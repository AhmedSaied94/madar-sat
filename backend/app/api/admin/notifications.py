"""``/admin/api/notifications``: the outbox log, reach, the composer and the test device (contracts/admin-api.md)."""

from __future__ import annotations

from typing import Annotated

from fastapi import APIRouter, Depends, Query, Response

from app.api.admin import _docs
from app.api.admin._common import ETAG_HEADER, Db, Editor, IdPath, IfMatch, Now
from app.api.deps import ETag
from app.api.envelope import Envelope, ok
from app.api.errors import ApiError
from app.auth.roles import require_admin, require_editor
from app.schemas import admin as a
from app.schemas import admin_examples as ex
from app.services.admin import notifications as service

router = APIRouter(prefix="/admin/api/notifications", tags=["notifications"], dependencies=[Depends(require_editor)])

_LOG_ETAG = "admin_notifications"
_TEST_DEVICE_OK = _docs.ok_example("test_device_ok", ex.TEST_DEVICE)


def _kick_dispatch() -> None:
    """Admin saves due now queue the dispatcher, as a poll that wrote a row does (push-pipeline)."""
    from app.workers import app as celery_app

    celery_app.send_task("notifications.dispatch_due", queue="notifications")


@router.get(
    "",
    response_model=Envelope[list[a.NotificationRow]],
    responses={
        200: {
            "description": "The log, newest first, with its `ETag`",
            **ETAG_HEADER,
            **_docs.ok_example("notifications_ok", [ex.NOTIFICATION_ROW], _docs.PAGE_META),
        },
        **_docs.AUTHED,
        304: _docs.NOT_MODIFIED,
        422: _docs.VALIDATION,
    },
    summary="Read the outbox log",
    dependencies=[Depends(ETag(_LOG_ETAG, ("outbox",), bucket_s=service.BUCKET_S))],
)
async def list_notifications(
    session: Db,
    type: Annotated[str | None, Query(pattern="^[a-z_]{1,32}$")] = None,
    status: Annotated[str | None, Query(pattern="^[a-z]{1,16}$")] = None,
    cursor: Annotated[str | None, Query(max_length=200)] = None,
    limit: Annotated[int, Query(ge=1, le=100)] = 50,
) -> Envelope[list[a.NotificationRow]]:
    items, next_cursor = await service.list_log(session, row_type=type, status=status, cursor=cursor, limit=limit)
    return ok(items, {"next_cursor": next_cursor})


@router.get(
    "/reach",
    response_model=Envelope[a.NotificationReach],
    responses={
        200: {
            "description": "How many devices the audience reaches",
            **_docs.ok_example("reach_ok", ex.NOTIFICATION_REACH),
        },
        **_docs.AUTHED,
        422: _docs.VALIDATION,
    },
    summary="Count the devices an audience reaches",
    dependencies=[Depends(require_admin), Depends(ETag("admin_reach", ("outbox",), bucket_s=30))],
)
async def get_reach(
    session: Db,
    kind: Annotated[str, Query(pattern="^(all|team|competition|match|channel)$")] = "all",
    id: Annotated[int | None, Query(ge=1, le=2**63 - 1)] = None,
) -> Envelope[a.NotificationReach]:
    if kind != "all" and id is None:
        raise ApiError(422, "validation_error", meta={"errors": [{"loc": ["query", "id"], "type": "missing"}]})
    devices = await service.reach(session, kind=kind, target_id=id)
    return ok(a.NotificationReach(devices=devices))


@router.post(
    "/announcements",
    status_code=201,
    response_model=Envelope[a.NotificationRow],
    responses={
        201: {
            "description": "Queued; `due_at` is now or `send_at`",
            **ETAG_HEADER,
            **_docs.ok_example("notification_ok", ex.NOTIFICATION_ROW),
        },
        **_docs.AUTHED,
        404: _docs.not_found("match_not_found"),
        409: _docs.VALIDATION,
        422: _docs.VALIDATION,
    },
    summary="Compose an announcement or a scheduled notification",
    dependencies=[Depends(require_admin)],
)
async def create_announcement(
    body: a.AnnouncementCreate, response: Response, session: Db, admin: Editor, now: Now
) -> Envelope[a.NotificationRow]:
    row = await service.create_announcement(session, admin, body, now)
    await session.commit()
    if row.due_at <= now:
        _kick_dispatch()
    response.headers["ETag"] = service.row_version(row)
    return ok(await service.view(session, row))


@router.post(
    "/{notification_id}/cancel",
    response_model=Envelope[a.NotificationRow],
    responses={
        200: {"description": "Cancelled", **_docs.ok_example("notification_ok", ex.NOTIFICATION_ROW)},
        **_docs.AUTHED,
        404: _docs.not_found("notification_not_found"),
        409: _docs.EDIT_CONFLICT,
        428: _docs.PRECONDITION_REQUIRED,
    },
    summary="Cancel a pending announcement (`If-Match` required)",
    dependencies=[Depends(require_admin)],
)
async def cancel_notification(
    notification_id: IdPath, response: Response, session: Db, admin: Editor, now: Now, if_match: IfMatch = None
) -> Envelope[a.NotificationRow]:
    row = await service.cancel(session, admin, notification_id, if_match, now)
    await session.commit()
    response.headers["ETag"] = service.row_version(row)
    return ok(await service.view(session, row))


@router.post(
    "/test",
    status_code=201,
    response_model=Envelope[a.NotificationRow],
    responses={
        201: {
            "description": "Queued to the caller's test device",
            **_docs.ok_example("notification_ok", ex.NOTIFICATION_ROW),
        },
        **_docs.AUTHED,
        422: _docs.VALIDATION,
    },
    summary="Send a test notification to my saved device",
    dependencies=[Depends(require_admin)],
)
async def send_test(
    body: a.TestSendCreate, response: Response, session: Db, admin: Editor, now: Now
) -> Envelope[a.NotificationRow]:
    row = await service.test_send(session, admin, body, now)
    await session.commit()
    _kick_dispatch()
    response.headers["ETag"] = service.row_version(row)
    return ok(await service.view(session, row))


@router.get(
    "/test-device",
    response_model=Envelope[a.TestDeviceRow | None],
    responses={
        200: {"description": "My saved test device, or null", **ETAG_HEADER, **_TEST_DEVICE_OK},
        **_docs.AUTHED,
    },
    summary="My test device",
    dependencies=[Depends(require_admin)],
)
async def get_test_device(session: Db, admin: Editor, response: Response) -> Envelope[a.TestDeviceRow | None]:
    from app.db.models import AdminUser

    account = await session.get(AdminUser, admin.id)
    if account is None:
        raise ApiError(401, "unauthenticated")
    # Always sent, so an empty answer is still cacheable and a PUT has a tag to send (admin-api).
    response.headers["ETag"] = service.test_device_version(account)
    return ok(await service.test_device(session, admin))


@router.put(
    "/test-device",
    response_model=Envelope[a.TestDeviceRow | None],
    responses={
        200: {"description": "Saved", **ETAG_HEADER, **_TEST_DEVICE_OK},
        **_docs.AUTHED,
        404: _docs.not_found("device_not_found"),
        409: _docs.EDIT_CONFLICT,
        428: _docs.PRECONDITION_REQUIRED,
    },
    summary="Save my test device (`If-Match` required)",
    dependencies=[Depends(require_admin)],
)
async def put_test_device(
    body: a.TestDevicePatch, response: Response, session: Db, admin: Editor, now: Now, if_match: IfMatch = None
) -> Envelope[a.TestDeviceRow | None]:
    _, etag = await service.set_test_device(session, admin, body.device_id, if_match, now)
    await session.commit()
    response.headers["ETag"] = etag
    return ok(await service.test_device(session, admin))


__all__ = ["router"]
