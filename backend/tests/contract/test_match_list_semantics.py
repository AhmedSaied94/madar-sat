"""``/v1/matches`` and match-detail semantics on a scenario built per test (T017).

The scenario lives on 2026-12-05, away from the fixture snapshot's days, inside the
test's rolled-back transaction, so it doesn't depend on (or disturb) the fixture.
"""

from __future__ import annotations

import gzip
import hashlib
from dataclasses import dataclass
from datetime import UTC, date, datetime, timedelta

import pytest
from sqlalchemy import func, select

from app.db.models import (
    Channel,
    HiddenChannelName,
    Match,
    MatchChannel,
    MediaAsset,
    Satellite,
    Team,
)
from app.domain.regions import ASIA, EUROPE, MIDDLE_EAST, OTHER

DAY = date(2026, 12, 5)
WINDOW = {"from": "2026-12-05T00:00:00Z", "to": "2026-12-06T00:00:00Z"}
MEDIA_BASE = "https://media.example"


@pytest.fixture
def frozen_now() -> datetime:
    return datetime(2026, 12, 5, 18, 0, tzinfo=UTC)


async def _logo(session, label: str) -> MediaAsset:
    sha = hashlib.sha256(label.encode()).hexdigest()
    asset = MediaAsset(
        sha256=sha, kind="logo", path=f"logo/{sha[:2]}/{sha}.webp", mime="image/webp", bytes=1, width=1, height=1
    )
    session.add(asset)
    await session.flush()
    return asset


@dataclass
class Scenario:
    sats: dict[str, Satellite]
    channels: dict[str, Channel]
    matches: dict[str, Match]
    logos: dict[str, MediaAsset]


@pytest.fixture
async def scenario(session, frozen_now) -> Scenario:
    sats = {
        "nile": Satellite(slug="nilesat-7-0w", name_en="T Nilesat", name_ar="ت نايل سات", orbital_position=-7.0),
        "badr": Satellite(slug="badr-26-0e", name_en="T Badr", name_ar="ت عرب سات", orbital_position=26.0),
        "hot": Satellite(slug="test-hot-13-0e", name_en="T Hot", name_ar="ت هوت", orbital_position=13.0),
        "dvbt": Satellite(slug="test-dvbt", name_en="T DVB T2", name_ar="ت أرضي", kind="terrestrial"),
    }
    # The fixture snapshot may already hold the default-slug satellites: reuse them.
    for key in ("nile", "badr"):
        existing = await session.scalar(select(Satellite).where(Satellite.slug == sats[key].slug))
        if existing is not None:
            sats[key] = existing
    session.add_all(s for s in sats.values() if s.id is None)
    await session.flush()

    def sat(name: str, on: str, access: str, sort: int | None = None, **kw) -> Channel:
        return Channel(
            kind="satellite",
            name=name,
            satellite_id=sats[on].id,
            access=access,
            sort_order=sort,
            frequency_mhz=11843,
            polarization="H",
            symbol_rate=27500,
            locked_fields=[],
            **kw,
        )

    def platform(name: str, country: str) -> Channel:
        return Channel(kind="platform", name=name, country=country, access="free", locked_fields=[])

    channels = {
        "nile_free": sat("T Nile Free", "nile", "free", 5),
        "nile_enc": sat("T Nile Enc", "nile", "encrypted", 1),
        "badr_free": sat("T Badr Free", "badr", "free", 2),
        "hot_free": sat("T Hot Free", "hot", "free", 0),
        "hot_show": sat("T Hot Show", "hot", "free", 9, show_in_match=True),
        "terr": Channel(
            kind="terrestrial", name="T Terr", satellite_id=sats["dvbt"].id, access="free", locked_fields=[]
        ),
        "plat_fr": platform("T Plat FR", "فرنسا"),
        "plat_sa": platform("T Plat SA", "السعودية"),
        "plat_xx": platform("T Plat XX", "زحل"),
        "hidden_name": sat("T Hidden By Name", "nile", "free", 0),
        "deleted": sat("T Deleted", "nile", "free", 0, deleted_at=frozen_now - timedelta(days=1)),
    }
    session.add_all(channels.values())
    session.add(HiddenChannelName(name=await session.scalar(select(func.ar_normalize("T Hidden By Name")))))

    logos = {key: await _logo(session, key) for key in ("home_team", "away_team", "match_home")}
    home = Team(name="T Home", logo_asset_id=logos["home_team"].id)
    away = Team(name="T Away", logo_asset_id=logos["away_team"].id)
    session.add_all([home, away])
    await session.flush()

    def match(label: str, kickoff: datetime | None, **kw) -> Match:
        return Match(
            source="legacy",
            match_date=DAY,
            kickoff_at=kickoff,
            time_tbd=kickoff is None,
            competition_name="T Cup",
            home_team_id=home.id,
            home_team_name=f"{label} home",
            away_team_id=away.id,
            away_team_name=f"{label} away",
            locked_fields=[],
            **kw,
        )

    matches = {
        "A": match("A", datetime(2026, 12, 5, 19, 0, tzinfo=UTC), home_logo_asset_id=logos["match_home"].id),
        "B": match("B", datetime(2026, 12, 5, 17, 0, tzinfo=UTC)),  # clock-live at 18:00
        "C": match("C", datetime(2026, 12, 5, 12, 0, tzinfo=UTC)),  # clock-finished
        "D": match("D", None),  # TBD, anchored to Cairo noon of DAY
        "E": match("E", datetime(2026, 12, 5, 20, 0, tzinfo=UTC)),  # only invisible Nilesat links
    }
    session.add_all(matches.values())
    await session.flush()

    def link(m: str, c: str, hidden: bool = False) -> MatchChannel:
        return MatchChannel(match_id=matches[m].id, channel_id=channels[c].id, source="legacy", is_hidden=hidden)

    a_links = [k for k in channels if k not in ("hot_free",)]
    session.add_all([link("A", c) for c in a_links] + [link("A", "hot_free", hidden=True)])
    session.add_all([link("B", "hot_free"), link("C", "badr_free"), link("E", "hidden_name"), link("E", "deleted")])
    await session.commit()
    return Scenario(sats, channels, matches, logos)


async def _list(public_client, **params) -> dict[int, dict]:
    resp = await public_client.get("/v1/matches", params={**WINDOW, **params})
    assert resp.status_code == 200, resp.text
    return {m["id"]: m for m in resp.json()["data"]}


def _ids(sc: Scenario, *labels: str) -> set[int]:
    return {sc.matches[label].id for label in labels}


@pytest.mark.asyncio
async def test_satellite_ids_filters_on_visible_carriages_only(scenario, public_client):
    sc = scenario
    mine = _ids(sc, "A", "B", "C", "D", "E")
    nile = await _list(public_client, satellite_ids=str(sc.sats["nile"].id))
    assert set(nile) & mine == _ids(sc, "A")  # E's Nilesat links are hidden or deleted
    hot = await _list(public_client, satellite_ids=str(sc.sats["hot"].id))
    assert set(hot) & mine == _ids(sc, "A", "B")  # A via hot_show; its hot_free link is hidden
    both = await _list(public_client, satellite_ids=f"{sc.sats['hot'].id},{sc.sats['badr'].id}")
    assert set(both) & mine == _ids(sc, "A", "B", "C")


@pytest.mark.asyncio
async def test_my_satellite_ids_only_reorders_the_headline(scenario, public_client):
    sc = scenario
    plain = await _list(public_client)
    mine = await _list(public_client, my_satellite_ids=str(sc.sats["hot"].id))
    assert set(plain) == set(mine)
    for match_id in plain:
        assert plain[match_id]["broadcast"]["channel_count"] == mine[match_id]["broadcast"]["channel_count"]
        assert plain[match_id]["broadcast"]["has_free"] == mine[match_id]["broadcast"]["has_free"]

    a = sc.matches["A"].id
    # Default: Nilesat/Badr or show_in_match first, then free, then sort_order.
    assert [h["name"] for h in plain[a]["broadcast"]["headline"]] == ["T Badr Free", "T Nile Free"]
    # The user's satellite first (its hidden hot_free link never shows), then the rest.
    assert [h["name"] for h in mine[a]["broadcast"]["headline"]] == ["T Hot Show", "T Badr Free"]


@pytest.mark.asyncio
async def test_status_filter_uses_the_derived_status(scenario, public_client):
    sc = scenario
    mine = _ids(sc, "A", "B", "C", "D", "E")
    assert set(await _list(public_client, status="live")) & mine == _ids(sc, "B")
    assert set(await _list(public_client, status="finished")) & mine == _ids(sc, "C")
    assert set(await _list(public_client, status="scheduled")) & mine == _ids(sc, "A", "D", "E")
    live = (await _list(public_client, status="live"))[sc.matches["B"].id]
    assert (live["estimated"], live["score"], live["minute"], live["period"]) == (True, None, None, None)


@pytest.mark.asyncio
async def test_list_order_is_kickoff_then_id_with_tbd_last(scenario, public_client):
    sc = scenario
    order = [m for m in (await _list(public_client)) if m in _ids(sc, "A", "B", "C", "D", "E")]
    assert order == [sc.matches[label].id for label in ("C", "B", "A", "E", "D")]


@pytest.mark.asyncio
async def test_hidden_and_deleted_links_never_appear(scenario, public_client):
    sc = scenario
    invisible = {"T Hot Free", "T Hidden By Name", "T Deleted"}
    a = sc.matches["A"].id
    row = (await _list(public_client))[a]
    # 11 links on A, minus the per-match hidden, hidden-by-name and deleted ones.
    assert row["broadcast"]["channel_count"] == 8
    assert not invisible & {h["name"] for h in row["broadcast"]["headline"]}

    detail = (await public_client.get(f"/v1/matches/{a}")).json()["data"]
    shown = (
        {b["label"] for b in detail["broadcasts"]}
        | {c["name"] for c in detail["carriages"]}
        | {p["name"] for g in detail["platforms"] for p in g["items"]}
    )
    assert not invisible & shown
    e = (await public_client.get(f"/v1/matches/{sc.matches['E'].id}")).json()["data"]
    assert (e["broadcast"]["channel_count"], e["broadcasts"], e["carriages"]) == (0, [], [])


@pytest.mark.asyncio
async def test_logos_fall_back_to_the_team_logo(scenario, public_client):
    sc = scenario
    rows = await _list(public_client)
    a, b = rows[sc.matches["A"].id], rows[sc.matches["B"].id]
    assert a["home"]["logo"] == f"{MEDIA_BASE}/{sc.logos['match_home'].path}"  # the match's own logo wins
    assert a["away"]["logo"] == f"{MEDIA_BASE}/{sc.logos['away_team'].path}"
    assert b["home"]["logo"] == f"{MEDIA_BASE}/{sc.logos['home_team'].path}"
    assert b["away"]["logo"] == f"{MEDIA_BASE}/{sc.logos['away_team'].path}"


@pytest.mark.asyncio
async def test_detail_sections(scenario, public_client):
    sc = scenario
    detail = (await public_client.get(f"/v1/matches/{sc.matches['A'].id}")).json()["data"]

    # Preferred carriages (default satellites or show_in_match): free first, then sort_order.
    assert [b["label"] for b in detail["broadcasts"]] == ["T Badr Free", "T Nile Free", "T Hot Show", "T Nile Enc"]
    assert all(b["kind"] == "channel" for b in detail["broadcasts"])

    carriages = {c["name"]: c for c in detail["carriages"]}
    assert set(carriages) == {"T Nile Free", "T Nile Enc", "T Badr Free", "T Hot Show", "T Terr"}
    assert carriages["T Terr"]["kind"] == "terrestrial"
    assert carriages["T Nile Free"]["satellite"]["slug"] == "nilesat-7-0w"

    assert [g["region"] for g in detail["platforms"]] == [MIDDLE_EAST, EUROPE, OTHER]
    assert [[p["name"] for p in g["items"]] for g in detail["platforms"]] == [
        ["T Plat SA"],
        ["T Plat FR"],
        ["T Plat XX"],
    ]
    assert ASIA not in [g["region"] for g in detail["platforms"]]  # empty regions are omitted

    assert (detail["local_broadcaster_eg"], detail["events"], detail["lineups"]) == (None, [], None)


@pytest.mark.asyncio
async def test_a_heavy_day_gzips_within_60_kb(session, public_client):
    """SC-003 on a realistic busy day: 80 matches with 20 visible links each."""
    sat = Satellite(slug="test-size-sat", name_en="Size Sat", name_ar="قمر الحجم", orbital_position=5.0)
    session.add(sat)
    await session.flush()
    channels = [
        Channel(
            kind="satellite",
            name=f"Size Channel {i:02d} HD",
            satellite_id=sat.id,
            access="free",
            sort_order=i,
            frequency_mhz=11000 + i,
            polarization="V",
            symbol_rate=27500,
            locked_fields=[],
        )
        for i in range(20)
    ]
    session.add_all(channels)
    matches = [
        Match(
            source="legacy",
            match_date=DAY,
            kickoff_at=datetime(2026, 12, 5, 8, 0, tzinfo=UTC) + timedelta(minutes=10 * i),
            competition_name="دوري الاختبار الطويل الاسم",
            home_team_name=f"فريق المضيف رقم {i}",
            away_team_name=f"فريق الضيف رقم {i}",
            locked_fields=[],
        )
        for i in range(80)
    ]
    session.add_all(matches)
    await session.flush()
    session.add_all(MatchChannel(match_id=m.id, channel_id=c.id, source="legacy") for m in matches for c in channels)
    await session.commit()

    resp = await public_client.get("/v1/matches", params=WINDOW)
    assert resp.status_code == 200
    assert len(resp.json()["data"]) >= 80
    assert len(gzip.compress(resp.content)) <= 60_000
