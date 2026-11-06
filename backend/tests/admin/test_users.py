"""A16: staff accounts — the list, create, edit, reset and their rules (T016)."""

from __future__ import annotations

import logging
import secrets
from datetime import timedelta
from uuid import uuid4

import pytest
from sqlalchemy import select

from app.auth.passwords import verify_password
from app.db.models import AdminRefreshToken, AdminUser
from app.services.admin import versions
from tests.admin.helpers import ADMIN, audit_rows, dataset_versions, if_match
from tests.conftest import ADMIN_PASSWORD

USERS = f"{ADMIN}/users"


@pytest.fixture(scope="session", autouse=True)
def _users_router_on_the_admin_app():
    """T016's router is registered here because ``app/admin.py`` belongs to another task."""
    from app.admin import app
    from app.api.admin import users as users_api

    if not any(getattr(route, "path", None) == USERS for route in app.routes):
        app.include_router(users_api.router)


def account_version(user: AdminUser) -> str:
    """The ``If-Match`` a client sends: the account row's own version, as ``lock_and_check`` computes it."""
    return versions.etag_of(versions.row_state(user))


async def new_refresh_token(session, admin_id: int, frozen_now) -> AdminRefreshToken:
    token = AdminRefreshToken(
        admin_user_id=admin_id,
        token_hash=secrets.token_hex(32),
        family_id=uuid4(),
        expires_at=frozen_now + timedelta(days=7),
    )
    session.add(token)
    await session.flush()
    return token


async def test_the_list_shows_every_account_with_its_lock_and_flag(
    admin_client, session, redis_client, frozen_now, make_admin
):
    from app.auth.limits import LoginLimiter

    other = await make_admin("locked@example.com", "مقفل", "editor")
    other.must_change_password = True
    other.last_login_at = frozen_now
    await session.flush()
    await redis_client.set(LoginLimiter.account_lock_key(other.email), "1", ex=660)

    response = await admin_client.get(USERS)

    assert response.status_code == 200, response.text
    assert response.headers["etag"]
    rows = {row["email"]: row for row in response.json()["data"]}
    assert set(rows) == {"boss@example.com", "locked@example.com"}
    assert rows["locked@example.com"]["locked_for_s"] == 660
    assert rows["locked@example.com"]["must_change_password"] is True
    assert rows["locked@example.com"]["last_login_at"].startswith("2026-10-28T18:00:00")
    assert rows["boss@example.com"]["locked_for_s"] is None
    assert rows["boss@example.com"]["must_change_password"] is False


async def test_creating_an_account_returns_a_temporary_password_once(admin_client, session, caplog):
    caplog.set_level(logging.DEBUG)
    before = await dataset_versions(session)

    response = await admin_client.post(
        USERS, json={"email": "New.Editor@Example.com", "name": "محرر جديد", "role": "editor"}
    )

    assert response.status_code == 201, response.text
    assert response.headers["cache-control"] == "no-store"
    assert response.headers["etag"]
    data = response.json()["data"]
    password = data["temporary_password"]
    assert len(password) >= 12
    assert data["user"]["email"] == "new.editor@example.com"
    assert data["user"]["role"] == "editor"
    assert data["user"]["is_active"] is True
    assert data["user"]["must_change_password"] is False
    assert data["user"]["locked_for_s"] is None

    user = await session.scalar(select(AdminUser).where(AdminUser.id == data["user"]["id"]))
    assert user.password_hash.startswith("$argon2id$")
    assert verify_password(user.password_hash, password).ok

    assert (await dataset_versions(session))["admin_users"] == before["admin_users"] + 1
    [created] = await audit_rows(session, "admin_users", user.id)
    assert created.action == "create"
    assert created.admin_user_id == admin_client.admin.id
    assert created.diff == {
        "email": [None, "new.editor@example.com"],
        "name": [None, "محرر جديد"],
        "role": [None, "editor"],
        "is_active": [None, True],
    }
    assert "password_hash" not in str(created.diff)
    assert password not in str(created.diff)

    listed = await admin_client.get(USERS)
    assert password not in listed.text
    assert "password_hash" not in listed.text
    assert password not in caplog.text
    assert "password_hash" not in caplog.text


async def test_a_duplicate_email_is_409_email_taken(admin_client, make_admin):
    await make_admin("taken@example.com", "مأخوذ", "editor")

    response = await admin_client.post(USERS, json={"email": "TAKEN@example.com", "name": "آخر", "role": "admin"})

    assert response.status_code == 409
    assert response.json()["error"]["code"] == "email_taken"


async def test_patching_an_account_changes_the_allowlist_and_audits_it(admin_client, session, make_admin):
    target = await make_admin("target@example.com", "هدف", "editor")
    before = account_version(target)

    response = await admin_client.patch(
        f"{USERS}/{target.id}", json={"name": "اسم جديد", "role": "admin"}, headers=if_match(before)
    )

    assert response.status_code == 200, response.text
    assert response.headers["etag"] != before
    assert response.json()["data"]["name"] == "اسم جديد"
    assert response.json()["data"]["role"] == "admin"
    [updated] = await audit_rows(session, "admin_users", target.id)
    assert updated.action == "update"
    assert updated.diff == {"name": ["هدف", "اسم جديد"], "role": ["editor", "admin"]}
    assert "password_hash" not in str(updated.diff)

    # A PATCH that changes nothing writes nothing and keeps the version.
    again = await admin_client.patch(
        f"{USERS}/{target.id}", json={"name": "اسم جديد"}, headers=if_match(response.headers["etag"])
    )
    assert again.status_code == 200
    assert again.headers["etag"] == response.headers["etag"]
    assert len(await audit_rows(session, "admin_users", target.id)) == 1


async def test_a_missing_or_stale_if_match_is_refused(admin_client, make_admin):
    target = await make_admin("conflict@example.com", "تعارض", "editor")

    assert (await admin_client.patch(f"{USERS}/{target.id}", json={"name": "x"})).status_code == 428
    stale = await admin_client.patch(f"{USERS}/{target.id}", json={"name": "x"}, headers=if_match('"deadbeef"'))
    assert stale.status_code == 409
    assert stale.json()["error"]["code"] == "edit_conflict"

    missing = await admin_client.patch(f"{USERS}/999999", json={"name": "x"}, headers=if_match('"x"'))
    assert missing.status_code == 404
    assert missing.json()["error"]["code"] == "admin_user_not_found"

    # A null in a field an account can't clear is a 422, checked after the version (as channels do).
    null_name = await admin_client.patch(
        f"{USERS}/{target.id}", json={"name": None}, headers=if_match(account_version(target))
    )
    assert null_name.status_code == 422
    assert null_name.json()["meta"]["errors"] == [{"loc": ["body", "name"], "type": "null_not_allowed"}]

    blank_name = await admin_client.patch(
        f"{USERS}/{target.id}", json={"name": "   "}, headers=if_match(account_version(target))
    )
    assert blank_name.status_code == 422
    assert blank_name.json()["meta"]["errors"] == [{"loc": ["body", "name"], "type": "empty"}]


async def test_the_last_active_admin_cannot_be_deactivated_or_demoted(admin_client):
    boss = admin_client.admin
    etag = account_version(boss)

    deactivate = await admin_client.patch(f"{USERS}/{boss.id}", json={"is_active": False}, headers=if_match(etag))
    assert deactivate.status_code == 409
    assert deactivate.json()["error"]["code"] == "last_admin"

    demote = await admin_client.patch(f"{USERS}/{boss.id}", json={"role": "editor"}, headers=if_match(etag))
    assert demote.status_code == 409
    assert demote.json()["error"]["code"] == "last_admin"


async def test_you_cannot_deactivate_or_demote_yourself(admin_client, make_admin):
    await make_admin("second@example.com", "ثانٍ", "admin")
    boss = admin_client.admin
    etag = account_version(boss)

    for body in ({"is_active": False}, {"role": "editor"}):
        response = await admin_client.patch(f"{USERS}/{boss.id}", json=body, headers=if_match(etag))
        assert response.status_code == 409
        assert response.json()["error"]["code"] == "cannot_change_self"


async def test_deactivating_an_account_revokes_every_refresh_token(admin_client, session, make_admin, frozen_now):
    target = await make_admin("leaver@example.com", "مغادر", "editor")
    token = await new_refresh_token(session, target.id, frozen_now)

    response = await admin_client.patch(
        f"{USERS}/{target.id}", json={"is_active": False}, headers=if_match(account_version(target))
    )

    assert response.status_code == 200, response.text
    assert response.json()["data"]["is_active"] is False
    await session.refresh(token)
    assert token.revoked_at is not None
    [updated] = await audit_rows(session, "admin_users", target.id)
    assert updated.diff == {"is_active": [True, False]}

    # Reactivating is allowed and needs a new login, which the revocation above forces anyway.
    back = await admin_client.patch(
        f"{USERS}/{target.id}", json={"is_active": True}, headers=if_match(response.headers["etag"])
    )
    assert back.status_code == 200
    assert back.json()["data"]["is_active"] is True


async def test_reset_password_returns_a_temporary_password_and_revokes_sessions(
    admin_client, session, make_admin, frozen_now, caplog
):
    caplog.set_level(logging.DEBUG)
    target = await make_admin("reset@example.com", "إعادة", "editor")
    token = await new_refresh_token(session, target.id, frozen_now)
    old_hash = target.password_hash

    response = await admin_client.post(f"{USERS}/{target.id}/reset-password", headers=if_match(account_version(target)))

    assert response.status_code == 200, response.text
    assert response.headers["cache-control"] == "no-store"
    data = response.json()["data"]
    password = data["temporary_password"]
    assert len(password) >= 12
    assert data["user"]["must_change_password"] is True

    await session.refresh(target)
    assert target.password_hash != old_hash
    assert verify_password(target.password_hash, password).ok
    assert not verify_password(target.password_hash, ADMIN_PASSWORD).ok
    await session.refresh(token)
    assert token.revoked_at is not None

    [reset] = await audit_rows(session, "admin_users", target.id)
    assert reset.diff == {"password": "changed"}
    assert "password_hash" not in response.text
    assert password not in caplog.text
    assert "password_hash" not in caplog.text


async def test_a_reset_needs_if_match(admin_client, make_admin):
    target = await make_admin("reset2@example.com", "إعادة", "editor")

    assert (await admin_client.post(f"{USERS}/{target.id}/reset-password")).status_code == 428


async def test_an_editor_may_not_read_or_write_accounts(editor_client, make_admin):
    target = await make_admin("someone@example.com", "شخص", "editor")
    headers = if_match('"whatever"')

    assert (await editor_client.get(USERS)).status_code == 403
    created = await editor_client.post(USERS, json={"email": "x@example.com", "name": "س", "role": "editor"})
    assert created.status_code == 403
    assert created.json()["meta"]["required_role"] == "admin"
    assert (await editor_client.patch(f"{USERS}/{target.id}", json={"name": "x"}, headers=headers)).status_code == 403
    reset = await editor_client.post(f"{USERS}/{target.id}/reset-password", headers=headers)
    assert reset.status_code == 403
