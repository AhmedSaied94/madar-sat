"""LiveSoccerTV's matching, placeholders and link rules (T055, R15, R18)."""

from __future__ import annotations

from datetime import UTC, datetime

import pytest
from sqlalchemy import select, text

from app.adapters.livesoccertv_links import apply_broadcasts
from app.adapters.messages import BroadcastChannel
from app.db.models import AuditLog, Channel, MatchChannel
from tests.adapters.helpers import dataset_versions, new_channel, new_match

COUNTRIES = ("Egypt", "Saudi Arabia", "Algeria", "Middle East")


@pytest.fixture
def match(sync_session):
    return new_match(sync_session, kickoff_at=datetime(2026, 11, 7, 18, 0, tzinfo=UTC))


def links_of(session, match_id: int) -> dict[int, MatchChannel]:
    rows = session.execute(select(MatchChannel).where(MatchChannel.match_id == match_id)).scalars()
    return {row.channel_id: row for row in rows}


def placeholders(session) -> list[Channel]:
    ids = [row[0] for row in session.execute(text("SELECT id FROM channels WHERE placeholder_source = 'livesoccertv'"))]
    return [session.get(Channel, channel_id) for channel_id in ids]


def test_an_existing_channel_is_linked_whatever_country_lists_it(sync_session, match) -> None:
    channel = new_channel(sync_session, "beIN Sports HD 1", country="qatar")
    other = new_channel(sync_session, "beIN Sports HD 1", country="morocco")

    outcome = apply_broadcasts(
        sync_session,
        match_id=match.id,
        channels=[BroadcastChannel(name="beIN Sports HD 1", country="Algeria")],
        countries=COUNTRIES,
    )

    assert sorted(outcome.added) == sorted([channel.id, other.id])
    stored = links_of(sync_session, match.id)
    assert set(stored) == {channel.id, other.id}
    assert {row.source for row in stored.values()} == {"livesoccertv"}


def test_a_channel_is_found_by_its_display_name_too(sync_session, match) -> None:
    channel = new_channel(sync_session, "قناة الاختبار", display_name="Test HD")

    apply_broadcasts(
        sync_session,
        match_id=match.id,
        channels=[BroadcastChannel(name="Test HD", country="Egypt")],
        countries=COUNTRIES,
    )

    assert set(links_of(sync_session, match.id)) == {channel.id}


def test_a_listed_country_picks_the_country_variant(sync_session, match) -> None:
    egyptian = new_channel(sync_session, "beIN Sports", country="مصر")
    kuwaiti = new_channel(sync_session, "beIN Sports", country="kwait")
    # The Arabic country names do not normalize, so the rule falls back to linking every variant
    # rather than guessing a translation (constitution II).
    outcome = apply_broadcasts(
        sync_session,
        match_id=match.id,
        channels=[BroadcastChannel(name="beIN Sports", country="Algeria")],
        countries=COUNTRIES,
    )
    assert set(outcome.added) == {egyptian.id, kuwaiti.id}

    english_kuwait = new_channel(sync_session, "beIN Max", country="kuwait")
    outcome = apply_broadcasts(
        sync_session,
        match_id=match.id,
        channels=[BroadcastChannel(name="beIN Max", country="Kuwait")],
        countries=COUNTRIES,
    )
    assert outcome.added == [english_kuwait.id]


def test_a_name_from_a_configured_country_becomes_one_hidden_placeholder(sync_session, match) -> None:
    before = dataset_versions(sync_session)

    outcome = apply_broadcasts(
        sync_session,
        match_id=match.id,
        channels=[BroadcastChannel(name="Al Kass One", country="Egypt")],
        countries=COUNTRIES,
    )

    created = placeholders(sync_session)
    assert len(created) == 1
    placeholder = created[0]
    assert placeholder.kind == "platform"
    assert placeholder.name == "Al Kass One"
    assert placeholder.satellite_id is None
    assert placeholder.frequency_mhz is None
    assert placeholder.show_in_match is False
    assert placeholder.country == "egypt"
    assert outcome.placeholders_created == ["Al Kass One"]
    assert outcome.added == [placeholder.id]
    assert set(links_of(sync_session, match.id)) == {placeholder.id}

    assert dataset_versions(sync_session)["channels"] == before["channels"] + 1
    audit = (
        sync_session.execute(
            select(AuditLog).where(AuditLog.entity == "channels", AuditLog.entity_id == placeholder.id)
        )
        .scalars()
        .all()
    )
    assert len(audit) == 1
    assert audit[0].source == "livesoccertv"
    assert audit[0].action == "create"


def test_the_same_placeholder_is_reused_by_a_second_run_and_another_match(sync_session, match) -> None:
    first = apply_broadcasts(
        sync_session,
        match_id=match.id,
        channels=[BroadcastChannel(name="Al Kass One", country="Egypt")],
        countries=COUNTRIES,
    )
    second = apply_broadcasts(
        sync_session,
        match_id=match.id,
        channels=[BroadcastChannel(name="Al Kass One", country="Egypt")],
        countries=COUNTRIES,
    )
    other = new_match(sync_session, kickoff_at=datetime(2026, 11, 8, 18, 0, tzinfo=UTC))
    third = apply_broadcasts(
        sync_session,
        match_id=other.id,
        channels=[BroadcastChannel(name="Al Kass One", country="Egypt")],
        countries=COUNTRIES,
    )

    assert len(placeholders(sync_session)) == 1
    assert second.placeholders_created == []
    assert second.added == [] and second.removed == []
    assert third.placeholders_created == []
    assert set(links_of(sync_session, other.id)) == set(first.added)


def test_a_soft_deleted_placeholder_is_never_recreated(sync_session, match) -> None:
    new_channel(sync_session, "Rejected Channel", country="egypt", deleted=True)

    outcome = apply_broadcasts(
        sync_session,
        match_id=match.id,
        channels=[BroadcastChannel(name="Rejected Channel", country="Egypt")],
        countries=COUNTRIES,
    )

    assert outcome.added == []
    assert placeholders(sync_session) == []
    assert outcome.skipped == [{"name": "Rejected Channel", "country": "egypt", "why": "deleted_by_editor"}]


def test_a_name_from_an_unlisted_country_is_skipped_and_counted(sync_session, match) -> None:
    outcome = apply_broadcasts(
        sync_session,
        match_id=match.id,
        channels=[BroadcastChannel(name="FanCode", country="Afghanistan")],
        countries=COUNTRIES,
    )

    assert outcome.added == []
    assert placeholders(sync_session) == []
    assert outcome.skipped == [{"name": "FanCode", "country": "afghanistan", "why": "country_not_listed"}]


def test_a_duplicate_name_is_linked_once(sync_session, match) -> None:
    channel = new_channel(sync_session, "ON Sport 1")

    outcome = apply_broadcasts(
        sync_session,
        match_id=match.id,
        channels=[
            BroadcastChannel(name="ON Sport 1", country="Egypt"),
            BroadcastChannel(name="ON Sport 1", country="Saudi Arabia"),
        ],
        countries=COUNTRIES,
    )

    assert outcome.added == [channel.id]
    assert set(links_of(sync_session, match.id)) == {channel.id}


def test_only_our_own_links_are_added_and_removed(sync_session, match) -> None:
    ours = new_channel(sync_session, "ON Sport 1")
    manual = new_channel(sync_session, "قناة يدوية")
    editor_hidden = new_channel(sync_session, "beIN Sports HD 1")
    sync_session.add(MatchChannel(match_id=match.id, channel_id=manual.id, source="manual", imported_by=None))
    sync_session.add(
        MatchChannel(
            match_id=match.id,
            channel_id=editor_hidden.id,
            source="livesoccertv",
            imported_by="livesoccertv",
            is_hidden=True,
        )
    )
    sync_session.flush()

    outcome = apply_broadcasts(
        sync_session,
        match_id=match.id,
        channels=[BroadcastChannel(name="ON Sport 1", country="Egypt")],
        countries=COUNTRIES,
    )

    stored = links_of(sync_session, match.id)
    assert ours.id in stored
    assert manual.id in stored  # an editor's link is never removed
    # The page no longer lists it, so our own row goes; an editor would have made it `manual`.
    assert editor_hidden.id not in stored
    assert outcome.removed == [editor_hidden.id]

    sync_session.add(
        MatchChannel(
            match_id=match.id,
            channel_id=editor_hidden.id,
            source="manual",
            imported_by="livesoccertv",
            is_hidden=True,
        )
    )
    sync_session.flush()
    apply_broadcasts(
        sync_session,
        match_id=match.id,
        channels=[BroadcastChannel(name="beIN Sports HD 1", country="Egypt")],
        countries=COUNTRIES,
    )
    again = links_of(sync_session, match.id)[editor_hidden.id]
    assert again.is_hidden is True  # a hidden link stays hidden
    assert again.source == "manual"


def test_the_matches_dataset_moves_when_a_link_changes(sync_session, match) -> None:
    new_channel(sync_session, "ON Sport 1")
    before = dataset_versions(sync_session)

    apply_broadcasts(
        sync_session,
        match_id=match.id,
        channels=[BroadcastChannel(name="ON Sport 1", country="Egypt")],
        countries=COUNTRIES,
    )

    assert dataset_versions(sync_session)["matches"] == before["matches"] + 1


# --- D5: the unresolved queue and channel aliases (T054, R11) ------------------------------------


def _queued(session) -> list:
    return list(
        session.execute(
            text("SELECT source, kind, name, context, seen_count, state FROM unresolved_names ORDER BY id")
        ).mappings()
    )


def _broadcast(session, match, name: str = "قناة جديدة", country: str = "Egypt"):
    return apply_broadcasts(
        session,
        match_id=match.id,
        channels=[BroadcastChannel(name=name, country=country)],
        countries=COUNTRIES,
    )


def _channel_alias(session, alias: str, channel_id: int) -> None:
    session.execute(
        text(
            "INSERT INTO channel_aliases (source, alias_norm, channel_id) "
            "VALUES ('livesoccertv', ar_normalize(:alias), :channel_id)"
        ),
        {"alias": alias, "channel_id": channel_id},
    )


def test_a_new_placeholder_also_records_a_channel_row(sync_session, match) -> None:
    before = dataset_versions(sync_session)["unresolved_names"]

    outcome = _broadcast(sync_session, match)

    assert outcome.placeholders_created == ["قناة جديدة"]  # R11: the placeholder stays
    [row] = _queued(sync_session)
    assert (row["source"], row["kind"], row["name"], row["seen_count"]) == ("livesoccertv", "channel", "قناة جديدة", 1)
    assert row["context"]["match_id"] == match.id
    assert row["context"]["home"] == match.home_team_name
    assert dataset_versions(sync_session)["unresolved_names"] == before + 1


def test_an_existing_placeholder_raises_the_count(sync_session, match) -> None:
    _broadcast(sync_session, match)
    outcome = _broadcast(sync_session, match)

    assert outcome.placeholders_created == []
    assert [row["seen_count"] for row in _queued(sync_session)] == [2]


def test_one_page_listing_a_placeholder_twice_counts_once(sync_session, match) -> None:
    apply_broadcasts(
        sync_session,
        match_id=match.id,
        channels=[
            BroadcastChannel(name="قناة جديدة", country="Egypt"),
            BroadcastChannel(name="قناة جديدة", country="Algeria"),
        ],
        countries=COUNTRIES,
    )
    _broadcast(sync_session, match)

    assert [row["seen_count"] for row in _queued(sync_session)] == [2]


def test_a_real_channel_is_not_queued(sync_session, match) -> None:
    new_channel(sync_session, "ON Sport 1")

    _broadcast(sync_session, match, name="ON Sport 1")

    assert _queued(sync_session) == []


def test_a_name_from_an_unlisted_country_is_not_queued(sync_session, match) -> None:
    _broadcast(sync_session, match, country="Portugal")
    assert _queued(sync_session) == []


def test_a_channel_alias_comes_first_and_makes_no_placeholder(sync_session, match) -> None:
    target = new_channel(sync_session, "القناة الهدف")
    _channel_alias(sync_session, "قناة جديدة", target.id)

    outcome = _broadcast(sync_session, match)

    assert outcome.placeholders_created == []
    assert list(links_of(sync_session, match.id)) == [target.id]
    assert _queued(sync_session) == []
    assert placeholders(sync_session) == []


def test_an_alias_written_after_a_placeholder_moves_the_link_to_its_target(sync_session, match) -> None:
    _broadcast(sync_session, match)
    target = new_channel(sync_session, "القناة الهدف")
    _channel_alias(sync_session, "قناة جديدة", target.id)

    _broadcast(sync_session, match)

    assert list(links_of(sync_session, match.id)) == [target.id]
    assert len(placeholders(sync_session)) == 1  # kept, per R11


def test_an_alias_to_a_deleted_channel_is_not_used(sync_session, match) -> None:
    target = new_channel(sync_session, "القناة المحذوفة", deleted=True)
    _channel_alias(sync_session, "قناة جديدة", target.id)

    _broadcast(sync_session, match)

    assert target.id not in links_of(sync_session, match.id)
