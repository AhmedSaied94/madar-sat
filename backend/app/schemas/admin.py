"""Pydantic schemas for the admin auth API (D1 declaration).

Shapes match ``specs/001-d01-foundation/contracts/admin-auth-v1.md``. The routes are
``501 not_implemented`` on D1; these schemas fix the shapes for the tagged contract.
"""

from __future__ import annotations

from enum import StrEnum
from typing import Literal

from pydantic import BaseModel, ConfigDict, EmailStr, Field


class AdminRole(StrEnum):
    editor = "editor"
    admin = "admin"


class AdminUser(BaseModel):
    id: int
    email: EmailStr
    name: str
    role: AdminRole


class Session(BaseModel):
    model_config = ConfigDict(
        # Always in the response, so required in its schema despite the defaults.
        json_schema_serialization_defaults_required=True,
        json_schema_extra={
            "examples": [
                {
                    "access_token": "eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiIzIn0.signature",
                    "token_type": "Bearer",
                    "expires_in": 900,
                    "admin": {"id": 3, "email": "editor@example.com", "name": "محرر", "role": "editor"},
                }
            ]
        },
    )

    access_token: str
    token_type: Literal["Bearer"] = "Bearer"  # noqa: S105 - the OAuth token type, not a secret
    expires_in: int = 900
    admin: AdminUser


class LoginRequest(BaseModel):
    email: EmailStr = Field(max_length=254)
    password: str = Field(min_length=1, max_length=256)
