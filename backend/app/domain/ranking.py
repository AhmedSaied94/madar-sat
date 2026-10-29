"""Headline ranking for the match-row channel line (research R2) and the preferred
carriages of match detail (research R6).

``broadcast.headline`` holds at most two visible channels, ranked: on the user's
satellites (or the filter satellites) first, else the default satellites or
``show_in_match``, then free before encrypted, then ``sort_order``, then ``id``.
"""

from __future__ import annotations

from dataclasses import dataclass

DEFAULT_SATELLITE_SLUGS = ("nilesat-7-0w", "badr-26-0e")
MAX_HEADLINE = 2


def is_preferred_carriage(kind: str, satellite_slug: str | None, show_in_match: bool) -> bool:
    """A satellite or terrestrial link on a default satellite, or flagged ``show_in_match``."""
    return kind in ("satellite", "terrestrial") and (satellite_slug in DEFAULT_SATELLITE_SLUGS or show_in_match)


def preferred_carriage_key(access: str | None, sort_order: int | None, channel_id: int) -> tuple[bool, bool, int, int]:
    """Sort key for preferred carriages: free first, then ``sort_order`` (nulls last), then id."""
    return (access != "free", sort_order is None, sort_order if sort_order is not None else 0, channel_id)


@dataclass(frozen=True)
class HeadlineCandidate:
    channel_id: int
    name: str
    access: str | None  # "free" | "encrypted" | None (platform with unknown access)
    satellite_id: int | None = None
    satellite_slug: str | None = None
    sort_order: int | None = None
    show_in_match: bool = False
    is_hidden: bool = False
    deleted: bool = False


def headline(
    candidates: list[HeadlineCandidate],
    my_satellite_ids: tuple[int, ...] = (),
    filter_satellite_ids: tuple[int, ...] = (),
) -> list[HeadlineCandidate]:
    """Return the top ≤ 2 visible candidates, ranked for the match row."""
    visible = [c for c in candidates if not c.is_hidden and not c.deleted]
    if not visible:
        return []

    if my_satellite_ids:
        priority_ids = frozenset(my_satellite_ids)
        priority_slugs: frozenset[str] = frozenset()
        use_show_in_match = False
    elif filter_satellite_ids:
        priority_ids = frozenset(filter_satellite_ids)
        priority_slugs = frozenset()
        use_show_in_match = False
    else:
        priority_ids = frozenset()
        priority_slugs = frozenset(DEFAULT_SATELLITE_SLUGS)
        use_show_in_match = True

    def key(c: HeadlineCandidate) -> tuple[bool, bool, bool, int, int]:
        on_priority = (
            c.satellite_id in priority_ids
            or c.satellite_slug in priority_slugs
            or (use_show_in_match and c.show_in_match)
        )
        free = c.access == "free"
        sort_order = c.sort_order
        return (
            not on_priority,
            not free,
            sort_order is None,
            sort_order if sort_order is not None else 0,
            c.channel_id,
        )

    return sorted(visible, key=key)[:MAX_HEADLINE]
