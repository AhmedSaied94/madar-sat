"""The admin account CLI: create-admin, set-admin-password, deactivate-admin (research R1, T016)."""

from __future__ import annotations

import io
from contextlib import contextmanager
from datetime import UTC, datetime, timedelta

import pytest
from sqlalchemy import select, text

from app import cli
from app.auth.passwords import verify_password
from app.db.models import AdminRefreshToken, AdminUser, AuditLog

PASSWORD = "correct horse battery"
EMAIL = "new.editor@example.com"
BASE = ["create-admin", "--email", EMAIL, "--name", "محرر جديد", "--role", "editor"]


@pytest.fixture
def run(monkeypatch, sync_session):
    """``run(argv, *passwords)`` runs the CLI against the test transaction; ``passwords`` answer getpass."""

    @contextmanager
    def _session():
        yield sync_session

    monkeypatch.setattr(cli, "SyncSession", _session)

    def _run(argv: list[str], *typed: str, stdin: str | None = None) -> int:
        answers = iter(typed)
        monkeypatch.setattr(cli.getpass, "getpass", lambda prompt="": next(answers))
        if stdin is not None:
            monkeypatch.setattr("sys.stdin", io.StringIO(stdin))
        return cli.main(argv)

    return _run


def _admin(sync_session, email: str = EMAIL) -> AdminUser | None:
    return sync_session.scalar(select(AdminUser).where(text("lower(email) = :e")).params(e=email.lower()))


def _audit(sync_session, action: str) -> AuditLog:
    return sync_session.scalars(
        select(AuditLog).where(AuditLog.entity == "admin_users", AuditLog.action == action)
    ).one()


def test_create_admin_reads_the_password_twice_and_stores_only_its_hash(run, sync_session):
    assert run(BASE, PASSWORD, PASSWORD) == 0

    admin = _admin(sync_session)
    assert admin is not None
    assert (admin.name, admin.role, admin.is_active) == ("محرر جديد", "editor", True)
    assert admin.password_hash != PASSWORD
    assert verify_password(admin.password_hash, PASSWORD).ok


def test_create_admin_accepts_the_password_once_from_stdin(run, sync_session):
    assert run([*BASE, "--password-stdin"], stdin=f"{PASSWORD}\n") == 0

    admin = _admin(sync_session)
    assert admin is not None
    assert verify_password(admin.password_hash, PASSWORD).ok


def test_create_admin_writes_a_cli_audit_row_with_both_actor_columns_null(run, sync_session):
    run(BASE, PASSWORD, PASSWORD)

    row = _audit(sync_session, "create")
    assert (row.admin_user_id, row.source) == (None, None)
    assert row.entity_id == _admin(sync_session).id
    assert row.diff["email"] == [None, EMAIL]
    assert row.diff["role"] == [None, "editor"]


def test_the_password_and_its_hash_never_reach_stdout_stderr_or_the_audit_diff(run, sync_session, capsys):
    run(BASE, PASSWORD, PASSWORD)

    captured = capsys.readouterr()
    admin = _admin(sync_session)
    assert PASSWORD not in captured.out + captured.err
    assert admin.password_hash not in captured.out + captured.err
    diff = repr(_audit(sync_session, "create").diff)
    assert PASSWORD not in diff
    assert admin.password_hash not in diff
    assert "password" not in _audit(sync_session, "create").diff


def test_there_is_no_password_option(run, capsys):
    with pytest.raises(SystemExit) as exit_info:
        run([*BASE, "--password", PASSWORD])

    assert exit_info.value.code == 2
    assert PASSWORD not in capsys.readouterr().out


@pytest.mark.parametrize(
    ("typed", "reason"),
    [
        (("short pass", "short pass"), "too short"),
        (("x" * 257, "x" * 257), "too long"),
        ((PASSWORD, PASSWORD + "!"), "mismatch"),
    ],
)
def test_create_admin_refuses_a_bad_password(run, sync_session, capsys, typed, reason):
    assert run(BASE, *typed) != 0, reason

    assert _admin(sync_session) is None
    assert typed[0] not in capsys.readouterr().err


def test_create_admin_refuses_a_duplicate_email_in_any_case(run, sync_session):
    assert run(BASE, PASSWORD, PASSWORD) == 0

    again = ["create-admin", "--email", EMAIL.upper(), "--name", "آخر", "--role", "admin"]
    assert run(again, PASSWORD, PASSWORD) != 0
    assert sync_session.scalar(text("SELECT count(*) FROM admin_users WHERE lower(email) = :e"), {"e": EMAIL}) == 1


def test_create_admin_refuses_an_invalid_role_email_or_name(run, sync_session):
    with pytest.raises(SystemExit):
        run(["create-admin", "--email", EMAIL, "--name", "x", "--role", "owner"])
    assert run(["create-admin", "--email", "not-an-email", "--name", "x", "--role", "editor"], PASSWORD, PASSWORD) != 0
    assert run(["create-admin", "--email", EMAIL, "--name", "n" * 81, "--role", "editor"], PASSWORD, PASSWORD) != 0
    assert _admin(sync_session) is None


def test_set_admin_password_replaces_the_hash_and_ends_every_session(run, sync_session):
    run(BASE, PASSWORD, PASSWORD)
    admin = _admin(sync_session)
    _refresh_token(sync_session, admin.id, "a" * 64)

    new_password = "another long password"
    assert run(["set-admin-password", "--email", EMAIL], new_password, new_password) == 0

    sync_session.refresh(admin)
    assert verify_password(admin.password_hash, new_password).ok
    assert not verify_password(admin.password_hash, PASSWORD).ok
    assert _live_tokens(sync_session, admin.id) == 0
    audit = _audit(sync_session, "update")
    assert audit.diff == {"password": "changed"}
    assert (audit.admin_user_id, audit.source) == (None, None)


def test_set_admin_password_for_an_unknown_email_fails(run):
    assert run(["set-admin-password", "--email", "nobody@example.com"], PASSWORD, PASSWORD) != 0


def test_deactivate_admin_revokes_every_refresh_token(run, sync_session):
    run(BASE, PASSWORD, PASSWORD)
    admin = _admin(sync_session)
    _refresh_token(sync_session, admin.id, "b" * 64)
    _refresh_token(sync_session, admin.id, "c" * 64)
    assert _live_tokens(sync_session, admin.id) == 2

    assert run(["deactivate-admin", "--email", EMAIL]) == 0

    sync_session.refresh(admin)
    assert admin.is_active is False
    assert _live_tokens(sync_session, admin.id) == 0
    assert _audit(sync_session, "update").diff == {"is_active": [True, False]}


def test_deactivate_admin_for_an_unknown_email_fails(run):
    assert run(["deactivate-admin", "--email", "nobody@example.com"]) != 0


def _refresh_token(sync_session, admin_id: int, token_hash: str) -> None:
    sync_session.execute(
        text(
            "INSERT INTO admin_refresh_tokens (admin_user_id, token_hash, family_id, expires_at) "
            "VALUES (:a, :h, gen_random_uuid(), :exp)"
        ),
        {"a": admin_id, "h": token_hash, "exp": datetime.now(UTC) + timedelta(days=14)},
    )
    sync_session.flush()


def _live_tokens(sync_session, admin_id: int) -> int:
    return len(
        sync_session.scalars(
            select(AdminRefreshToken).where(
                AdminRefreshToken.admin_user_id == admin_id, AdminRefreshToken.revoked_at.is_(None)
            )
        ).all()
    )
