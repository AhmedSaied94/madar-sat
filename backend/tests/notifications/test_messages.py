"""The reminder copy and FCM fields (research R8, T021)."""

from __future__ import annotations

import re
from dataclasses import replace
from datetime import timedelta

from app.notifications.dispatcher import visible_links
from app.notifications.messages import (
    FSI,
    PDI,
    MatchView,
    VisibleLink,
    build_message,
    minutes_phrase,
)
from app.notifications.sender import FcmSender
from tests import support

PWA = "https://app.example"
ARABIC_DIGITS = re.compile(r"[٠-٩]")


def _view(now, minutes: int = 15) -> MatchView:
    return MatchView(
        id=48213,
        kickoff_at=now + timedelta(minutes=minutes),
        home_name="الأهلي",
        away_name="Al Ahly SC",
    )


def _link(
    channel_id: int,
    *,
    access: str = "encrypted",
    satellite_id: int | None = None,
    slug: str | None = None,
    sort: int = 1,
) -> VisibleLink:
    return VisibleLink(
        channel_id=channel_id,
        name=f"Channel {channel_id}",
        access=access,
        sort_order=sort,
        show_in_match=True,
        satellite_id=satellite_id,
        satellite_slug=slug,
        satellite_name=f"Satellite {satellite_id}",
    )


def test_the_device_satellites_win_and_free_comes_first(frozen_now):
    links = [
        _link(1, access="encrypted", satellite_id=10, slug="other"),
        _link(2, access="free", satellite_id=10, slug="other"),
    ]
    message = build_message(_view(frozen_now), links, (10,), PWA, frozen_now)

    assert "Channel 2" in message.body


def test_with_nothing_on_the_device_satellites_the_default_set_wins(frozen_now):
    links = [
        _link(1, access="encrypted", satellite_id=99, slug="nilesat-7-0w", sort=1),
        _link(2, access="free", satellite_id=100, slug="badr-26-0e", sort=9),
        _link(3, access="free", satellite_id=101, slug="some-other", sort=0),
    ]
    message = build_message(_view(frozen_now), links, (7,), PWA, frozen_now)

    assert "Channel 2" in message.body
    assert "Channel 1" not in message.body


def test_no_visible_link_gives_the_no_channel_body(frozen_now):
    message = build_message(_view(frozen_now), [], (), PWA, frozen_now)

    assert message.body == "اضغط لعرض القنوات والترددات"


def test_the_title_says_the_real_minutes_with_arabic_agreement(frozen_now):
    assert "بعد 15 دقيقة" in build_message(_view(frozen_now, 15), [], (), PWA, frozen_now).title
    assert "بعد 7 دقائق" in build_message(_view(frozen_now, 7), [], (), PWA, frozen_now).title
    assert "بعد دقيقتين" in build_message(_view(frozen_now, 2), [], (), PWA, frozen_now).title
    assert "بعد دقيقة" in build_message(_view(frozen_now, 1), [], (), PWA, frozen_now).title
    # A match created a minute late still says at least one minute.
    assert "بعد دقيقة" in build_message(_view(frozen_now, 0), [], (), PWA, frozen_now).title
    assert minutes_phrase(3) == "دقائق"
    assert minutes_phrase(11) == "دقيقة"


def test_every_name_is_isolated_and_the_digits_are_western(frozen_now):
    links = [_link(1, access="free", satellite_id=10, slug="nilesat-7-0w")]
    message = build_message(_view(frozen_now), links, (10,), PWA, frozen_now)

    assert f"{FSI}الأهلي{PDI}" in message.title
    assert f"{FSI}Al Ahly SC{PDI}" in message.title
    assert f"{FSI}Channel 1{PDI}" in message.body
    assert not ARABIC_DIGITS.search(message.title)
    assert not ARABIC_DIGITS.search(message.body)


def test_tag_data_route_and_web_link(frozen_now):
    message = build_message(_view(frozen_now), [], (), PWA, frozen_now)

    assert message.tag == "match_48213"
    assert message.data == {
        "type": "kickoff_reminder",
        "match_id": "48213",
        "route": "/match/48213",
    }
    assert message.link == "https://app.example/match/48213"


def test_the_fcm_message_carries_the_collapsing_fields(frozen_now):
    from firebase_admin import messaging

    message = replace(build_message(_view(frozen_now), [], (), PWA, frozen_now), token="device-token")
    out = FcmSender(None)._message(messaging, message)

    assert out.android is not None and out.android.collapse_key == "match_48213"
    assert out.android.notification.tag == "match_48213"
    assert out.android.notification.channel_id == "reminders"
    assert out.webpush is not None and out.webpush.notification.tag == "match_48213"
    assert out.webpush.fcm_options.link == "https://app.example/match/48213"
    assert out.data["route"] == "/match/48213"


def test_hidden_deleted_and_placeholder_links_are_never_named(sync_session, frozen_now):
    from app.db.models import Channel, HiddenChannelName

    bag = support.create_match_sync(sync_session, frozen_now)
    hidden = Channel(kind="platform", name="Hidden Link", locked_fields=[])
    deleted = Channel(kind="platform", name="Deleted Link", locked_fields=[], deleted_at=frozen_now)
    placeholder = Channel(kind="platform", name="Placeholder Link", locked_fields=[], placeholder_source="livesoccertv")
    by_name = Channel(kind="platform", name="Always Hidden", locked_fields=[])
    sync_session.add_all([hidden, deleted, placeholder, by_name])
    sync_session.flush()
    sync_session.add(support_match_link(bag.match.id, hidden.id, is_hidden=True))
    for channel in (deleted, placeholder, by_name):
        sync_session.add(support_match_link(bag.match.id, channel.id))
    sync_session.add(HiddenChannelName(name="always hidden"))
    sync_session.flush()

    names = {link.name for link in visible_links(sync_session, bag.match.id)}

    assert names == {bag.channels[0].name}


def support_match_link(match_id: int, channel_id: int, *, is_hidden: bool = False):
    from app.db.models import MatchChannel

    return MatchChannel(match_id=match_id, channel_id=channel_id, source="manual", is_hidden=is_hidden)
