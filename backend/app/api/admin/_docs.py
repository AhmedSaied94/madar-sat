"""Named OpenAPI examples for the admin routes (Prism serves them to Lane A; contract tests validate them).

Sample data is invented: Arabic team and channel names, no real person's data.
"""

from __future__ import annotations

from typing import Any

GENERATED_AT = "2026-10-30T14:00:00Z"
SAMPLE_ETAG = "3f9a0c1d5b7e2a64c8d01f93be5a7d20"


def ok_value(data: Any, meta: dict[str, Any] | None = None) -> dict[str, Any]:
    return {"success": True, "data": data, "error": None, "meta": {"generated_at": GENERATED_AT, **(meta or {})}}


def error_value(code: str, meta: dict[str, Any] | None = None) -> dict[str, Any]:
    return {
        "success": False,
        "data": None,
        "error": {"code": code, "message": code.replace("_", " ")},
        "meta": meta or {},
    }


def example(**named: dict[str, Any]) -> dict[str, Any]:
    """``{"content": {"application/json": {"examples": {name: {"value": …}}}}}`` for a response."""
    return {"content": {"application/json": {"examples": {name: {"value": value} for name, value in named.items()}}}}


def ok_example(name: str, data: Any, meta: dict[str, Any] | None = None) -> dict[str, Any]:
    """A named success example. Orval builds each MSW handler from these, so every success response has one."""
    return example(**{name: ok_value(data, meta)})


LIST_META: dict[str, Any] = {"count": 1}
PAGE_META: dict[str, Any] = {"count": 1, "next_cursor": None}


def error_response(description: str, **named: dict[str, Any]) -> dict[str, Any]:
    return {"description": description, **example(**named)}


# --- Shared error responses ------------------------------------------------------------------------

UNAUTHENTICATED = error_response(
    "No bearer token, a bad one, or an expired one",
    unauthenticated=error_value("unauthenticated"),
    token_expired=error_value("token_expired"),
)
FORBIDDEN = error_response(
    "The role is below the route's requirement", forbidden=error_value("forbidden", {"required_role": "admin"})
)
VALIDATION = error_response(
    "Validation error",
    validation_error=error_value(
        "validation_error", {"errors": [{"loc": ["body", "stadium"], "type": "string_too_long"}]}
    ),
)
PRECONDITION_REQUIRED = error_response(
    "`If-Match` is missing", precondition_required=error_value("precondition_required")
)
ALREADY_EXISTS = error_response("A unique rule fails", already_exists=error_value("already_exists", {"field": "slug"}))
IN_USE = error_response(
    "Something still references the entity",
    in_use=error_value("in_use", {"usage": {"matches": 12, "follows": 0}}),
)
NOT_MODIFIED = {"description": "The list hasn't changed since `If-None-Match`; no body"}

AUTHED: dict[int | str, dict[str, Any]] = {401: UNAUTHENTICATED, 403: FORBIDDEN}


def not_found(code: str) -> dict[str, Any]:
    return error_response("Unknown id", **{code: error_value(code)})


EDIT_CONFLICT = error_response(
    "`If-Match` is stale: someone else changed the entity",
    edit_conflict=error_value(
        "edit_conflict",
        {
            "current_etag": f'"{SAMPLE_ETAG}"',
            "changed_by": {"kind": "admin", "name": "سارة"},
            "changed_at": "2026-10-30T13:58:41Z",
        },
    ),
    edit_conflict_source=error_value(
        "edit_conflict",
        {
            "current_etag": f'"{SAMPLE_ETAG}"',
            "changed_by": {"kind": "source", "name": "ysscores"},
            "changed_at": "2026-10-30T13:00:12Z",
        },
    ),
)

# --- Matches -----------------------------------------------------------------------------------------

_SAT = {"id": 2, "name_ar": "نايل سات", "name_en": "Nilesat 7.0W", "orbital_position": -7.0}

MATCH_OK = ok_value(
    {
        "id": 48213,
        "sport": "football",
        "match_date": "2026-10-31",
        "kickoff_at": "2026-10-31T18:00:00Z",
        "time_tbd": False,
        "competition_id": 12,
        "competition_name": "الدوري المصري الممتاز",
        "competition_stage": "الجولة 9",
        "home": {
            "team_id": 101,
            "name": "الأهلي",
            "logo_asset_id": None,
            "logo": "https://media.example/logo/ab/ab12.webp",
        },
        "away": {"team_id": 102, "name": "الزمالك", "logo_asset_id": None, "logo": None},
        "stadium": "استاد القاهرة",
        "commentator_id": None,
        "status": {
            "status": "scheduled",
            "status_source": "clock",
            "estimated": False,
            "period": None,
            "minute": None,
            "score": None,
            "status_label": None,
            "status_updated_at": None,
        },
        "broadcasts": [
            {
                "slot": 1,
                "label": "ON Sport 1",
                "logo_asset_id": 88,
                "logo": "https://media.example/logo/cd/cd34.webp",
                "commentator_id": 7,
            }
        ],
        "channels": [
            {
                "channel_id": 5512,
                "name": "beIN SPORTS 1 HD",
                "display_name": "beIN SPORTS 1",
                "kind": "satellite",
                "satellite": _SAT,
                "frequency": {"mhz": 11843, "pol": "H", "sr": 27500},
                "access": "encrypted",
                "category": "sports",
                "logo": None,
                "source": "legacy",
                "imported_by": "legacy",
                "is_hidden": False,
                "hidden_by_name": False,
                "commentator_id": 7,
                "commentator2_id": None,
            }
        ],
        "locked_fields": ["kickoff_at"],
        "external_ids": [
            {"source": "ysscores", "external_id": "123456", "url": "https://www.ysscores.com/ar/match/123456/example"}
        ],
        "source": "ysscores",
        "last_change": {"kind": "admin", "name": "سارة", "at": "2026-10-30T14:02:11Z"},
    }
)

FORBIDDEN_REMOVE_CHANNELS = error_response(
    "The role is below the route's requirement (`remove_channels` needs `admin`)",
    forbidden_remove_channels=error_value("forbidden", {"required_role": "admin"}),
)
VALIDATION_STATUS = error_response(
    "Validation error",
    validation_error_status=error_value(
        "validation_error", {"errors": [{"loc": ["body", "status", "set", "score"], "type": "not_allowed"}]}
    ),
)
MATCH_PRECONDITION_REQUIRED = PRECONDITION_REQUIRED

# --- Media -------------------------------------------------------------------------------------------

MEDIA_OK = ok_value(
    {
        "id": 88,
        "kind": "image",
        "url": "https://media.example/logo/cd/cd34.webp",
        "width": 256,
        "height": 256,
        "duration_ms": None,
        "bytes": 18432,
    }
)
FILE_TOO_LARGE = error_response(
    "The upload is over its cap", file_too_large=error_value("file_too_large", {"max_bytes": 2097152})
)
UNSUPPORTED_MEDIA_TYPE = error_response(
    "The file's magic bytes aren't an allowed type for `kind`",
    unsupported_media_type=error_value("unsupported_media_type"),
)
MEDIA_INVALID = error_response("The file won't decode", media_invalid=error_value("media_invalid"))


def merged(description: str, *responses: dict[str, Any]) -> dict[str, Any]:
    """One response entry that carries the named examples of several (a status can mean more than one code)."""
    examples: dict[str, Any] = {}
    for response in responses:
        examples.update(response["content"]["application/json"]["examples"])
    return {"description": description, "content": {"application/json": {"examples": examples}}}


CONFLICT_OR_EXISTS = merged("`If-Match` is stale, or a unique rule fails", EDIT_CONFLICT, ALREADY_EXISTS)
IN_USE_OR_CONFLICT = merged("Something still references the entity, or `If-Match` is stale", IN_USE, EDIT_CONFLICT)
