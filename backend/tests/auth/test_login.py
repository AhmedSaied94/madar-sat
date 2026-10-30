"""POST /admin/api/auth/login against the frozen D1 contract (research R3, T017, SC-003)."""

from __future__ import annotations

import hashlib

import pytest

LOGIN = "/admin/api/auth/login"
EMAIL = "editor@example.com"


def _key_hash(email: str) -> str:
    return hashlib.sha256(email.lower().encode()).hexdigest()[:32]


async def _login(client, email: str, password: str):
    return await client.post(LOGIN, json={"email": email, "password": password})


async def _keys(redis_client, pattern: str) -> list[str]:
    return sorted([key.decode() async for key in redis_client.scan_iter(match=pattern)])


@pytest.fixture
async def editor(make_admin):
    return await make_admin(EMAIL, "محرر", "editor")


async def test_a_good_login_returns_the_session_and_sets_both_cookies(
    anon_admin_client, redis_client, editor, admin_password
):
    resp = await _login(anon_admin_client, EMAIL, admin_password)

    assert resp.status_code == 200
    body = resp.json()
    assert body["success"] is True
    assert body["data"]["token_type"] == "Bearer"
    assert body["data"]["expires_in"] == 900
    assert body["data"]["access_token"]
    assert body["data"]["admin"] == {"id": editor.id, "email": EMAIL, "name": "محرر", "role": "editor"}

    cookies = {c.split("=", 1)[0]: c for c in resp.headers.get_list("set-cookie")}
    assert set(cookies) == {"madar_refresh", "madar_csrf"}
    refresh = cookies["madar_refresh"]
    assert "HttpOnly" in refresh and "Secure" in refresh and "SameSite=strict" in refresh.replace("Strict", "strict")
    assert "Path=/admin/api/auth" in refresh and "Max-Age=1209600" in refresh
    csrf = cookies["madar_csrf"]
    assert "HttpOnly" not in csrf  # readable by the admin app's JS
    assert "Secure" in csrf and "Path=/;" in csrf + ";" and "Max-Age=1209600" in csrf


async def test_the_access_token_is_never_set_as_a_cookie_or_header(
    anon_admin_client, redis_client, editor, admin_password
):
    resp = await _login(anon_admin_client, EMAIL, admin_password)

    token = resp.json()["data"]["access_token"]
    assert token not in "".join(resp.headers.get_list("set-cookie"))


async def test_wrong_passwords_count_attempts_remaining_down_to_zero(anon_admin_client, redis_client, editor):
    remaining = []
    for _ in range(5):
        resp = await _login(anon_admin_client, EMAIL, "wrong wrong wrong")
        assert resp.status_code == 401
        assert resp.json()["error"]["code"] == "invalid_credentials"
        remaining.append(resp.json()["meta"]["attempts_remaining"])

    assert remaining == [4, 3, 2, 1, 0]


async def test_the_sixth_attempt_is_locked_with_the_locks_ttl(anon_admin_client, redis_client, editor, admin_password):
    for _ in range(5):
        await _login(anon_admin_client, EMAIL, "wrong wrong wrong")

    resp = await _login(anon_admin_client, EMAIL, admin_password)  # even the right password is refused

    assert resp.status_code == 429
    assert resp.json()["error"]["code"] == "account_locked"
    (lock_key,) = await _keys(redis_client, "auth:lock:*")
    ttl = await redis_client.ttl(lock_key)
    assert 0 < ttl <= 900
    assert abs(resp.json()["meta"]["retry_after_s"] - ttl) <= 1
    assert int(resp.headers["retry-after"]) == resp.json()["meta"]["retry_after_s"]


async def test_registered_and_unregistered_emails_get_identical_responses(anon_admin_client, redis_client, editor):
    def normalised(resp):
        body = resp.json()
        body.get("meta", {}).pop("retry_after_s", None)
        return resp.status_code, body

    for email in (EMAIL, "ghost@example.com"):
        seen = []
        for _ in range(7):
            seen.append(normalised(await _login(anon_admin_client, email, "wrong wrong wrong")))
        if email == EMAIL:
            registered = seen
        else:
            unregistered = seen

    assert registered == unregistered  # 401 ×5 with attempts_remaining 4…0, then 429 ×2 (SC-003)
    assert [status for status, _ in registered] == [401] * 5 + [429] * 2


async def test_an_unknown_email_still_runs_a_verification_against_the_dummy_hash(
    anon_admin_client, redis_client, monkeypatch
):
    from app.auth import passwords

    calls = []
    real = passwords.burn_verify
    monkeypatch.setattr(passwords, "burn_verify", lambda password: (calls.append(password), real(password))[1])

    resp = await _login(anon_admin_client, "ghost@example.com", "wrong wrong wrong")

    assert resp.status_code == 401
    assert calls == ["wrong wrong wrong"]


async def test_a_deactivated_admin_gets_invalid_credentials(
    anon_admin_client, redis_client, make_admin, admin_password
):
    await make_admin("gone@example.com", "سابق", "editor", is_active=False)

    resp = await _login(anon_admin_client, "gone@example.com", admin_password)

    assert resp.status_code == 401
    assert resp.json()["error"]["code"] == "invalid_credentials"


async def test_a_success_clears_the_failure_and_lock_keys(anon_admin_client, redis_client, editor, admin_password):
    for _ in range(3):
        await _login(anon_admin_client, EMAIL, "wrong wrong wrong")
    assert await _keys(redis_client, "auth:fail:*")

    assert (await _login(anon_admin_client, EMAIL, admin_password)).status_code == 200

    assert await _keys(redis_client, "auth:*") == []


async def test_keys_hold_the_email_hash_and_ip_never_the_email(anon_admin_client, redis_client, editor):
    for _ in range(5):
        await _login(anon_admin_client, EMAIL, "wrong wrong wrong")

    fail_keys = await _keys(redis_client, "auth:fail:*")
    lock_keys = await _keys(redis_client, "auth:lock:*")

    assert fail_keys == [f"auth:fail:{_key_hash(EMAIL)}:127.0.0.1"]
    assert lock_keys == [f"auth:lock:{_key_hash(EMAIL)}:127.0.0.1"]
    assert not any("editor" in key or "example.com" in key for key in fail_keys + lock_keys)


async def test_email_case_does_not_dodge_the_limit(anon_admin_client, redis_client, editor):
    for email in (EMAIL, EMAIL.upper(), "Editor@Example.com", EMAIL, EMAIL.upper()):
        await _login(anon_admin_client, email, "wrong wrong wrong")

    assert (await _login(anon_admin_client, EMAIL, "wrong wrong wrong")).status_code == 429


async def test_attempts_from_another_ip_do_not_lock_this_one(client_at, redis_client, editor):
    async with client_at(("198.51.100.7", 1)) as other:
        for _ in range(5):
            await _login(other, EMAIL, "wrong wrong wrong")
        assert (await _login(other, EMAIL, "wrong wrong wrong")).status_code == 429
    async with client_at(("198.51.100.8", 1)) as elsewhere:
        assert (await _login(elsewhere, EMAIL, "wrong wrong wrong")).status_code == 401


async def test_x_forwarded_for_is_honoured_only_from_the_proxy(client_at, redis_client, editor):
    forwarded = {"X-Forwarded-For": "203.0.113.9"}
    async with client_at(("10.8.0.1", 5000)) as via_proxy:
        await via_proxy.post(LOGIN, json={"email": EMAIL, "password": "wrong wrong wrong"}, headers=forwarded)
    async with client_at(("192.0.2.50", 5000)) as direct:
        await direct.post(LOGIN, json={"email": EMAIL, "password": "wrong wrong wrong"}, headers=forwarded)

    assert await _keys(redis_client, "auth:fail:*") == [
        f"auth:fail:{_key_hash(EMAIL)}:192.0.2.50",  # a spoofed header from anyone else is ignored
        f"auth:fail:{_key_hash(EMAIL)}:203.0.113.9",
    ]


async def test_the_last_login_time_is_recorded(
    anon_admin_client, redis_client, editor, admin_password, session, frozen_now
):
    await _login(anon_admin_client, EMAIL, admin_password)

    await session.refresh(editor)
    assert editor.last_login_at is not None


async def test_login_rehashes_a_weaker_stored_hash(
    anon_admin_client, redis_client, make_admin, session, admin_password
):
    from argon2 import PasswordHasher

    weak = PasswordHasher(time_cost=1, memory_cost=8, parallelism=1).hash(admin_password)
    admin = await make_admin("weak@example.com", "ضعيف", "editor", password_hash=weak)

    assert (await _login(anon_admin_client, "weak@example.com", admin_password)).status_code == 200

    await session.refresh(admin)
    assert admin.password_hash != weak
    assert "m=65536,t=3,p=4" in admin.password_hash


async def test_a_malformed_body_is_a_validation_error_and_counts_nothing(anon_admin_client, redis_client):
    resp = await anon_admin_client.post(LOGIN, json={"email": "not-an-email", "password": "x"})

    assert resp.status_code == 422
    assert resp.json()["error"]["code"] == "validation_error"
    assert await _keys(redis_client, "auth:*") == []
