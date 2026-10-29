"""Semantics of the channel, satellite, catalog and team endpoints against the fixture."""

from __future__ import annotations

from datetime import date, timedelta

import pytest
from sqlalchemy import select

from app.db.models import (
    Channel,
    Match,
    RightsHolder,
    RightsHolderCarriage,
    RightsHolderCarriageSatellite,
    RightsHolderFrequency,
    Satellite,
    Team,
)


async def _satellite(session, slug: str, position: float) -> Satellite:
    sat = Satellite(slug=slug, name_en=slug, name_ar=slug, orbital_position=position)
    session.add(sat)
    await session.flush()
    return sat


@pytest.mark.asyncio
async def test_channel_search_never_treats_symbols_as_wildcards(session, public_client):
    sat = await _satellite(session, "test-like-1-0e", 1.0)
    session.add_all(
        [
            Channel(
                kind="satellite",
                name="Sport 100% HD",
                satellite_id=sat.id,
                access="free",
                frequency_mhz=12000,
                polarization="H",
                symbol_rate=27500,
                locked_fields=[],
            ),
            Channel(kind="satellite", name="A_B", satellite_id=sat.id, access="free", locked_fields=[]),
            Channel(kind="satellite", name="AXB", satellite_id=sat.id, access="free", locked_fields=[]),
            Channel(kind="satellite", name="الجزيرة الرياضية", satellite_id=sat.id, access="free", locked_fields=[]),
        ]
    )
    await session.commit()

    async def names(q: str) -> set[str]:
        resp = await public_client.get(f"/v1/satellites/{sat.id}/channels", params={"q": q})
        assert resp.status_code == 200, resp.text
        return {c["name"] for c in resp.json()["data"]}

    # A query of symbols alone normalizes to nothing: it matches no channel, not all of them.
    assert await names("%") == set()
    assert await names("_") == set()
    assert await names("1%") == {"Sport 100% HD"}  # by name ("1"), not as a frequency wildcard
    assert await names("A_B") == {"A_B"}  # "_" is a space after normalization, never "any char"
    assert await names("الْجَزِيرَة") == {"الجزيرة الرياضية"}  # Arabic-insensitive


@pytest.mark.asyncio
async def test_channel_search_matches_a_frequency_digit_prefix(session, public_client):
    sat = await _satellite(session, "test-freq-2-0e", 2.0)
    session.add_all(
        [
            Channel(
                kind="satellite",
                name="Alpha",
                satellite_id=sat.id,
                access="free",
                frequency_mhz=11843,
                polarization="H",
                symbol_rate=27500,
                locked_fields=[],
            ),
            Channel(
                kind="satellite",
                name="Beta",
                satellite_id=sat.id,
                access="free",
                frequency_mhz=12054,
                polarization="V",
                symbol_rate=27500,
                locked_fields=[],
            ),
        ]
    )
    await session.commit()

    resp = await public_client.get(f"/v1/satellites/{sat.id}/channels", params={"q": "118"})
    assert [c["name"] for c in resp.json()["data"]] == ["Alpha"]


@pytest.mark.asyncio
async def test_rights_holder_detail_groups_satellites_and_frequencies_per_carriage(session, public_client):
    west, east = await _satellite(session, "test-rh-west", -7.0), await _satellite(session, "test-rh-east", 26.0)
    holder = RightsHolder(name="Test Rights")
    session.add(holder)
    await session.flush()
    first = RightsHolderCarriage(rights_holder_id=holder.id, position=1, access="encrypted", beam="wide")
    second = RightsHolderCarriage(rights_holder_id=holder.id, position=2, access="free", beam=None)
    session.add_all([first, second])
    await session.flush()
    session.add_all(
        [
            RightsHolderCarriageSatellite(carriage_id=first.id, satellite_id=east.id),
            RightsHolderCarriageSatellite(carriage_id=first.id, satellite_id=west.id),
            RightsHolderCarriageSatellite(carriage_id=second.id, satellite_id=east.id),
            RightsHolderFrequency(carriage_id=first.id, frequency_mhz=11000, polarization="H", symbol_rate=27500),
            RightsHolderFrequency(
                carriage_id=first.id, frequency_mhz=12000, polarization="V", symbol_rate=27500, is_primary=True
            ),
        ]
    )
    await session.commit()

    resp = await public_client.get(f"/v1/rights-holders/{holder.id}")
    assert resp.status_code == 200, resp.text
    first_out, second_out = resp.json()["data"]["carriages"]
    assert [s["slug"] for s in first_out["satellites"]] == ["test-rh-west", "test-rh-east"]  # by orbital position
    assert [(f["mhz"], f["is_primary"]) for f in first_out["frequencies"]] == [(12000, True), (11000, False)]
    assert [s["slug"] for s in second_out["satellites"]] == ["test-rh-east"]
    assert second_out["frequencies"] == []


@pytest.mark.asyncio
async def test_team_upcoming_keeps_tbd_matches_only_until_their_day_ends(session, public_client, frozen_now):
    team = Team(name="فريق الاختبار")
    session.add(team)
    await session.flush()
    today = date(2026, 10, 28)  # frozen_now's Cairo date

    def tbd(label: str, day: date) -> Match:
        return Match(
            source="legacy",
            match_date=day,
            kickoff_at=None,
            time_tbd=True,
            competition_name="كأس",
            home_team_id=team.id,
            home_team_name=team.name,
            away_team_name=label,
            locked_fields=[],
        )

    session.add_all([tbd("أمس", today - timedelta(days=1)), tbd("اليوم", today), tbd("غدا", today + timedelta(days=1))])
    await session.commit()

    resp = await public_client.get(f"/v1/teams/{team.id}")
    assert resp.status_code == 200, resp.text
    assert {m["away"]["name"] for m in resp.json()["data"]["upcoming"]} == {"اليوم", "غدا"}


@pytest.mark.asyncio
async def test_platform_channel_detail_has_no_satellite(session, public_client):
    platform_ids = (await session.scalars(select(Channel.id).where(Channel.kind == "platform"))).all()
    assert platform_ids, "fixture has no platform channel"
    for channel_id in platform_ids:
        resp = await public_client.get(f"/v1/channels/{channel_id}")
        assert resp.status_code == 200, resp.text
        data = resp.json()["data"]
        assert data["kind"] == "platform"
        assert data["satellite"] is None
        assert data["frequency"] is None


@pytest.mark.asyncio
async def test_channel_other_carriages_may_include_platforms(session, public_client):
    """A satellite channel whose name also exists as a platform lists it without failing."""
    sat_channel = (
        await session.scalars(select(Channel).where(Channel.kind == "satellite", Channel.deleted_at.is_(None)).limit(1))
    ).one()
    session.add(Channel(kind="platform", name=sat_channel.name, country="فرنسا", access="free", locked_fields=[]))
    await session.commit()

    resp = await public_client.get(f"/v1/channels/{sat_channel.id}")
    assert resp.status_code == 200, resp.text
    others = resp.json()["data"]["other_carriages"]
    assert any(o["kind"] == "platform" and o["satellite"] is None for o in others)
