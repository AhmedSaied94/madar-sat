"""Channel changes: one pending push per match, netted when the hold ends (T025, research R5)."""

from __future__ import annotations

from datetime import timedelta

from sqlalchemy import select

from app.db.models import MatchChannel, MatchChannelChange, NotificationOutbox, Satellite
from app.notifications.channel_changes import net_pending, prune_announced, report_link_change
from tests import support


def _rows(session, model):
    return list(session.scalars(select(model).execution_options(populate_existing=True)))


def _add_channel(session, name: str = "قناة جديدة", *, visible: bool = True) -> int:
    from uuid import uuid4

    satellite = Satellite(
        slug=f"sat-{uuid4().hex[:12]}",
        name_en=f"Satellite {uuid4().hex[:6]}",
        name_ar="نايل سات",
        kind="satellite",
        orbital_position=-7.0,
    )
    session.add(satellite)
    session.flush()
    from app.db.models import Channel

    channel = Channel(
        kind="satellite",
        name=name,
        satellite_id=satellite.id,
        access="free",
        show_in_match=visible,
        locked_fields=[],
    )
    session.add(channel)
    session.flush()
    return channel.id


def test_a_change_inside_the_window_creates_one_pending_row_keyed_on_the_change(sync_session, frozen_now):
    bag = support.create_match_sync(sync_session, frozen_now, kickoff_in=timedelta(hours=2))
    channel_id = _add_channel(sync_session)

    written = report_link_change(sync_session, bag.match.id, channel_id, "added", "admin", frozen_now)
    sync_session.flush()

    assert written == 2
    [change] = _rows(sync_session, MatchChannelChange)
    [row] = _rows(sync_session, NotificationOutbox)
    assert row.type == "channels_updated"
    assert row.dedupe_key == f"channels_updated:{bag.match.id}:{change.id}"
    assert row.audience == {"kind": "match_followers", "match_id": bag.match.id}
    assert row.due_at == frozen_now + timedelta(minutes=5)


def test_three_changes_in_two_saves_make_one_row(sync_session, frozen_now):
    bag = support.create_match_sync(sync_session, frozen_now, kickoff_in=timedelta(hours=2))
    first, second, third = (_add_channel(sync_session, f"قناة {index}") for index in range(3))

    report_link_change(sync_session, bag.match.id, first, "added", "admin", frozen_now)
    report_link_change(sync_session, bag.match.id, second, "added", "admin", frozen_now)
    report_link_change(sync_session, bag.match.id, third, "removed", "admin", frozen_now)
    sync_session.flush()

    assert len(_rows(sync_session, MatchChannelChange)) == 3
    assert len(_rows(sync_session, NotificationOutbox)) == 1


def test_before_the_window_only_a_first_visible_channel_is_announced_to_match_followers(sync_session, frozen_now):
    bag = support.create_match_sync(sync_session, frozen_now, kickoff_in=timedelta(days=3), links=False)
    channel_id = _add_channel(sync_session)
    later = _add_channel(sync_session, "قناة ثانية")

    report_link_change(sync_session, bag.match.id, channel_id, "added", "admin", frozen_now)
    report_link_change(sync_session, bag.match.id, later, "added", "admin", frozen_now)
    sync_session.flush()

    [row] = _rows(sync_session, NotificationOutbox)
    assert row.audience == {"kind": "match_only", "match_id": bag.match.id}
    assert row.payload == {"match_id": bag.match.id, "first_channels": True}


def test_before_the_window_a_second_visible_link_that_already_exists_wins_nothing(sync_session, frozen_now):
    bag = support.create_match_sync(sync_session, frozen_now, kickoff_in=timedelta(days=3))
    channel_id = _add_channel(sync_session)

    written = report_link_change(sync_session, bag.match.id, channel_id, "added", "admin", frozen_now)

    assert written == 0
    assert _rows(sync_session, NotificationOutbox) == []


def test_a_removal_before_the_window_and_a_final_match_never_produce(sync_session, frozen_now):
    bag = support.create_match_sync(sync_session, frozen_now, kickoff_in=timedelta(days=3))
    channel_id = _add_channel(sync_session)
    assert report_link_change(sync_session, bag.match.id, channel_id, "removed", "admin", frozen_now) == 0

    bag.match.status = "finished"
    bag.match.status_source = "feed"
    sync_session.flush()
    assert report_link_change(sync_session, bag.match.id, channel_id, "added", "admin", frozen_now) == 0

    bag.match.kickoff_at = None
    bag.match.time_tbd = True
    bag.match.status = "scheduled"
    sync_session.flush()
    assert report_link_change(sync_session, bag.match.id, channel_id, "added", "admin", frozen_now) == 0


def test_one_row_per_direction_per_channel_per_match(sync_session, frozen_now):
    bag = support.create_match_sync(sync_session, frozen_now, kickoff_in=timedelta(hours=2))
    channel_id = _add_channel(sync_session)

    report_link_change(sync_session, bag.match.id, channel_id, "added", "admin", frozen_now)
    report_link_change(sync_session, bag.match.id, channel_id, "added", "admin", frozen_now)
    report_link_change(sync_session, bag.match.id, channel_id, "removed", "admin", frozen_now)
    sync_session.flush()

    changes = _rows(sync_session, MatchChannelChange)
    assert [(change.action) for change in changes] == ["added", "removed"]


def test_netting_keeps_the_changes_that_are_still_true_and_marks_them_announced(sync_session, frozen_now):
    bag = support.create_match_sync(sync_session, frozen_now, kickoff_in=timedelta(hours=2))
    added_channel = _add_channel(sync_session, "قناة مضافة")
    removed_channel = _add_channel(sync_session, "قناة محذوفة")
    sync_session.add(MatchChannel(match_id=bag.match.id, channel_id=added_channel, source="manual"))
    support_link = MatchChannel(match_id=bag.match.id, channel_id=removed_channel, source="manual")
    sync_session.add(support_link)
    sync_session.flush()

    report_link_change(sync_session, bag.match.id, added_channel, "added", "admin", frozen_now)
    report_link_change(sync_session, bag.match.id, removed_channel, "removed", "admin", frozen_now)
    sync_session.flush()
    # A hidden link is not visible, and a channel the editor made invisible is not announced either.
    support_link.is_hidden = True
    sync_session.flush()

    added, removed = net_pending(sync_session, bag.match.id, frozen_now)
    sync_session.flush()

    assert [link.channel_id for link in added] == [added_channel]
    assert [link.channel_id for link in removed] == [removed_channel]
    assert all(change.announced_at is not None for change in _rows(sync_session, MatchChannelChange))


def test_an_added_link_that_was_removed_again_nets_to_nothing(sync_session, frozen_now):
    bag = support.create_match_sync(sync_session, frozen_now, kickoff_in=timedelta(hours=2))
    channel_id = _add_channel(sync_session)

    report_link_change(sync_session, bag.match.id, channel_id, "added", "admin", frozen_now)
    report_link_change(sync_session, bag.match.id, channel_id, "removed", "admin", frozen_now)
    sync_session.flush()

    added, removed = net_pending(sync_session, bag.match.id, frozen_now)

    assert added == []
    assert removed == []


def test_a_hidden_name_is_not_named_when_a_link_goes(sync_session, frozen_now):
    from app.db.models import HiddenChannelName
    from app.domain.arabic import ar_normalize

    bag = support.create_match_sync(sync_session, frozen_now, kickoff_in=timedelta(hours=2))
    channel_id = _add_channel(sync_session, "قناة مخفية")
    sync_session.add(HiddenChannelName(name=ar_normalize("قناة مخفية")))
    sync_session.add(MatchChannel(match_id=bag.match.id, channel_id=channel_id, source="manual"))
    sync_session.flush()

    report_link_change(sync_session, bag.match.id, channel_id, "removed", "admin", frozen_now)
    sync_session.flush()
    added, removed = net_pending(sync_session, bag.match.id, frozen_now)

    assert added == []
    assert removed == []


def test_announced_changes_older_than_thirty_days_are_pruned(sync_session, frozen_now):
    bag = support.create_match_sync(sync_session, frozen_now, kickoff_in=timedelta(hours=2))
    channel_id = _add_channel(sync_session)
    report_link_change(sync_session, bag.match.id, channel_id, "added", "admin", frozen_now)
    sync_session.flush()
    [change] = _rows(sync_session, MatchChannelChange)
    change.announced_at = frozen_now - timedelta(days=31)
    sync_session.flush()

    removed = prune_announced(sync_session, frozen_now - timedelta(days=30))

    assert removed == 1
    assert _rows(sync_session, MatchChannelChange) == []


async def test_the_async_twin_records_and_queues_one_row(session, frozen_now):
    from app.notifications.channel_changes import report_link_change_async

    bag = await support.create_match(session, frozen_now, kickoff_in=timedelta(hours=2), links=False)
    channel_satellite = Satellite(
        slug="sat-async",
        name_en="Satellite async",
        name_ar="نايل سات",
        kind="satellite",
        orbital_position=-7.0,
    )
    session.add(channel_satellite)
    await session.flush()
    from app.db.models import Channel

    channel = Channel(
        kind="satellite",
        name="قناة غير متزامنة",
        satellite_id=channel_satellite.id,
        access="free",
        show_in_match=True,
        locked_fields=[],
    )
    session.add(channel)
    await session.flush()

    written = await report_link_change_async(session, bag.match.id, channel.id, "added", "admin", frozen_now)
    again = await report_link_change_async(session, bag.match.id, channel.id, "added", "admin", frozen_now)

    assert (written, again) == (2, 0)
    [row] = list(await session.scalars(select(NotificationOutbox)))
    assert row.type == "channels_updated"


async def test_the_async_twin_ignores_a_match_with_no_kickoff(session, frozen_now):
    from app.notifications.channel_changes import report_link_change_async

    bag = await support.create_match(session, frozen_now)
    bag.match.kickoff_at = None
    bag.match.time_tbd = True
    await session.flush()
    assert await report_link_change_async(session, bag.match.id, 1, "added", "admin", frozen_now) == 0
