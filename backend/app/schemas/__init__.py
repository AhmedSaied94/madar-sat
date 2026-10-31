"""Pydantic shapes for the public and admin APIs."""

from pydantic import AfterValidator

# PostgreSQL text can't hold a NUL, and asyncpg raises rather than answering with the API envelope,
# so every text input (body or query) is refused up front (B1-R1-2, FR-013).
NO_NUL_PATTERN = r"^[^\x00]*$"


def _reject_nul(value: str) -> str:
    if "\x00" in value:
        raise ValueError("NUL bytes are not allowed")
    return value


# The `/v1` query guards can't be a `pattern`: adding one to a request parameter is a breaking change
# against `contract-v1` for oasdiff (B1-R2-1). An `AfterValidator` puts no keyword in the published
# schema, so the same 422 comes from a guard the contract doesn't mention.
NoNul = AfterValidator(_reject_nul)

__all__ = ["NO_NUL_PATTERN", "NoNul"]
