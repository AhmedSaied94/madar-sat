"""Test support: a fake push sender, factories for matches and devices (D3, Lane B1)."""

from __future__ import annotations

import uuid
from dataclasses import dataclass, field
from datetime import UTC, datetime, timedelta
from typing import Any

from sqlalchemy.orm import Session

from app.db.models import Channel, Competition, Device, DeviceFollow, Match, MatchChannel, Satellite, Team
from app.devices.tokens import token_hash
from app.notifications.messages import PushMessage
from app.notifications.sender import SendOutcome
from app.workers.base import Retryable


class FakePushSender:
    """Records each page and answers per token, the way ``send_each`` does (B1-R1-6).

    A token's behaviour is ``ok`` (default), ``UNREGISTERED`` (a dead token, which the dispatcher
    clears), ``retryable`` (a transient error that outlasted the real sender's own re-sends: an
    outage, a limit) or ``failed`` (any other per-message error: a bad message field). The real
    sender returns those as ``SendOutcome`` fields and never raises for one device, so the fake does
    the same. A *whole call* failure, the one case ``send_each`` raises, is ``fail_page`` (that call
    only) or ``fail_every_page``.
    """

    def __init__(
        self,
        behaviour: dict[str, str] | None = None,
        fail_page: int | None = None,
        fail_every_page: bool = False,
        pwa_origin: str | None = None,
    ) -> None:
        self.behaviour = behaviour or {}
        self.fail_page = fail_page
        self.fail_every_page = fail_every_page
        self.pwa_origin = pwa_origin
        self.pages: list[list[PushMessage]] = []
        self.calls = 0

    def send_page(self, messages: list[PushMessage]) -> SendOutcome:
        """Answer one page; raises ``Retryable`` only for a whole-call failure."""
        self.calls += 1
        self.pages.append(list(messages))
        if self.fail_every_page or (self.fail_page is not None and self.calls == self.fail_page):
            raise Retryable("UNAVAILABLE")
        sent = failed = 0
        unregistered: list[str] = []
        retryable: list[str] = []
        for message in messages:
            answer = self.behaviour.get(message.token, "ok")
            if answer == "ok":
                sent += 1
            elif answer == "UNREGISTERED":
                unregistered.append(message.token)
            elif answer == "retryable":
                retryable.append(message.token)
            else:
                failed += 1
        return SendOutcome(sent=sent, failed=failed, unregistered=tuple(unregistered), retryable=tuple(retryable))

    @property
    def tokens_sent(self) -> list[str]:
        return [message.token for page in self.pages for message in page]


@dataclass
class MatchBag:
    """A match with two teams, a competition and (optionally) visible channel links."""

    match: Match
    competition: Competition
    home: Team
    away: Team
    satellites: list[Satellite] = field(default_factory=list)
    channels: list[Channel] = field(default_factory=list)
    links: list[MatchChannel] = field(default_factory=list)

    @property
    def rows(self) -> list[Any]:
        return [self.competition, self.home, self.away, self.match, *self.satellites, *self.channels, *self.links]


def build_match(
    now: datetime,
    *,
    kickoff_in: timedelta | None = timedelta(minutes=20),
    satellite_slugs: tuple[str, ...] = ("nilesat-7-0w",),
    links: bool = True,
    status: str = "scheduled",
    status_source: str = "clock",
    time_tbd: bool = False,
    access: str = "free",
    show_in_match: bool = True,
    competition_priority: int | None = 1,
) -> MatchBag:
    suffix = uuid.uuid4().hex[:8]
    competition = Competition(name=f"دوري {suffix}", priority=competition_priority)
    home = Team(name=f"الأهلي {suffix}")
    away = Team(name=f"الزمالك {suffix}")
    kickoff = now + kickoff_in if kickoff_in is not None else None
    match = Match(
        source="legacy",
        match_date=(kickoff or now).date(),
        kickoff_at=kickoff,
        competition_name=competition.name,
        home_team_name=home.name,
        away_team_name=away.name,
        status=status,
        status_source=status_source,
        time_tbd=time_tbd,
        locked_fields=[],
    )
    satellites: list[Satellite] = []
    channels: list[Channel] = []
    channel_links: list[MatchChannel] = []
    if links:
        for index, slug in enumerate(satellite_slugs):
            satellite = Satellite(
                slug=f"{slug}-{suffix}" if slug == "nilesat-7-0w" else slug,
                name_en=f"Satellite {suffix} {index}",
                name_ar="نايل سات",
                kind="satellite",
                orbital_position=-7.0,
            )
            satellites.append(satellite)
            channel = Channel(
                kind="satellite",
                name=f"قناة {suffix} {index}",
                access=access,
                show_in_match=show_in_match,
                locked_fields=[],
            )
            channels.append(channel)
            channel_links.append(MatchChannel(source="manual"))
    return MatchBag(match, competition, home, away, satellites, channels, channel_links)


def _satellite_rows(bag: MatchBag) -> None:
    """Channels are inserted after their satellite (``ck_channels_kind_fields`` needs both)."""
    for satellite, channel in zip(bag.satellites, bag.channels, strict=True):
        channel.satellite_id = satellite.id


async def create_match(session: Any, now: datetime, **kwargs: Any) -> MatchBag:
    bag = build_match(now, **kwargs)
    session.add_all([bag.competition, bag.home, bag.away, *bag.satellites])
    await session.flush()
    _satellite_rows(bag)
    session.add_all(bag.channels)
    await session.flush()
    bag.match.competition_id = bag.competition.id
    bag.match.home_team_id = bag.home.id
    bag.match.away_team_id = bag.away.id
    session.add(bag.match)
    await session.flush()
    for channel, link in zip(bag.channels, bag.links, strict=True):
        link.match_id = bag.match.id
        link.channel_id = channel.id
    session.add_all(bag.links)
    await session.flush()
    return bag


def create_match_sync(session: Session, now: datetime, **kwargs: Any) -> MatchBag:
    bag = build_match(now, **kwargs)
    session.add_all([bag.competition, bag.home, bag.away, *bag.satellites])
    session.flush()
    _satellite_rows(bag)
    session.add_all(bag.channels)
    session.flush()
    bag.match.competition_id = bag.competition.id
    bag.match.home_team_id = bag.home.id
    bag.match.away_team_id = bag.away.id
    session.add(bag.match)
    session.flush()
    for channel, link in zip(bag.channels, bag.links, strict=True):
        link.match_id = bag.match.id
        link.channel_id = channel.id
    session.add_all(bag.links)
    session.flush()
    return bag


def new_device(
    session: Session,
    *,
    token: str | None = None,
    push_token: str | None = None,
    satellite_ids: list[int] | None = None,
    prefs: dict[str, Any] | None = None,
    platform: str = "android",
) -> Device:
    device = Device(
        install_id=uuid.uuid4(),
        token_hash=token_hash(token or uuid.uuid4().hex),
        platform=platform,
        push_token=push_token,
        prefs=prefs or {},
        satellite_ids=satellite_ids or [],
        last_seen_at=datetime(2026, 10, 28, 18, 0, tzinfo=UTC),
    )
    session.add(device)
    session.flush()
    return device


def follow(
    session: Session,
    device: Device,
    *,
    team: int | None = None,
    competition: int | None = None,
    match: int | None = None,
) -> DeviceFollow:
    row = DeviceFollow(device_id=device.id, team_id=team, competition_id=competition, match_id=match)
    session.add(row)
    session.flush()
    return row
