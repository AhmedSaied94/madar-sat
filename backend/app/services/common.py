"""Shared helpers for the read services: media URLs and channel visibility."""

from __future__ import annotations

from typing import Any

from sqlalchemy import Select, and_, func, select
from sqlalchemy.sql.elements import ColumnElement

from app.db.models import HiddenChannelName
from app.settings import get_settings


def media_url(path: str | None) -> str | None:
    """Build an absolute media URL, or ``None`` when no asset is set (FR-007)."""
    if not path:
        return None
    return f"{get_settings().media_base_url}/{path}"


def hidden_names() -> Select[tuple[str]]:
    return select(HiddenChannelName.name)


# A channel link is visible when it is not hidden on the match, the channel is not
# soft-deleted, it is not an importer's placeholder (research R13), and its name (or
# normalized display name) is not in hidden_channel_names. This mirrors research R6.
def visible_link(match_channel: Any, channel: Any, hidden: Any) -> ColumnElement[bool]:
    return and_(
        match_channel.is_hidden.is_(False),
        channel.deleted_at.is_(None),
        channel.placeholder_source.is_(None),
        channel.name_norm.not_in(hidden),
        func.ar_normalize(func.coalesce(channel.display_name, "")).not_in(hidden),
    )
