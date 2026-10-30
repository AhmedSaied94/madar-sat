"""Password hashing: argon2id with the RFC 9106 low-memory profile (research R1)."""

from __future__ import annotations

from dataclasses import dataclass

from argon2 import PasswordHasher
from argon2.exceptions import InvalidHashError, VerificationError, VerifyMismatchError
from argon2.profiles import RFC_9106_LOW_MEMORY

MIN_LENGTH = 12
MAX_LENGTH = 256

# t = 3, m = 64 MiB, p = 4. `check_needs_rehash` makes a later change of these numbers upgrade
# every hash silently, on the owner's next login.
_hasher = PasswordHasher.from_parameters(RFC_9106_LOW_MEMORY)


@dataclass(frozen=True)
class Verification:
    ok: bool
    new_hash: str | None = None  # set when the password is right and the stored hash is weaker than today's


def hash_password(password: str) -> str:
    return _hasher.hash(password)


def verify_password(password_hash: str, password: str) -> Verification:
    """Check ``password`` against a stored hash; a malformed hash is a failed login, never an error."""
    try:
        _hasher.verify(password_hash, password)
    except (VerifyMismatchError, VerificationError, InvalidHashError):
        return Verification(ok=False)
    rehash = hash_password(password) if _hasher.check_needs_rehash(password_hash) else None
    return Verification(ok=True, new_hash=rehash)


# A fixed hash of a random password nobody knows, made with the same parameters. Logins for an
# unknown or deactivated email verify against it, so the response time doesn't say which emails exist.
DUMMY_HASH = hash_password("dummy-password-nobody-can-guess-7f3a9c")


def burn_verify(password: str) -> None:
    """Spend the time of one verification and discard the result."""
    verify_password(DUMMY_HASH, password)
