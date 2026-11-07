"""S6 and S8: the channel's 7-day limit and the competition detail (T004, contracts/public-api.md)."""

from __future__ import annotations

from datetime import date, timedelta

from sqlalchemy import update

from app.db.models import (
    Channel,
    Competition,
    DatasetVersion,
    Match,
    MatchChannel,
    RightsHolder,
    RightsHolderCarriage,
    RightsHolderCarriageSatellite,
    RightsHolderCompetition,
    Satellite,
)


def _match(kickoff, label: str, competition_id: int | None = None) -> Match:
    return Match(
        source="legacy",
        match_date=date(2026, 10, 28),
        kickoff_at=kickoff,
        competition_id=competition_id,
        competition_name="كأس",
        home_team_name=f"{label} أ",
        away_team_name=f"{label} ب",
        locked_fields=[],
    )


async def test_channel_upcoming_is_limited_to_the_next_seven_days(public_client, session, frozen_now):
    channel = Channel(kind="platform", name="قناة الاختبار السبعة", locked_fields=[])
    session.add(channel)
    await session.flush()
    rows = {
        "too-old": _match(frozen_now - timedelta(minutes=151), "too-old"),
        "old-edge": _match(frozen_now - timedelta(minutes=150), "old-edge"),
        "new-edge": _match(frozen_now + timedelta(days=7), "new-edge"),
        "too-new": _match(frozen_now + timedelta(days=7, seconds=1), "too-new"),
    }
    session.add_all(rows.values())
    await session.flush()
    session.add_all(MatchChannel(match_id=m.id, channel_id=channel.id, source="manual") for m in rows.values())
    await session.flush()

    data = (await public_client.get(f"/v1/channels/{channel.id}")).json()["data"]

    assert [m["id"] for m in data["upcoming_matches"]] == [rows["old-edge"].id, rows["new-edge"].id]
    assert data["recent_frequency_changes"] == []


async def test_channel_upcoming_holds_at_most_twenty(public_client, session, frozen_now):
    channel = Channel(kind="platform", name="قناة الاختبار العشرون", locked_fields=[])
    session.add(channel)
    await session.flush()
    rows = [_match(frozen_now + timedelta(hours=i), f"m{i}") for i in range(1, 23)]
    session.add_all(rows)
    await session.flush()
    session.add_all(MatchChannel(match_id=m.id, channel_id=channel.id, source="manual") for m in rows)
    await session.flush()

    data = (await public_client.get(f"/v1/channels/{channel.id}")).json()["data"]

    assert len(data["upcoming_matches"]) == 20


async def _competition(session, name="بطولة التفاصيل") -> Competition:
    competition = Competition(name=name)
    session.add(competition)
    await session.flush()
    return competition


async def test_competition_has_upcoming_and_recent_at_most_thirty_each(public_client, session, frozen_now):
    competition = await _competition(session)
    upcoming = [_match(frozen_now + timedelta(hours=i), f"u{i}", competition.id) for i in range(1, 33)]
    recent = [_match(frozen_now - timedelta(hours=i), f"r{i}", competition.id) for i in range(1, 33)]
    session.add_all([*upcoming, *recent])
    await session.flush()

    data = (await public_client.get(f"/v1/competitions/{competition.id}")).json()["data"]

    assert [m["id"] for m in data["upcoming"]] == [m.id for m in upcoming[:30]]
    assert [m["id"] for m in data["recent"]] == [m.id for m in recent[:30]]


async def test_rights_holders_carry_satellites_and_their_competition_count(public_client, session):
    competition = await _competition(session)
    other = await _competition(session, "بطولة أخرى")
    satellite = Satellite(
        slug="sat-details", name_en="Sat Details", name_ar="قمر", kind="satellite", orbital_position=-7.0
    )
    holder = RightsHolder(name="حقوق التفاصيل")
    session.add_all([satellite, holder])
    await session.flush()
    carriage = RightsHolderCarriage(rights_holder_id=holder.id, position=0, access="encrypted")
    session.add(carriage)
    await session.flush()
    session.add_all(
        [
            RightsHolderCarriageSatellite(carriage_id=carriage.id, satellite_id=satellite.id),
            RightsHolderCompetition(rights_holder_id=holder.id, competition_id=competition.id),
            RightsHolderCompetition(rights_holder_id=holder.id, competition_id=other.id),
        ]
    )
    await session.flush()

    data = (await public_client.get(f"/v1/competitions/{competition.id}")).json()["data"]

    [row] = data["rights_holders"]
    assert (row["id"], row["name"], row["logo"], row["competition_count"]) == (holder.id, "حقوق التفاصيل", None, 2)
    assert [sat["id"] for sat in row["satellites"]] == [satellite.id]


async def test_competition_etag_changes_when_a_match_changes(public_client, session):
    competition = await _competition(session)
    url = f"/v1/competitions/{competition.id}"
    before = (await public_client.get(url)).headers["etag"]

    await session.execute(
        update(DatasetVersion).where(DatasetVersion.name == "matches").values(version=DatasetVersion.version + 1)
    )
    await session.flush()

    response = await public_client.get(url, headers={"If-None-Match": before})
    assert response.status_code == 200
    assert response.headers["etag"] != before


async def test_recent_frequency_changes_are_the_last_five_newest_first(public_client, session, frozen_now):
    from app.db.models import ChannelFrequencyChange

    channel = Channel(kind="platform", name="قناة الترددات", locked_fields=[])
    session.add(channel)
    await session.flush()
    session.add_all(
        ChannelFrequencyChange(
            channel_id=channel.id,
            old_frequency_mhz=11000 + index,
            new_frequency_mhz=11001 + index,
            old_polarization="H",
            new_polarization="V",
            old_symbol_rate=27500,
            new_symbol_rate=27500,
            source="admin",
            detected_at=frozen_now - timedelta(minutes=index),
        )
        for index in range(7)
    )
    await session.flush()

    data = (await public_client.get(f"/v1/channels/{channel.id}")).json()["data"]

    changes = data["recent_frequency_changes"]
    assert len(changes) == 5
    assert [row["new"]["frequency_mhz"] for row in changes] == [11001, 11002, 11003, 11004, 11005]
    assert changes[0]["old"] == {"frequency_mhz": 11000, "polarization": "H", "symbol_rate": 27500}
    assert changes[0]["new"] == {"frequency_mhz": 11001, "polarization": "V", "symbol_rate": 27500}
    assert changes[0]["detected_at"].startswith(frozen_now.strftime("%Y-%m-%dT%H:%M"))


async def test_a_new_history_row_moves_the_etag(public_client, session, frozen_now):
    from app.db.models import ChannelFrequencyChange

    channel = Channel(kind="platform", name="قناة الترددات الثانية", locked_fields=[])
    session.add(channel)
    await session.flush()
    url = f"/v1/channels/{channel.id}"
    before = (await public_client.get(url)).headers["etag"]

    session.add(
        ChannelFrequencyChange(
            channel_id=channel.id,
            old_frequency_mhz=11766,
            new_frequency_mhz=11843,
            old_polarization="H",
            new_polarization="H",
            old_symbol_rate=27500,
            new_symbol_rate=27500,
            source="admin",
            detected_at=frozen_now,
        )
    )
    await session.execute(
        update(DatasetVersion).where(DatasetVersion.name == "channels").values(version=DatasetVersion.version + 1)
    )
    await session.flush()

    after = await public_client.get(url, headers={"If-None-Match": before})
    assert after.status_code == 200
    assert after.headers["etag"] != before
    assert len(after.json()["data"]["recent_frequency_changes"]) == 1
