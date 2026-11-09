"""``/admin/api/users``: A16's staff accounts (contracts/admin-api.md).

Admin role only. Every write bypasses the writer's generic state diff so ``password_hash`` never
reaches ``audit_log``; a response carrying a temporary password is ``Cache-Control: no-store`` and
still returns the account's new ``ETag`` (research R19).
"""

from __future__ import annotations

from typing import Annotated, Any

import redis.asyncio as aioredis
from fastapi import APIRouter, Depends, Response

from app.api.admin import _docs
from app.api.admin._common import ETAG_HEADER, Db, IdPath, IfMatch, set_etag
from app.api.deps import ETag
from app.api.envelope import Envelope, ok
from app.auth.limits import get_redis
from app.auth.roles import AuthedAdmin, require_admin
from app.schemas import admin as a
from app.schemas import admin_examples as ex
from app.services.admin import users as service

router = APIRouter(prefix="/admin/api/users", tags=["users"], dependencies=[Depends(require_admin)])

Admin = Annotated[AuthedAdmin, Depends(require_admin)]

_NOT_FOUND = _docs.not_found("admin_user_not_found")
# A body with a temporary password in it must never be stored by a browser or a proxy (R19).
_NO_STORE = {
    "Cache-Control": {"description": "`no-store`: the password must not be cached", "schema": {"type": "string"}}
}


def _with_no_store(response: dict[str, Any]) -> dict[str, Any]:
    """The ``201``/``200`` entry of a response that returns a temporary password."""
    headers = {**response.get("headers", {}), **_NO_STORE}
    return {**response, "headers": headers}


@router.get(
    "",
    response_model=Envelope[list[a.AdminUserRow]],
    responses={
        200: {
            "description": "Accounts, with the list's `ETag`",
            **ETAG_HEADER,
            **_docs.ok_example("users_ok", [ex.ADMIN_USER_ROW], _docs.LIST_META),
        },
        **_docs.AUTHED,
        304: _docs.NOT_MODIFIED,
    },
    summary="A16: every staff account, with its lock time and temporary-password flag",
    dependencies=[Depends(ETag("admin_users", ("admin_users",), bucket_s=30))],
)
async def list_users(session: Db, redis: aioredis.Redis = Depends(get_redis)) -> Envelope[list[a.AdminUserRow]]:
    return ok(await service.accounts(session, redis))


@router.post(
    "",
    status_code=201,
    response_model=Envelope[a.UserWithPassword],
    responses={
        201: _with_no_store(
            {
                "description": "Created; the temporary password is shown once (`no-store`)",
                **ETAG_HEADER,
                **_docs.ok_example("user_created", ex.USER_WITH_PASSWORD),
            }
        ),
        **_docs.AUTHED,
        409: _docs.error_response("The email is already used", email_taken=_docs.error_value("email_taken")),
        422: _docs.VALIDATION,
    },
    summary="A16: create an account; it gets a temporary password it must change at the first sign-in",
)
async def create_user(
    body: a.UserCreate, response: Response, session: Db, admin: Admin
) -> Envelope[a.UserWithPassword]:
    user, password = await service.create(session, admin, body)
    row = service.to_row(user, None)
    etag = service.version(user)
    await session.commit()
    set_etag(response, etag)
    response.headers["Cache-Control"] = "no-store"
    return ok(a.UserWithPassword(user=row, temporary_password=password))


@router.patch(
    "/{user_id}",
    response_model=Envelope[a.AdminUserRow],
    responses={
        200: {
            "description": "The saved account, with its new `ETag`",
            **ETAG_HEADER,
            **_docs.ok_example("user_ok", ex.ADMIN_USER_ROW),
        },
        **_docs.AUTHED,
        404: _NOT_FOUND,
        409: _docs.merged(
            "`If-Match` is stale, or the change is refused (`cannot_change_self`, `last_admin`)",
            _docs.EDIT_CONFLICT,
            _docs.error_response(
                "The change is refused",
                cannot_change_self=_docs.error_value("cannot_change_self"),
                last_admin=_docs.error_value("last_admin"),
            ),
        ),
        422: _docs.VALIDATION,
        428: _docs.PRECONDITION_REQUIRED,
    },
    summary="A16: rename, change the role or switch an account on/off",
)
async def patch_user(
    user_id: IdPath,
    body: a.UserPatch,
    response: Response,
    session: Db,
    admin: Admin,
    if_match: IfMatch = None,
) -> Envelope[a.AdminUserRow]:
    user = await service.update(session, admin, user_id, body, if_match)
    row = service.to_row(user, None)
    etag = service.version(user)
    await session.commit()
    set_etag(response, etag)
    return ok(row)


@router.post(
    "/{user_id}/reset-password",
    response_model=Envelope[a.UserWithPassword],
    responses={
        200: _with_no_store(
            {
                "description": "The account's new temporary password (`no-store`); every session is revoked",
                **ETAG_HEADER,
                **_docs.ok_example("user_reset", ex.USER_WITH_PASSWORD),
            }
        ),
        **_docs.AUTHED,
        404: _NOT_FOUND,
        409: _docs.EDIT_CONFLICT,
        428: _docs.PRECONDITION_REQUIRED,
    },
    summary="A16: reset an account's password; it must change it at the next sign-in",
)
async def reset_password(
    user_id: IdPath, response: Response, session: Db, admin: Admin, if_match: IfMatch = None
) -> Envelope[a.UserWithPassword]:
    user, password = await service.reset_password(session, admin, user_id, if_match)
    row = service.to_row(user, None)
    etag = service.version(user)
    await session.commit()
    set_etag(response, etag)
    response.headers["Cache-Control"] = "no-store"
    return ok(a.UserWithPassword(user=row, temporary_password=password))
