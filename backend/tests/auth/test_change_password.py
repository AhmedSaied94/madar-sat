"""POST /admin/api/auth/change-password and the forced-change flag (T008, research R19)."""

from __future__ import annotations

import logging

import pytest
from sqlalchemy import select

from app.auth.tokens import issue_refresh_token
from app.db.models import DatasetVersion

CHANGE = "/admin/api/auth/change-password"
EMAIL = "flagged@example.com"
NEW_PASSWORD = "a brand new passphrase"


@pytest.fixture
async def flagged(session, admin_password_hash):
    from app.db.models import AdminUser

    admin = AdminUser(
        email=EMAIL, name="محرر", role="editor", password_hash=admin_password_hash, must_change_password=True
    )
    session.add(admin)
    await session.flush()
    return admin


@pytest.fixture
async def flagged_client(client_at, flagged, frozen_now, redis_client):
    from tests.conftest import bearer

    async with client_at(("10.8.0.1", 5000), headers=bearer(flagged, frozen_now)) as client:
        client.admin = flagged
        yield client


async def _post(client, current: str, new: str):
    return await client.post(CHANGE, json={"current_password": current, "new_password": new})


async def test_a_flagged_account_is_refused_everywhere_but_the_exempt_routes(
    flagged_client, editor_client, admin_password
):
    refused = await flagged_client.get("/admin/api/channels")
    assert refused.status_code == 403
    assert refused.json()["error"]["code"] == "password_change_required"

    me = await flagged_client.get("/admin/api/auth/me")
    assert me.status_code == 200
    assert me.json()["data"]["must_change_password"] is True

    # A healthy account still reads the same routes.
    assert (await editor_client.get("/admin/api/channels")).status_code == 200

    # The change route itself is reachable while flagged.
    changed = await _post(flagged_client, admin_password, NEW_PASSWORD)
    assert changed.status_code == 200, changed.text


async def test_a_change_clears_the_flag_and_keeps_the_session_that_made_it(
    flagged_client, flagged, session, redis_client, admin_password, frozen_now
):
    keep_raw, keep_row = await issue_refresh_token(session, flagged.id, frozen_now)
    other_raw, other_row = await issue_refresh_token(session, flagged.id, frozen_now)
    flagged_client.cookies.set("madar_refresh", keep_raw)

    versions_before = await session.scalar(select(DatasetVersion.version).where(DatasetVersion.name == "admin_users"))

    resp = await _post(flagged_client, admin_password, NEW_PASSWORD)
    assert resp.status_code == 200
    body = resp.json()["data"]
    assert body["admin"]["must_change_password"] is False
    assert body["access_token"]

    await session.refresh(flagged)
    assert flagged.must_change_password is False
    await session.refresh(keep_row)
    await session.refresh(other_row)
    assert keep_row.revoked_at is None
    assert other_row.revoked_at is not None

    versions_after = await session.scalar(select(DatasetVersion.version).where(DatasetVersion.name == "admin_users"))
    assert versions_after == versions_before + 1

    # The new password works and the old one doesn't.
    assert (await _post(flagged_client, NEW_PASSWORD, "yet another passphrase")).status_code == 200


async def test_a_change_writes_one_audit_row_with_no_secret(
    flagged_client, flagged, session, redis_client, admin_password, caplog
):
    from app.db.models import AuditLog

    caplog.set_level(logging.DEBUG)
    resp = await _post(flagged_client, admin_password, NEW_PASSWORD)
    assert resp.status_code == 200

    rows = list(
        await session.scalars(
            select(AuditLog).where(AuditLog.entity == "admin_users", AuditLog.entity_id == flagged.id)
        )
    )
    assert [row.diff for row in rows] == [{"password": "changed"}]
    assert rows[0].admin_user_id == flagged.id

    haystack = resp.text + repr([row.diff for row in rows]) + caplog.text
    assert admin_password not in haystack
    assert NEW_PASSWORD not in haystack
    assert "argon2" not in haystack
    assert flagged.password_hash not in haystack


async def test_the_three_refusals(flagged_client, redis_client, admin_password):
    too_short = await _post(flagged_client, admin_password, "short")
    assert too_short.status_code == 422
    assert too_short.json()["error"]["code"] == "password_too_short"

    unchanged = await _post(flagged_client, admin_password, admin_password)
    assert unchanged.status_code == 422
    assert unchanged.json()["error"]["code"] == "password_unchanged"

    wrong = await _post(flagged_client, "not the password", NEW_PASSWORD)
    assert wrong.status_code == 401
    assert wrong.json()["error"]["code"] == "invalid_credentials"
    assert wrong.json()["meta"]["attempts_remaining"] == 4


async def test_five_wrong_current_passwords_lock_the_account(flagged_client, redis_client, flagged, admin_password):
    for _ in range(5):
        resp = await _post(flagged_client, "not the password", NEW_PASSWORD)
        assert resp.status_code == 401

    locked = await _post(flagged_client, admin_password, NEW_PASSWORD)
    assert locked.status_code == 429
    assert locked.json()["meta"]["retry_after_s"] >= 1

    from app.auth.limits import LoginLimiter

    ttl = await redis_client.ttl(LoginLimiter.account_lock_key(EMAIL))
    assert ttl > 0


async def test_an_unflagged_account_may_change_its_password_too(editor_client, admin_password):
    resp = await _post(editor_client, admin_password, NEW_PASSWORD)
    assert resp.status_code == 200
    assert resp.json()["data"]["admin"]["must_change_password"] is False


async def test_the_flag_survives_until_a_change_lands(flagged_client, flagged, session, admin_password):
    assert (await flagged_client.get("/admin/api/channels")).status_code == 403
    assert (await _post(flagged_client, admin_password, NEW_PASSWORD)).status_code == 200
    assert (await flagged_client.get("/admin/api/channels")).status_code == 200
