"""Schema-level examples for the admin response models.

Orval builds each MSW handler's data from a model's ``examples`` when it has one. Without them it
falls back to ``faker.number.int({min: undefined, …})``, which fails the admin app's strict
``exactOptionalPropertyTypes`` typecheck. FastAPI drops ``null`` values from schema examples, so
these fill every field with a value; the named response examples (``app.api.admin._docs``) keep
the nulls. Data is invented: Arabic names, no real person's data.
"""

from __future__ import annotations

from typing import Any

LOGO = "https://media.example/logo/ab/ab12cd.webp"
FREQUENCY: dict[str, Any] = {"mhz": 11843, "pol": "H", "sr": 27500}
SCORE: dict[str, Any] = {"home": 1, "away": 0, "home_pen": 3, "away_pen": 2}
COMPETITION_REF: dict[str, Any] = {
    "id": 12,
    "name": "الدوري المصري الممتاز",
    "logo": LOGO,
    "stage": "الجولة 9",
    "priority": 3,
}
SATELLITE_REF: dict[str, Any] = {"id": 2, "name_ar": "نايل سات", "name_en": "Nilesat 7.0W", "orbital_position": -7.0}

MATCH_ROW: dict[str, Any] = {
    "id": 48213,
    "match_date": "2026-10-31",
    "kickoff_at": "2026-10-31T18:00:00Z",
    "time_tbd": False,
    "status": "live",
    "estimated": False,
    "score": SCORE,
    "competition": COMPETITION_REF,
    "home": {"id": 101, "name": "الأهلي", "logo": LOGO},
    "away": {"id": 102, "name": "الزمالك", "logo": LOGO},
    "channel_count": 14,
    "broadcaster_count": 1,
    "missing_channels": False,
    "commentator": {"id": 7, "name": "معلق تجريبي"},
    "sources": ["ysscores", "legacy"],
    "locked": True,
    "etag": '"3f9a1c6d47b0e2a5c8d14f7b90e3a652"',
}

MATCH: dict[str, Any] = {
    "id": 48213,
    "sport": "football",
    "match_date": "2026-10-31",
    "kickoff_at": "2026-10-31T18:00:00Z",
    "time_tbd": False,
    "competition_id": 12,
    "competition_name": "الدوري المصري الممتاز",
    "competition_stage": "الجولة 9",
    "home": {"team_id": 101, "name": "الأهلي", "logo_asset_id": 12, "logo": LOGO},
    "away": {"team_id": 102, "name": "الزمالك", "logo_asset_id": 13, "logo": LOGO},
    "stadium": "استاد القاهرة",
    "commentator_id": 7,
    "status": {
        "status": "live",
        "status_source": "manual",
        "estimated": False,
        "period": "2H",
        "minute": "67",
        "score": SCORE,
        "status_label": "مباراة قوية",
        "status_updated_at": "2026-10-31T19:07:00Z",
    },
    "broadcasts": [{"slot": 1, "label": "ON Sport 1", "logo_asset_id": 88, "logo": LOGO, "commentator_id": 7}],
    "channels": [
        {
            "channel_id": 5512,
            "name": "beIN SPORTS 1 HD",
            "display_name": "beIN SPORTS 1",
            "kind": "satellite",
            "satellite": SATELLITE_REF,
            "frequency": FREQUENCY,
            "access": "encrypted",
            "category": "sports",
            "logo": LOGO,
            "source": "legacy",
            "imported_by": "legacy",
            "is_hidden": False,
            "hidden_by_name": False,
            "commentator_id": 7,
            "commentator2_id": 8,
        }
    ],
    "locked_fields": ["kickoff_at"],
    "external_ids": [
        {"source": "ysscores", "external_id": "123456", "url": "https://www.ysscores.com/ar/match/123456/example"}
    ],
    "source": "ysscores",
    "last_change": {"kind": "admin", "name": "سارة", "at": "2026-10-30T14:02:11Z"},
}

TEAM_ITEM: dict[str, Any] = {
    "id": 101,
    "name": "الأهلي",
    "country": "مصر",
    "logo": LOGO,
    "primary_competition": {"id": 12, "name": "الدوري المصري الممتاز"},
    "competitions": [{"id": 12, "name": "الدوري المصري الممتاز"}, {"id": 40, "name": "دوري أبطال أفريقيا"}],
}

TEAM: dict[str, Any] = {
    "id": 101,
    "sport": "football",
    "name": "الأهلي",
    "country": "مصر",
    "logo_asset_id": 12,
    "logo": LOGO,
    "stadium": "استاد القاهرة",
    "primary_competition_id": 12,
    "competition_ids": [12, 40],
    "external_ids": [{"source": "ysscores", "external_id": "77"}],
}

COMPETITION: dict[str, Any] = {
    "id": 12,
    "sport": "football",
    "name": "الدوري المصري الممتاز",
    "logo_asset_id": 3,
    "logo": LOGO,
    "priority": 3,
    "etag": '"7c1e5a09d3b84f26a0e9c5d71b3f8a42"',
}

SATELLITE: dict[str, Any] = {
    "id": 2,
    "slug": "nilesat-7-0w",
    "kind": "satellite",
    "name_en": "Nilesat 7.0W",
    "name_ar": "نايل سات",
    "orbital_position": -7.0,
    "logo_asset_id": 4,
    "logo": LOGO,
    "best_frequency": {"mhz": 11996, "pol": "V", "sr": 27500},
    "worst_frequency": FREQUENCY,
    "reception_url": "https://www.youtube.com/watch?v=example",
    "priority": 1,
    "etag": '"b25d8e41f07a39c6d1e4a8b03c97f512"',
}

CHANNEL_ITEM: dict[str, Any] = {
    "id": 5512,
    "kind": "satellite",
    "name": "beIN SPORTS 1 HD",
    "display_name": "beIN SPORTS 1",
    "logo_asset_id": 9,
    "logo": LOGO,
    "category": "sports",
    "country": "قطر",
    "satellite_id": 2,
    "frequency": FREQUENCY,
    "frequency_note": "تردد احتياطي",
    "access": "encrypted",
    "provider": "beIN",
    "package": "باقة الرياضة",
    "beam": "wide",
    "show_in_match": False,
    "sort_order": 14,
    "hidden_by_name": False,
    "placeholder_source": None,
}

CHANNEL: dict[str, Any] = {**CHANNEL_ITEM, "locked_fields": ["name"]}

COMMENTATOR: dict[str, Any] = {
    "id": 7,
    "name": "معلق تجريبي",
    "photo_asset_id": 31,
    "photo": LOGO,
    "audio_asset_id": 32,
    "audio": "https://media.example/audio/ef/ef56.mp4",
    "usage": {"matches": 120, "match_channels": 340},
}

BROADCAST_PRESET: dict[str, Any] = {"id": 1, "name": "ON Sport 1", "logo_asset_id": 88, "logo": LOGO}
HIDDEN_CHANNEL_NAME: dict[str, Any] = {"name": "قناة مخفية"}
UNRESOLVED_NAME: dict[str, Any] = {
    "id": 91,
    "source": "yallakora",
    "kind": "team",
    "name": "Al Ahli",
    "context": {
        "match_id": 48213,
        "home": "Al Ahli",
        "away": "الزمالك",
        "competition": "الدوري المصري الممتاز",
        "kickoff_at": "2026-11-04T18:00:00Z",
    },
    "seen_count": 4,
    "last_seen_at": "2026-11-04T16:30:00Z",
    "state": "open",
    "etag": '"3f9a0c1d5b7e2a64c8d01f93be5a7d20"',
    "suggestions": [{"id": 101, "name": "الأهلي", "detail": "الدوري المصري الممتاز", "confidence": 100, "exact": True}],
}
UNRESOLVED_MAP: dict[str, Any] = {"target_id": 101, "scope_to_competition": True, "created": False}

RIGHTS_HOLDER_BODY: dict[str, Any] = {
    "name": "Eleven Sports",
    "logo_asset_id": 77,
    "competition_ids": [12, 14],
    "carriages": [
        {
            "access": "encrypted",
            "beam": "wide",
            "package": "الباقة الرياضية",
            "satellite_ids": [2],
            "frequencies": [{"frequency_mhz": 11013, "polarization": "H", "symbol_rate": 27500, "is_primary": True}],
        }
    ],
}
RIGHTS_HOLDER: dict[str, Any] = {
    "id": 3,
    **RIGHTS_HOLDER_BODY,
    "logo": LOGO,
    "sort_order": 1,
    "etag": '"7c1e5a09d3b84f26a0e9c5d71b3f8a42"',
}
RIGHTS_HOLDER_ROW: dict[str, Any] = {
    "id": 3,
    "name": "Eleven Sports",
    "logo": LOGO,
    "sort_order": 1,
    "competitions": ["الدوري المصري الممتاز"],
    "satellites": ["نايل سات"],
    "etag": '"7c1e5a09d3b84f26a0e9c5d71b3f8a42"',
}

RAW_PAGE: dict[str, Any] = {
    "state": "ready",
    "page": 0,
    "pages": 3,
    "url": "https://www.filgoal.com/matches/",
    "content_type": "text/html",
    "text": "<!doctype html>",
    "truncated": False,
}

SOURCE: dict[str, Any] = {"name": "ysscores", "kind": "scraper", "is_enabled": True}

IMPORT_RUN_ROW: dict[str, Any] = {
    "id": 9123,
    "status": "succeeded",
    "started_at": "2026-11-01T07:58:00Z",
    "finished_at": "2026-11-01T08:00:41Z",
    "items_found": 64,
    "items_upserted": 12,
    "http_errors": 0,
    "error": None,
}

IMPORT_RUN_DETAIL: dict[str, Any] = {
    **IMPORT_RUN_ROW,
    "raw_path": "livesoccertv/2026-11-01/run.json",
    "log": {"unmatched_matches": [], "placeholders_created": [], "skipped_channels": 7, "errors": []},
    "log_available": True,
    "pages": 3,
    "worker": "worker-imports@vps2",
}

SOURCE_HEALTH: dict[str, Any] = {
    **SOURCE,
    "breaker": "closed",
    "breaker_opened_at": None,
    "consecutive_failures": 0,
    "paused": False,
    "last_success_at": "2026-11-01T08:00:41Z",
    "last_run": IMPORT_RUN_ROW,
    "items_24h": [41, 64, 58],
    "error_rate_24h": 0.25,
    "running": False,
    "live": {"matches_live": 6, "error_share": 0.01, "sources": [{"name": "filgoal", "state": "ok"}]},
}

DASHBOARD: dict[str, Any] = {
    "missing_channels": [
        {
            "competition": {"id": 12, "name": "الدوري المصري الممتاز", "priority": 3},
            "matches": [{"id": 48213, "kickoff_at": "2026-11-01T18:00:00Z", "home": "الأهلي", "away": "الزمالك"}],
        }
    ],
    "missing_channels_count": 9,
    "placeholders_to_complete": 14,
    "sources": [SOURCE_HEALTH],
    "recent_changes": [
        {
            "at": "2026-11-01T08:00:41Z",
            "by": {"kind": "admin", "name": "محرر"},
            "entity": "match",
            "entity_id": 48213,
            "action": "update",
        }
    ],
}
MEDIA_ASSET: dict[str, Any] = {
    "id": 88,
    "kind": "image",
    "url": LOGO,
    "width": 256,
    "height": 256,
    "duration_ms": 12000,
    "bytes": 18432,
}
BULK_RESULT: dict[str, Any] = {"updated": [{"id": 48213, "etag": '"3f9a0c1d5b7e2a64c8d01f93be5a7d20"'}]}

# --- D6: notifications, staff accounts, audit and channel history --------------------------------

NOTIFICATION_ROW: dict[str, Any] = {
    "id": 9012,
    "type": "goal",
    "status": "sent",
    "error": None,
    "target": {"kind": "match_core", "label": "الأهلي × الزمالك", "id": 48213},
    "is_test": False,
    "is_correction": False,
    "recipients": 2410,
    "sent": 2398,
    "failed": 12,
    "due_at": "2026-11-06T18:40:00Z",
    "sent_at": "2026-11-06T18:40:09Z",
    "created_at": "2026-11-06T18:40:00Z",
    "etag": '"5d0e8a3b71c94f26b0a1d7e3c94b2f18"',
}
NOTIFICATION_REACH: dict[str, Any] = {"devices": 41230}
ANNOUNCEMENT_BODY: dict[str, Any] = {
    "title": "مباراة الليلة",
    "body": "الأهلي × الزمالك في الثامنة مساءً",
    "target": {"type": "match", "id": 48213},
    "audience": {"kind": "all", "id": None},
    "send_at": None,
}
TEST_DEVICE: dict[str, Any] = {
    "device_id": 812,
    "platform": "android",
    "app_version": "0.6.0+60",
    "has_push_token": True,
}
ADMIN_USER_ROW: dict[str, Any] = {
    "id": 3,
    "email": "editor@example.com",
    "name": "محرر",
    "role": "editor",
    "is_active": True,
    "locked_for_s": 660,
    "last_login_at": "2026-11-06T09:12:00Z",
    "must_change_password": False,
    "etag": '"a41c7e09b3d25f86c1e0947d2b6a3f5e"',
}
USER_WITH_PASSWORD: dict[str, Any] = {
    "user": ADMIN_USER_ROW,
    "temporary_password": "a temporary passphrase",
}
AUDIT_ROW: dict[str, Any] = {
    "id": 7711,
    "created_at": "2026-11-06T17:00:00Z",
    "actor": {"kind": "admin", "id": 3, "name": "محرر"},
    "entity": "channel",
    "entity_id": 412,
    "action": "update",
    "summary_fields": ["frequency_mhz"],
    "has_notification": True,
}
AUDIT_DETAIL: dict[str, Any] = {
    **AUDIT_ROW,
    "diff": {"frequency_mhz": [11766, 11843]},
    "notification": {"id": 9012, "type": "frequency_changed", "status": "sent", "sent": 118, "failed": 0},
}
FREQUENCY_HISTORY_ROW: dict[str, Any] = {
    "id": 55,
    "old": "11766 H 27500",
    "new": "11843 H 27500",
    "source": "admin",
    "actor": "محرر",
    "detected_at": "2026-11-06T17:05:00Z",
}
