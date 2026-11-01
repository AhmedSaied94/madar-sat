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
