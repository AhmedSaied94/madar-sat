"""Columns a human edit protects from importers (``locked_fields``, 001 data-model).

The database CHECKs ``ck_matches_locked_fields`` and ``ck_channels_locked_fields`` allow exactly
these names; importers skip a field that is locked on the row they update (research R18).
"""

from __future__ import annotations

MATCH_LOCKABLE = frozenset(
    {
        "kickoff_at",
        "competition_id",
        "competition_name",
        "competition_stage",
        "home_team_id",
        "home_team_name",
        "home_logo_asset_id",
        "away_team_id",
        "away_team_name",
        "away_logo_asset_id",
        "stadium",
        "commentator_id",
        "status",
        "home_score",
        "away_score",
        "home_pen",
        "away_pen",
        "local_broadcaster_eg",
    }
)

CHANNEL_LOCKABLE = frozenset(
    {
        "name",
        "display_name",
        "logo_asset_id",
        "category",
        "country",
        "satellite_id",
        "frequency_mhz",
        "polarization",
        "symbol_rate",
        "frequency_note",
        "access",
        "provider",
        "package",
        "beam",
        "show_in_match",
        "sort_order",
    }
)

# The status and score columns a manual status sets, and a cleared one gives back to the clock.
STATUS_COLUMNS = frozenset({"status", "home_score", "away_score", "home_pen", "away_pen"})
