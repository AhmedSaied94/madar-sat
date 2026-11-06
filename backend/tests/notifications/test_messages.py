"""The kickoff reminder and every D6 type's copy and FCM fields (research R8, D6 T021/T023)."""

from __future__ import annotations

import json
import re
from dataclasses import replace
from datetime import timedelta

import pytest

from app.notifications.dispatcher import visible_links
from app.notifications.messages import (
    CHANNEL_ID,
    FSI,
    PDI,
    ChannelView,
    FrequencyReadout,
    GoalEvent,
    MatchView,
    VisibleLink,
    build_announcement,
    build_channels_updated,
    build_correction,
    build_final_score,
    build_frequency_changed,
    build_goal,
    build_match_started,
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
    assert minutes_phrase(3) == "دقائق"
    assert minutes_phrase(11) == "دقيقة"


def test_a_lead_under_a_minute_still_says_one_minute(frozen_now):
    """The row is due at kickoff − 15 min, but a late schedule can leave 20 seconds."""
    view = MatchView(id=1, kickoff_at=frozen_now + timedelta(seconds=20), home_name="أ", away_name="ب")

    assert "بعد دقيقة" in build_message(view, [], (), PWA, frozen_now).title


def test_a_kickoff_that_has_passed_is_never_worded_as_one_minute(frozen_now):
    """A negative lead is the dispatcher's to cancel, not the copy's to round up (B1-R1-5)."""
    view = MatchView(id=1, kickoff_at=frozen_now - timedelta(minutes=45), home_name="أ", away_name="ب")

    with pytest.raises(ValueError):
        build_message(view, [], (), PWA, frozen_now)


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


# --------------------------------------------------------------------------------- D6: the copy table


def _iso(text: str) -> str:
    return f"{FSI}{text}{PDI}"


def _score(home: str, home_goals: int, away: str, away_goals: int) -> str:
    """The contract's shape: each name and each digit isolated, an en dash between the goals."""
    return f"{_iso(home)} {_iso(str(home_goals))} – {_iso(str(away_goals))} {_iso(away)}"


def test_match_started_copy_and_fields(frozen_now):
    message = build_match_started(_view(frozen_now), PWA)

    assert message.title == "بدأت المباراة"
    assert message.body == f"{_iso('الأهلي')} × {_iso('Al Ahly SC')}"
    assert message.tag == "match_48213"
    assert message.data == {"type": "match_started", "match_id": "48213", "route": "/match/48213"}
    assert message.link == "https://app.example/match/48213"


def test_goal_copy_names_the_team_and_builds_the_score_beside_both_names(frozen_now):
    message = build_goal(_view(frozen_now), 1, 0, "home", (), PWA)

    assert message.title == f"هدف لـ {_iso('الأهلي')}!"
    assert message.body == _score("الأهلي", 1, "Al Ahly SC", 0)
    assert message.data == {"type": "goal", "match_id": "48213", "route": "/match/48213"}
    assert message.tag == "match_48213"


def test_the_scorer_is_the_last_goal_event_by_minute_when_the_count_matches(frozen_now):
    events = [
        GoalEvent("goal", "home", "10", "محمد"),
        GoalEvent("penalty", "home", "20", "أحمد"),
        GoalEvent("red_card", "home", "30", None),
    ]

    message = build_goal(_view(frozen_now), 2, 0, "home", events, PWA)

    assert message.body == f"{_score('الأهلي', 2, 'Al Ahly SC', 0)} · {_iso('أحمد')} {_iso('20′')}"


def test_a_scorer_is_never_shown_when_the_events_do_not_add_up(frozen_now):
    events = [GoalEvent("goal", "home", "10", "محمد"), GoalEvent("penalty", "home", "20", "أحمد")]

    message = build_goal(_view(frozen_now), 3, 0, "home", events, PWA)

    assert message.body == _score("الأهلي", 3, "Al Ahly SC", 0)


def test_an_event_without_a_player_names_none(frozen_now):
    events = [GoalEvent("goal", "home", "10", "محمد"), GoalEvent("goal", "home", "20", None)]

    message = build_goal(_view(frozen_now), 2, 0, "home", events, PWA)

    assert message.body == _score("الأهلي", 2, "Al Ahly SC", 0)


def test_an_own_goal_credits_the_side_that_scored_and_marks_the_scorer(frozen_now):
    events = [GoalEvent("own_goal", "home", "23", "سامي")]

    message = build_goal(_view(frozen_now), 1, 0, "home", events, PWA)

    assert message.body == f"{_score('الأهلي', 1, 'Al Ahly SC', 0)} · {_iso('سامي')} عكسي {_iso('23′')}"


def test_only_the_sides_goal_events_count(frozen_now):
    events = [GoalEvent("goal", "home", "10", "محمد"), GoalEvent("goal", "away", "20", "خصم")]

    message = build_goal(_view(frozen_now), 1, 1, "away", events, PWA)

    assert message.body == f"{_score('الأهلي', 1, 'Al Ahly SC', 1)} · {_iso('خصم')} {_iso('20′')}"


def test_correction_copy_stays_under_the_goal_type(frozen_now):
    message = build_correction(_view(frozen_now), 0, 0, PWA)

    assert message.title == "تصحيح النتيجة"
    assert message.body == _score("الأهلي", 0, "Al Ahly SC", 0)
    assert message.data == {"type": "goal", "match_id": "48213", "route": "/match/48213"}
    assert message.tag == "match_48213"


def test_final_score_copy(frozen_now):
    message = build_final_score(_view(frozen_now), 2, 1, pwa_origin=PWA)

    assert message.title == "انتهت المباراة"
    assert message.body == _score("الأهلي", 2, "Al Ahly SC", 1)
    assert message.data == {"type": "final_score", "match_id": "48213", "route": "/match/48213"}


def test_final_score_adds_the_shootout_when_known(frozen_now):
    message = build_final_score(_view(frozen_now), 1, 1, home_pen=4, away_pen=3, pwa_origin=PWA)

    assert message.body == (f"{_score('الأهلي', 1, 'Al Ahly SC', 1)} · بركلات الترجيح {_iso('4')} – {_iso('3')}")


def test_channels_added_names_the_channel_and_its_satellite(frozen_now):
    added = [_link(1, access="free", satellite_id=10, slug="nilesat-7-0w")]

    message = build_channels_updated(_view(frozen_now), added, [], (10,), PWA)

    assert message.title == f"قنوات جديدة لمباراة {_iso('الأهلي')} × {_iso('Al Ahly SC')}"
    assert message.body == f"أُضيفت {_iso('Channel 1')} على {_iso('Satellite 10')}"
    assert message.data == {
        "type": "channels_updated",
        "match_id": "48213",
        "route": "/match/48213?section=channels",
    }
    assert message.tag == "match_48213"
    assert message.link == "https://app.example/match/48213?section=channels"


def test_channels_added_counts_the_rest(frozen_now):
    added = [
        _link(1, access="free", satellite_id=10, slug="nilesat-7-0w"),
        _link(2, access="encrypted", satellite_id=10, slug="nilesat-7-0w"),
        _link(3, access="encrypted", satellite_id=10, slug="nilesat-7-0w"),
    ]

    message = build_channels_updated(_view(frozen_now), added, [], (10,), PWA)

    assert message.body == f"أُضيفت {_iso('Channel 1')} على {_iso('Satellite 10')} و{_iso('2')} غيرها"


def test_a_channel_without_a_satellite_drops_the_satellite_phrase(frozen_now):
    added = [VisibleLink(channel_id=5, name="Platform", access="free", sort_order=1, show_in_match=True)]

    message = build_channels_updated(_view(frozen_now), added, [], (), PWA)

    assert message.body == f"أُضيفت {_iso('Platform')}"


def test_channels_removed_only_uses_the_new_copy(frozen_now):
    removed = [_link(4, access="free", satellite_id=10, slug="nilesat-7-0w")]

    message = build_channels_updated(_view(frozen_now), [], removed, (10,), PWA)

    assert message.title == f"تغيّرت قنوات مباراة {_iso('الأهلي')} × {_iso('Al Ahly SC')}"
    assert message.body == f"لم تعد {_iso('Channel 4')} تنقل المباراة"


def test_channels_added_win_over_removed_when_both_are_netted(frozen_now):
    added = [_link(1, access="free", satellite_id=10, slug="nilesat-7-0w")]
    removed = [_link(4, access="free", satellite_id=10, slug="nilesat-7-0w")]

    message = build_channels_updated(_view(frozen_now), added, removed, (10,), PWA)

    assert message.body == f"أُضيفت {_iso('Channel 1')} على {_iso('Satellite 10')}"


def test_nothing_added_or_removed_is_never_a_message(frozen_now):
    with pytest.raises(ValueError):
        build_channels_updated(_view(frozen_now), [], [], (), PWA)


def test_frequency_change_shows_the_new_and_old_readouts(frozen_now):
    channel = ChannelView(id=77, name="beIN SPORTS 1", satellite_name="نايل سات")

    message = build_frequency_changed(
        channel,
        FrequencyReadout(11766, "H", 27500),
        FrequencyReadout(11843, "H", 27500),
        PWA,
    )

    assert message.title == f"تغيّر تردد {_iso('beIN SPORTS 1')}"
    assert message.body == f"على {_iso('نايل سات')}: {_iso('11843 H 27500')} (كان {_iso('11766 H 27500')})"
    assert message.data == {"type": "frequency_changed", "channel_id": "77", "route": "/channel/77"}
    assert message.tag == "channel_77"
    assert message.link == "https://app.example/channel/77"


def test_a_frequency_change_without_a_satellite_drops_the_satellite_phrase(frozen_now):
    channel = ChannelView(id=77, name="beIN SPORTS 1")

    message = build_frequency_changed(
        channel,
        FrequencyReadout(11766, "H", 27500),
        FrequencyReadout(11843, "H", 27500),
    )

    assert message.body == f"{_iso('11843 H 27500')} (كان {_iso('11766 H 27500')})"
    assert message.link is None


def test_an_announcement_keeps_the_admins_text_verbatim(frozen_now):
    message = build_announcement(901, "تحديث", "نص الإعلان", "/match/48213", PWA)

    assert message.title == "تحديث"
    assert message.body == "نص الإعلان"
    assert message.tag == "announcement_901"
    assert message.data == {"type": "announcement", "announcement_id": "901", "route": "/match/48213"}
    assert message.link == "https://app.example/match/48213"


def test_a_score_is_never_one_isolated_string(frozen_now):
    message = build_goal(_view(frozen_now), 1, 0, "home", (), PWA)

    assert f"{FSI}1 – 0{PDI}" not in message.body
    assert _iso("1") in message.body
    assert _iso("0") in message.body


@pytest.mark.parametrize(
    "build",
    [
        lambda view: build_match_started(view, PWA),
        lambda view: build_goal(view, 1, 0, "home", (), PWA),
        lambda view: build_correction(view, 0, 0, PWA),
        lambda view: build_final_score(view, 2, 1, pwa_origin=PWA),
    ],
)
def test_match_types_open_the_match_and_collapse_on_its_tag(frozen_now, build):
    message = build(_view(frozen_now))

    assert message.tag == "match_48213"
    assert message.data["route"] == "/match/48213"
    assert message.link == "https://app.example/match/48213"


def test_every_type_keeps_the_reminders_android_channel(frozen_now):
    """A new Android channel needs a client release, so old builds would fall back (contract, FCM fields)."""
    from firebase_admin import messaging

    assert CHANNEL_ID == "reminders"
    message = replace(build_goal(_view(frozen_now), 1, 0, "home", (), PWA), token="device-token")
    out = FcmSender(None)._message(messaging, message)

    assert out.android is not None and out.android.notification.channel_id == "reminders"
    assert out.data["type"] == "goal"
    assert out.data["route"] == "/match/48213"


def test_every_data_value_is_a_string(frozen_now):
    channel = ChannelView(id=77, name="beIN SPORTS 1", satellite_name="نايل سات")
    messages = [
        build_match_started(_view(frozen_now), PWA),
        build_goal(_view(frozen_now), 1, 0, "home", (), PWA),
        build_correction(_view(frozen_now), 0, 0, PWA),
        build_final_score(_view(frozen_now), 2, 1, pwa_origin=PWA),
        build_channels_updated(_view(frozen_now), [_link(1, satellite_id=10)], [], (10,), PWA),
        build_frequency_changed(channel, FrequencyReadout(11766, "H", 27500), FrequencyReadout(11843, "H", 27500), PWA),
        build_announcement(901, "تحديث", "نص", "/match/48213", PWA),
    ]

    for message in messages:
        assert all(isinstance(value, str) for value in message.data.values())
        assert json.dumps(message.data)
        assert not ARABIC_DIGITS.search(message.title)
        assert not ARABIC_DIGITS.search(message.body)
