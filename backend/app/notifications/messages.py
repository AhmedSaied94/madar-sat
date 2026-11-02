"""The kickoff reminder's copy and FCM fields (research R8).

Built at send time from the match, its visible links and the device's satellites, so a channel that
arrived in the last hour is named and a device that changed satellites is worded for its dish. Pure:
no database, no clock beyond the ``now`` it is given.
"""

from __future__ import annotations

from dataclasses import dataclass
from datetime import datetime

from app.domain.ranking import DEFAULT_SATELLITE_SLUGS, preferred_carriage_key

FSI = "\u2068"  # FIRST STRONG ISOLATE
PDI = "\u2069"  # POP DIRECTIONAL ISOLATE
TAG_PREFIX = "match_"
CHANNEL_ID = "reminders"
ICON = "ic_stat_madar"


def isolate(name: str) -> str:
    """Wrap a name in FSI…PDI so a Latin island stays intact inside an RTL sentence."""
    return f"{FSI}{name}{PDI}"


def minutes_phrase(minutes: int) -> str:
    """Arabic number agreement: دقيقة، دقيقتين، دقائق."""
    if minutes == 1:
        return "دقيقة"
    if minutes == 2:
        return "دقيقتين"
    if 3 <= minutes <= 10:
        return "دقائق"
    return "دقيقة"


@dataclass(frozen=True)
class MatchView:
    id: int
    kickoff_at: datetime
    home_name: str
    away_name: str


@dataclass(frozen=True)
class VisibleLink:
    """One visible link on the match, flattened for the choice and the copy."""

    channel_id: int
    name: str
    access: str | None
    sort_order: int | None
    show_in_match: bool
    satellite_id: int | None = None
    satellite_slug: str | None = None
    satellite_name: str | None = None


@dataclass(frozen=True)
class PushMessage:
    """What a sender needs: one device's title, body, data and platform fields."""

    token: str
    title: str
    body: str
    data: dict[str, str]
    tag: str
    link: str | None


def choose_channel(links: list[VisibleLink], my_satellite_ids: tuple[int, ...] = ()) -> VisibleLink | None:
    """The device's satellites first, else Nilesat + Badr by slug, else any visible link; free first."""
    if not links:
        return None
    if my_satellite_ids:
        mine = frozenset(my_satellite_ids)
        on_mine = [link for link in links if link.satellite_id in mine]
        if on_mine:
            return min(on_mine, key=_key)
    on_default = [link for link in links if link.satellite_slug in DEFAULT_SATELLITE_SLUGS]
    if on_default:
        return min(on_default, key=_key)
    return min(links, key=_key)


def _key(link: VisibleLink) -> tuple[bool, bool, int, int]:
    return preferred_carriage_key(link.access, link.sort_order, link.channel_id)


def build_message(
    match: MatchView,
    links: list[VisibleLink],
    device_satellite_ids: tuple[int, ...],
    pwa_origin: str | None,
    now: datetime,
) -> PushMessage:
    """One device's reminder: title, body, ``data`` and the collapsing tag/link.

    The caller cancels a row whose kickoff has passed (``dispatcher._cancelled``), so a lead in the
    past is a bug here, never a message: rounding it up to «بعد دقيقة» would tell followers that a
    match already in play starts in a minute (B1-R1-5).
    """
    lead_seconds = (match.kickoff_at - now).total_seconds()
    if lead_seconds <= 0:
        raise ValueError("a reminder for a kickoff that has passed must be cancelled, not built")
    minutes = max(int(round(lead_seconds / 60)), 1)
    channel = choose_channel(links, device_satellite_ids)
    # Arabic keeps the dual and the singular unnumbered: «بعد دقيقتين», «بعد دقيقة».
    when = minutes_phrase(minutes) if minutes in (1, 2) else f"{minutes} {minutes_phrase(minutes)}"
    title = f"{isolate(match.home_name)} × {isolate(match.away_name)} بعد {when}"

    if channel is None:
        body = "اضغط لعرض القنوات والترددات"
    elif channel.satellite_name:
        body = f"على {isolate(channel.name)} · {isolate(channel.satellite_name)} — اضغط لعرض القنوات والترددات"
    else:
        body = f"على {isolate(channel.name)} — اضغط لعرض القنوات والترددات"

    tag = f"{TAG_PREFIX}{match.id}"
    link = f"{pwa_origin.rstrip('/')}/match/{match.id}" if pwa_origin else None
    return PushMessage(
        token="",
        title=title,
        body=body,
        data={"type": "kickoff_reminder", "match_id": str(match.id), "route": f"/match/{match.id}"},
        tag=tag,
        link=link,
    )
