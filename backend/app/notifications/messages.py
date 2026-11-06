"""Copy and FCM fields for every push type (research R8, D6 contracts/push-pipeline.md "Copy").

Built at send time from the match, its visible links and the device's satellites, so a channel that
arrived in the last hour is named and a device that changed satellites is worded for its dish. Pure:
no database, no clock beyond the ``now`` it is given. Every name, score digit, minute and readout is
wrapped by :func:`isolate`, and a score is never one isolated string: it sits beside its team in an
RTL line (FR-018).
"""

from __future__ import annotations

import re
from collections.abc import Sequence
from dataclasses import dataclass
from datetime import datetime

from app.domain.ranking import DEFAULT_SATELLITE_SLUGS, preferred_carriage_key
from app.live.types import GOAL_TYPES

FSI = "\u2068"  # FIRST STRONG ISOLATE
PDI = "\u2069"  # POP DIRECTIONAL ISOLATE
TAG_PREFIX = "match_"
CHANNEL_TAG_PREFIX = "channel_"
ANNOUNCEMENT_TAG_PREFIX = "announcement_"
CHANNEL_ID = "reminders"
ICON = "ic_stat_madar"
SCORE_DASH = " – "  # en dash, with the spaces the catalog draws around it
SEPARATOR = " · "

_MINUTE = re.compile(r"^(\d{1,3})(?:\+(\d{1,2}))?$")


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
class ChannelView:
    """A channel and the satellite its readout sits on, flattened for the frequency copy."""

    id: int
    name: str
    satellite_name: str | None = None


@dataclass(frozen=True)
class FrequencyReadout:
    """A complete tuning, shaped like ``11843 H 27500`` (``app.domain.frequency``)."""

    mhz: int
    polarization: str
    symbol_rate: int

    @property
    def text(self) -> str:
        return f"{self.mhz} {self.polarization} {self.symbol_rate}"


@dataclass(frozen=True)
class GoalEvent:
    """One stored event a goal's scorer may come from (FR-006). ``side`` is the credited team."""

    type: str
    side: str
    minute: str
    player: str | None = None


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


def score_line(match: MatchView, home: int, away: int) -> str:
    """``home 1 – 0 away`` with every part isolated: a score never stands alone in an RTL line."""
    return f"{isolate(match.home_name)} {isolate(str(home))}{SCORE_DASH}{isolate(str(away))} {isolate(match.away_name)}"


def choose_scorer(events: Sequence[GoalEvent], side: str, score: int) -> GoalEvent | None:
    """The last goal-type event on ``side`` by minute, only when their count adds up (FR-006, PB §11).

    "Adds up" means the count equals the side's score in the message: with two known goals and a 3–0
    score, the missing one is unknown, so no scorer is named and nothing is invented. A shoot-out kick
    isn't a goal event, and an own goal's side is already the team it credited.
    """
    goals = [event for event in events if event.type in GOAL_TYPES and event.side == side]
    if len(goals) != score:
        return None
    last: GoalEvent | None = None
    for event in goals:
        if last is None or _minute_key(event.minute) >= _minute_key(last.minute):
            last = event
    return last if last is not None and last.player else None


def build_match_started(match: MatchView, pwa_origin: str | None = None) -> PushMessage:
    route = _match_route(match)
    return _match_message(
        match,
        "match_started",
        route,
        "بدأت المباراة",
        f"{isolate(match.home_name)} × {isolate(match.away_name)}",
        pwa_origin,
    )


def build_goal(
    match: MatchView,
    home: int,
    away: int,
    side: str,
    events: Sequence[GoalEvent] = (),
    pwa_origin: str | None = None,
) -> PushMessage:
    """«هدف لـ ‹team›!» over the score, with «· ‹player› 23′» only when the events add up."""
    if side not in ("home", "away"):
        raise ValueError(f"a goal's side is home or away, not {side!r}")
    team = match.home_name if side == "home" else match.away_name
    body = score_line(match, home, away)
    scorer = choose_scorer(events, side, home if side == "home" else away)
    if scorer is not None:
        body = f"{body}{SEPARATOR}{_scorer_phrase(scorer)}"
    return _match_message(match, "goal", _match_route(match), f"هدف لـ {isolate(team)}!", body, pwa_origin)


def build_correction(match: MatchView, home: int, away: int, pwa_origin: str | None = None) -> PushMessage:
    """FR-009: the corrected score, no reason given, and it stays under type ``goal``."""
    return _match_message(
        match, "goal", _match_route(match), "تصحيح النتيجة", score_line(match, home, away), pwa_origin
    )


def build_final_score(
    match: MatchView,
    home: int,
    away: int,
    home_pen: int | None = None,
    away_pen: int | None = None,
    pwa_origin: str | None = None,
) -> PushMessage:
    """«انتهت المباراة» over the score, plus the shoot-out when both counts are known (FR-007)."""
    body = score_line(match, home, away)
    if home_pen is not None and away_pen is not None:
        body = f"{body}{SEPARATOR}بركلات الترجيح {isolate(str(home_pen))}{SCORE_DASH}{isolate(str(away_pen))}"
    return _match_message(match, "final_score", _match_route(match), "انتهت المباراة", body, pwa_origin)


def build_channels_updated(
    match: MatchView,
    added: Sequence[VisibleLink],
    removed: Sequence[VisibleLink],
    device_satellite_ids: tuple[int, ...] = (),
    pwa_origin: str | None = None,
) -> PushMessage:
    """One push per hold: the channels added, else the channels removed (FR-010 to FR-012).

    The named channel goes through :func:`choose_channel`, as the reminder's does: the device's own
    satellites first, then Nilesat and Badr, then any, free first. A channel with no satellite drops
    «على ‹satellite›». Nothing to say means the row is cancelled as ``no_net_change``, never built.
    """
    route = f"{_match_route(match)}?section=channels"
    if added:
        channel = _first(added, device_satellite_ids)
        body = f"أُضيفت {isolate(channel.name)}"
        if channel.satellite_name:
            body = f"{body} على {isolate(channel.satellite_name)}"
        if len(added) > 1:
            body = f"{body} و{isolate(str(len(added) - 1))} غيرها"
        title = f"قنوات جديدة لمباراة {isolate(match.home_name)} × {isolate(match.away_name)}"
    elif removed:
        channel = _first(removed, device_satellite_ids)
        title = f"تغيّرت قنوات مباراة {isolate(match.home_name)} × {isolate(match.away_name)}"
        body = f"لم تعد {isolate(channel.name)} تنقل المباراة"
    else:
        raise ValueError("a channels_updated row with nothing added and nothing removed must be cancelled")
    return _match_message(match, "channels_updated", route, title, body, pwa_origin)


def build_frequency_changed(
    channel: ChannelView,
    old: FrequencyReadout,
    new: FrequencyReadout,
    pwa_origin: str | None = None,
) -> PushMessage:
    """«تغيّر تردد ‹channel›» with both readouts; tag ``channel_<id>`` opens S6 (FR-014, FR-018)."""
    title = f"تغيّر تردد {isolate(channel.name)}"
    if channel.satellite_name:
        body = f"على {isolate(channel.satellite_name)}: {isolate(new.text)} (كان {isolate(old.text)})"
    else:
        body = f"{isolate(new.text)} (كان {isolate(old.text)})"
    route = f"/channel/{channel.id}"
    return PushMessage(
        token="",
        title=title,
        body=body,
        data={"type": "frequency_changed", "channel_id": str(channel.id), "route": route},
        tag=f"{CHANNEL_TAG_PREFIX}{channel.id}",
        link=_web_link(pwa_origin, route),
    )


def build_announcement(
    row_id: int,
    title: str,
    body: str,
    route: str,
    pwa_origin: str | None = None,
) -> PushMessage:
    """The composer's own text, unisolated, under the row's tag and the server-built route (FR-016)."""
    return PushMessage(
        token="",
        title=title,
        body=body,
        data={"type": "announcement", "announcement_id": str(row_id), "route": route},
        tag=f"{ANNOUNCEMENT_TAG_PREFIX}{row_id}",
        link=_web_link(pwa_origin, route),
    )


def _match_route(match: MatchView) -> str:
    return f"/match/{match.id}"


def _match_message(
    match: MatchView,
    row_type: str,
    route: str,
    title: str,
    body: str,
    pwa_origin: str | None,
) -> PushMessage:
    """A match-type message: it collapses on ``match_<id>`` and opens the match."""
    return PushMessage(
        token="",
        title=title,
        body=body,
        data={"type": row_type, "match_id": str(match.id), "route": route},
        tag=f"{TAG_PREFIX}{match.id}",
        link=_web_link(pwa_origin, route),
    )


def _web_link(pwa_origin: str | None, route: str) -> str | None:
    return f"{pwa_origin.rstrip('/')}{route}" if pwa_origin else None


def _first(links: Sequence[VisibleLink], device_satellite_ids: tuple[int, ...]) -> VisibleLink:
    channel = choose_channel(list(links), device_satellite_ids)
    if channel is None:  # the branch above already checked the list isn't empty
        raise ValueError("no channel to name")
    return channel


def _scorer_phrase(event: GoalEvent) -> str:
    parts = [isolate(event.player or "")]
    if event.type == "own_goal":
        parts.append("عكسي")
    if event.minute:
        parts.append(isolate(f"{event.minute}′"))
    return " ".join(parts)


def _minute_key(minute: str) -> tuple[int, int]:
    """``90+3`` sorts after ``90``; a minute that doesn't parse sorts first."""
    found = _MINUTE.match(minute.strip())
    if found is None:
        return (0, 0)
    return (int(found.group(1)), int(found.group(2) or 0))
