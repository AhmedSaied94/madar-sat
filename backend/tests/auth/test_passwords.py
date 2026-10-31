"""Password hashing: argon2id with the RFC 9106 low-memory profile and silent rehash (research R1, T016)."""

from __future__ import annotations

import re

from argon2 import PasswordHasher

from app.auth import passwords


def test_hash_is_argon2id_with_rfc_9106_low_memory_parameters():
    hashed = passwords.hash_password("correct horse battery")

    match = re.match(r"^\$argon2id\$v=19\$m=(\d+),t=(\d+),p=(\d+)\$", hashed)
    assert match, hashed
    assert tuple(int(g) for g in match.groups()) == (65536, 3, 4)  # m = 64 MiB, t = 3, p = 4


def test_hashes_of_one_password_differ_and_each_verifies(admin_password_hash):
    again = passwords.hash_password("correct horse battery")

    assert again != admin_password_hash  # a fresh salt each time
    assert passwords.verify_password(admin_password_hash, "correct horse battery").ok
    assert passwords.verify_password(again, "correct horse battery").ok


def test_a_wrong_password_does_not_verify(admin_password_hash):
    result = passwords.verify_password(admin_password_hash, "wrong horse battery")

    assert result.ok is False
    assert result.new_hash is None


def test_a_malformed_stored_hash_is_a_failed_login_not_an_error():
    assert passwords.verify_password("not-a-hash", "whatever password").ok is False


def test_current_parameters_need_no_rehash(admin_password_hash):
    assert passwords.verify_password(admin_password_hash, "correct horse battery").new_hash is None


def test_weaker_parameters_are_rehashed_silently_on_a_good_login():
    weak = PasswordHasher(time_cost=1, memory_cost=8, parallelism=1).hash("correct horse battery")

    result = passwords.verify_password(weak, "correct horse battery")

    assert result.ok is True
    assert result.new_hash is not None
    assert "m=65536,t=3,p=4" in result.new_hash
    assert passwords.verify_password(result.new_hash, "correct horse battery").ok


def test_a_weak_hash_is_not_rehashed_when_the_password_is_wrong():
    weak = PasswordHasher(time_cost=1, memory_cost=8, parallelism=1).hash("correct horse battery")

    assert passwords.verify_password(weak, "wrong horse battery").new_hash is None


def test_the_dummy_hash_uses_the_same_cost_so_unknown_emails_take_as_long():
    assert "m=65536,t=3,p=4" in passwords.DUMMY_HASH
    assert passwords.verify_password(passwords.DUMMY_HASH, "anything at all").ok is False
    passwords.burn_verify("anything at all")  # runs a verification and discards the result
