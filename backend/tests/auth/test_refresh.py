"""Refresh rotation, reuse detection, CSRF, logout and the access token (research R2, T018)."""

from __future__ import annotations

from datetime import timedelta
from http.cookies import SimpleCookie

import jwt
import pytest
from sqlalchemy import select, update

from app.db.models import AdminRefreshToken

BASE = "/admin/api/auth"
EMAIL = "editor@example.com"


def _cookies(resp) -> dict[str, str]:
    jar: SimpleCookie = SimpleCookie()
    for header in resp.headers.get_list("set-cookie"):
        jar.load(header)
    return {name: morsel.value for name, morsel in jar.items()}


def _set_cookie(resp, name: str) -> str:
    return next(h for h in resp.headers.get_list("set-cookie") if h.startswith(f"{name}="))


def _session_headers(cookies: dict[str, str], *, csrf: str | None = "") -> dict[str, str]:
    """The cookies the browser would send, plus the header the admin app echoes from ``madar_csrf``."""
    headers = {"Cookie": "; ".join(f"{name}={value}" for name, value in cookies.items())}
    if csrf is not None:
        headers["X-CSRF-Token"] = cookies["madar_csrf"] if csrf == "" else csrf
    return headers


@pytest.fixture
async def signed_in(anon_admin_client, redis_client, make_admin, admin_password):
    admin = await make_admin(EMAIL, "محرر", "editor")
    resp = await anon_admin_client.post(f"{BASE}/login", json={"email": EMAIL, "password": admin_password})
    assert resp.status_code == 200
    return admin, _cookies(resp), resp.json()["data"]


async def _rows(session, admin_id: int) -> list[AdminRefreshToken]:
    result = await session.scalars(
        select(AdminRefreshToken).where(AdminRefreshToken.admin_user_id == admin_id).order_by(AdminRefreshToken.id)
    )
    return list(result)


async def test_refresh_rotates_the_token_in_the_same_family_and_rotates_the_csrf_value(
    anon_admin_client, signed_in, session
):
    admin, cookies, _ = signed_in

    resp = await anon_admin_client.post(f"{BASE}/refresh", headers=_session_headers(cookies))

    assert resp.status_code == 200
    assert resp.json()["data"]["expires_in"] == 900
    fresh = _cookies(resp)
    assert fresh["madar_refresh"] != cookies["madar_refresh"]
    assert fresh["madar_csrf"] != cookies["madar_csrf"]
    old, new = await _rows(session, admin.id)
    assert old.revoked_at is not None
    assert old.replaced_by_id == new.id
    assert old.family_id == new.family_id
    assert new.revoked_at is None


async def test_the_refresh_token_is_stored_only_as_its_hash(signed_in, session):
    admin, cookies, _ = signed_in

    (row,) = await _rows(session, admin.id)

    assert row.token_hash != cookies["madar_refresh"]
    assert len(row.token_hash) == 64


async def test_a_rotated_token_cannot_be_used_again_and_the_family_dies(anon_admin_client, signed_in, session):
    admin, cookies, _ = signed_in
    first = await anon_admin_client.post(f"{BASE}/refresh", headers=_session_headers(cookies))
    newest = _cookies(first)

    replay = await anon_admin_client.post(f"{BASE}/refresh", headers=_session_headers(cookies))

    assert replay.status_code == 401
    assert replay.json()["error"]["code"] == "refresh_invalid"
    assert all(row.revoked_at is not None for row in await _rows(session, admin.id))
    after = await anon_admin_client.post(f"{BASE}/refresh", headers=_session_headers(newest))
    assert after.status_code == 401  # even the legitimate newest token is gone


async def test_a_token_revoked_by_logout_cannot_be_refreshed(anon_admin_client, signed_in):
    _, cookies, _ = signed_in
    assert (await anon_admin_client.post(f"{BASE}/logout", headers=_session_headers(cookies))).status_code == 200

    resp = await anon_admin_client.post(f"{BASE}/refresh", headers=_session_headers(cookies))

    assert resp.status_code == 401
    assert resp.json()["error"]["code"] == "refresh_invalid"


async def test_two_parallel_refreshes_rotate_once_and_the_second_revokes_the_family(
    parallel_admin_client, committed_editor, redis_client
):
    """The row lock is what makes this true: without ``FOR UPDATE`` both would rotate (B1-R1-9)."""
    import asyncio

    email, _ = committed_editor
    login = await parallel_admin_client.post(
        BASE + "/login", json={"email": email, "password": "correct horse battery"}
    )
    assert login.status_code == 200
    cookies = _cookies(login)
    headers = {"Cookie": "; ".join(f"{name}={value}" for name, value in cookies.items())}
    headers["X-CSRF-Token"] = cookies["madar_csrf"]

    first, second = await asyncio.gather(
        parallel_admin_client.post(f"{BASE}/refresh", headers=headers),
        parallel_admin_client.post(f"{BASE}/refresh", headers=headers),
    )

    assert sorted([first.status_code, second.status_code]) == [200, 401]
    refused = second if first.status_code == 200 else first
    assert refused.json()["error"]["code"] == "refresh_invalid"
    # The reuse rule killed the family, including the token the winner received.
    winner = _cookies(first if first.status_code == 200 else second)
    assert (await parallel_admin_client.post(f"{BASE}/refresh", headers=_session_headers(winner))).status_code == 401


@pytest.mark.parametrize("route", ["refresh", "logout"])
@pytest.mark.parametrize("csrf", [None, "not-the-cookie-value"])
async def test_a_missing_or_different_csrf_header_is_403_and_changes_nothing(
    anon_admin_client, signed_in, session, route, csrf
):
    admin, cookies, _ = signed_in

    resp = await anon_admin_client.post(f"{BASE}/{route}", headers=_session_headers(cookies, csrf=csrf))

    assert resp.status_code == 403
    assert resp.json()["error"]["code"] == "csrf_failed"
    (row,) = await _rows(session, admin.id)
    assert row.revoked_at is None


@pytest.mark.parametrize("route", ["refresh", "logout"])
async def test_no_csrf_cookie_at_all_is_403(anon_admin_client, signed_in, route):
    _, cookies, _ = signed_in
    only_refresh = {"madar_refresh": cookies["madar_refresh"]}

    resp = await anon_admin_client.post(
        f"{BASE}/{route}", headers={**_session_headers(only_refresh, csrf=None), "X-CSRF-Token": "anything"}
    )

    assert resp.status_code == 403


async def test_logout_revokes_the_token_and_clears_both_cookies(anon_admin_client, signed_in, session):
    admin, cookies, _ = signed_in

    resp = await anon_admin_client.post(f"{BASE}/logout", headers=_session_headers(cookies))

    assert resp.status_code == 200
    assert resp.json()["data"] is None
    for name in ("madar_refresh", "madar_csrf"):
        assert "Max-Age=0" in _set_cookie(resp, name)
    (row,) = await _rows(session, admin.id)
    assert row.revoked_at is not None


async def test_a_deactivated_admin_cannot_refresh(anon_admin_client, signed_in, session):
    admin, cookies, _ = signed_in
    admin.is_active = False
    await session.flush()

    resp = await anon_admin_client.post(f"{BASE}/refresh", headers=_session_headers(cookies))

    assert resp.status_code == 401
    assert resp.json()["error"]["code"] == "refresh_invalid"


async def test_an_expired_refresh_token_is_refused(anon_admin_client, signed_in, session, frozen_now):
    admin, cookies, _ = signed_in
    await session.execute(
        update(AdminRefreshToken)
        .where(AdminRefreshToken.admin_user_id == admin.id)
        .values(expires_at=frozen_now - timedelta(seconds=1))
    )

    resp = await anon_admin_client.post(f"{BASE}/refresh", headers=_session_headers(cookies))

    assert resp.status_code == 401
    assert resp.json()["error"]["code"] == "refresh_invalid"


async def test_a_refresh_token_lives_fourteen_days(signed_in, session, frozen_now):
    admin, _, _ = signed_in

    (row,) = await _rows(session, admin.id)

    assert row.expires_at == frozen_now + timedelta(days=14)


async def test_refresh_without_the_cookie_is_refresh_invalid(anon_admin_client, signed_in):
    _, cookies, _ = signed_in

    resp = await anon_admin_client.post(
        f"{BASE}/refresh", headers=_session_headers({"madar_csrf": cookies["madar_csrf"]})
    )

    assert resp.status_code == 401
    assert resp.json()["error"]["code"] == "refresh_invalid"


# --- The access token ------------------------------------------------------------------------------


async def test_me_returns_the_signed_in_admin(anon_admin_client, signed_in):
    admin, _, session_data = signed_in

    resp = await anon_admin_client.get(
        f"{BASE}/me", headers={"Authorization": f"Bearer {session_data['access_token']}"}
    )

    assert resp.status_code == 200
    assert resp.json()["data"] == {"id": admin.id, "email": EMAIL, "name": "محرر", "role": "editor"}


async def test_the_access_token_carries_sub_role_iat_and_a_fifteen_minute_exp(signed_in, frozen_now):
    admin, _, session_data = signed_in

    claims = jwt.decode(
        session_data["access_token"],
        options={"verify_signature": False, "verify_exp": False, "verify_iat": False},
        algorithms=["HS256"],
    )

    assert claims["sub"] == str(admin.id)
    assert claims["role"] == "editor"
    assert claims["iat"] == int(frozen_now.timestamp())
    assert claims["exp"] - claims["iat"] == 900


async def test_an_access_token_older_than_fifteen_minutes_is_token_expired(anon_admin_client, signed_in, frozen_now):
    from app.auth.tokens import issue_access_token

    admin, _, _ = signed_in
    stale = issue_access_token(admin.id, admin.role, frozen_now - timedelta(minutes=15, seconds=1))

    resp = await anon_admin_client.get(f"{BASE}/me", headers={"Authorization": f"Bearer {stale}"})

    assert resp.status_code == 401
    assert resp.json()["error"]["code"] == "token_expired"


async def test_an_access_token_at_fourteen_minutes_still_works(anon_admin_client, signed_in, frozen_now):
    from app.auth.tokens import issue_access_token

    admin, _, _ = signed_in
    token = issue_access_token(admin.id, admin.role, frozen_now - timedelta(minutes=14, seconds=59))

    resp = await anon_admin_client.get(f"{BASE}/me", headers={"Authorization": f"Bearer {token}"})

    assert resp.status_code == 200


@pytest.mark.parametrize("header", [None, "Bearer garbage", "Basic abc", "Bearer ", "Bearer a.b.c"])
async def test_no_token_or_a_malformed_one_is_unauthenticated(anon_admin_client, header):
    headers = {} if header is None else {"Authorization": header}

    resp = await anon_admin_client.get(f"{BASE}/me", headers=headers)

    assert resp.status_code == 401
    assert resp.json()["error"]["code"] == "unauthenticated"


async def test_a_bad_signature_is_unauthenticated(anon_admin_client, signed_in, frozen_now):
    admin, _, _ = signed_in
    now = int(frozen_now.timestamp())
    forged = jwt.encode(
        {"sub": str(admin.id), "role": "admin", "iat": now, "exp": now + 900},
        "an-attackers-own-secret-0123456789abcdef",
        algorithm="HS256",
    )

    resp = await anon_admin_client.get(f"{BASE}/me", headers={"Authorization": f"Bearer {forged}"})

    assert resp.status_code == 401
    assert resp.json()["error"]["code"] == "unauthenticated"


async def test_the_none_algorithm_is_refused(anon_admin_client, signed_in, frozen_now):
    admin, _, _ = signed_in
    now = int(frozen_now.timestamp())
    unsigned = jwt.encode({"sub": str(admin.id), "role": "admin", "iat": now, "exp": now + 900}, None, algorithm="none")

    resp = await anon_admin_client.get(f"{BASE}/me", headers={"Authorization": f"Bearer {unsigned}"})

    assert resp.status_code == 401


async def test_the_role_comes_from_the_database_not_the_token(anon_admin_client, signed_in, session, frozen_now):
    from app.auth.tokens import issue_access_token

    admin, _, _ = signed_in
    token = issue_access_token(admin.id, "admin", frozen_now)  # the token claims admin; the account is an editor

    resp = await anon_admin_client.get(f"{BASE}/me", headers={"Authorization": f"Bearer {token}"})

    assert resp.json()["data"]["role"] == "editor"


async def test_a_deactivated_admins_access_token_stops_working_at_once(anon_admin_client, signed_in, session):
    admin, _, session_data = signed_in
    admin.is_active = False
    await session.flush()

    resp = await anon_admin_client.get(
        f"{BASE}/me", headers={"Authorization": f"Bearer {session_data['access_token']}"}
    )

    assert resp.status_code == 401
    assert resp.json()["error"]["code"] == "unauthenticated"
