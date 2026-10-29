"""Semantics of /v1/matches and match detail against the loaded fixture (T017)."""

from __future__ import annotations

import gzip

import pytest


async def _matches(public_client, **params):
    resp = await public_client.get("/v1/matches", params=params)
    assert resp.status_code == 200, resp.text
    return resp.json()["data"]


@pytest.mark.asyncio
async def test_window_and_tbd_ordering(public_client):
    data = await _matches(public_client, **{"from": "2026-10-28T00:00:00Z", "to": "2026-10-29T00:00:00Z"})
    ids = [m["id"] for m in data]
    assert ids  # m-1, m-amb, m-unmarked, m-tbd (m-1b merged into m-1)
    # TBD match sorts last.
    tbd = [m for m in data if m["time_tbd"]]
    assert tbd
    assert ids[-1] == tbd[0]["id"]
    # Non-TBD matches are ordered by kickoff_at.
    non_tbd = [m for m in data if not m["time_tbd"]]
    kicks = [m["kickoff_at"] for m in non_tbd]
    assert kicks == sorted(kicks)


@pytest.mark.asyncio
async def test_satellite_ids_filter(public_client):
    # The Nilesat satellite id filters to matches carried on Nilesat.
    from sqlalchemy import text

    from app.db.session import SyncSession

    with SyncSession() as s:
        nilesat_id = s.execute(text("SELECT id FROM satellites WHERE slug='nilesat-7-0w'")).scalar_one()

    data = await _matches(
        public_client,
        **{"from": "2026-10-28T00:00:00Z", "to": "2026-10-29T00:00:00Z", "satellite_ids": str(nilesat_id)},
    )
    # m-1 has ch-nilesat-free on Nilesat; m-amb has no channels.
    names = {m["home"]["name"] for m in data}
    assert "الأهلي" in names


@pytest.mark.asyncio
async def test_hidden_links_never_appear(public_client):
    data = await _matches(public_client, **{"from": "2026-10-28T00:00:00Z", "to": "2026-10-29T00:00:00Z"})
    m1 = next(m for m in data if m["home"]["name"] == "الأهلي" and not m["time_tbd"] and m["away"]["name"] == "الزمالك")
    headline_names = [h["name"] for h in m1["broadcast"]["headline"]]
    assert "beIN SPORTS EN 1" not in headline_names  # hidden by name + per match
    # Visible links: ch-cyr + ch-nilesat-free + ch-badr-enc (from the merged
    # duplicate listing); ch-hidden is excluded.
    assert m1["broadcast"]["channel_count"] == 3


@pytest.mark.asyncio
async def test_estimated_rows_have_null_score(public_client):
    data = await _matches(public_client, **{"from": "2026-10-28T00:00:00Z", "to": "2026-10-29T00:00:00Z"})
    # m-unmarked (02:30 → 14:30 Cairo) is finished by the frozen now (18:00Z).
    finished = [m for m in data if m["status"] == "finished"]
    assert finished
    for m in finished:
        assert m["estimated"] is True
        assert m["score"] is None
        assert m["minute"] is None
        assert m["period"] is None


@pytest.mark.asyncio
async def test_match_detail_sections(public_client):
    data = await _matches(public_client, **{"from": "2026-10-28T00:00:00Z", "to": "2026-10-29T00:00:00Z"})
    m1 = next(m for m in data if m["away"]["name"] == "الزمالك")
    resp = await public_client.get(f"/v1/matches/{m1['id']}")
    assert resp.status_code == 200
    detail = resp.json()["data"]
    assert detail["local_broadcaster_eg"] is None
    assert detail["events"] == []
    assert detail["lineups"] is None
    # broadcasts + carriages + platforms keys exist.
    assert "broadcasts" in detail
    assert "carriages" in detail
    assert "platforms" in detail
    # Carriages cover the satellite link (ch-cyr), not the platform or hidden ones.
    carriage_ids = {c["id"] for c in detail["carriages"]}
    assert carriage_ids


@pytest.mark.asyncio
async def test_custom_broadcasts_come_first_with_their_own_commentators(session, public_client):
    from sqlalchemy import delete, select

    from app.db.models import Commentator, Match, MatchCustomBroadcast

    match = (await session.scalars(select(Match).where(Match.away_team_name == "الزمالك").limit(1))).one()
    # Replace whatever slots the fixture gave this match (undone with the test's transaction).
    await session.execute(delete(MatchCustomBroadcast).where(MatchCustomBroadcast.match_id == match.id))
    slot1_voice = Commentator(name="معلق الحدث الأول")
    slot2_voice = Commentator(name="معلق الحدث الثاني")
    session.add_all([slot1_voice, slot2_voice])
    await session.flush()
    # Slot 1's commentator is the match commentator, who is on no channel link.
    match.commentator_id = slot1_voice.id
    session.add_all(
        [
            MatchCustomBroadcast(match_id=match.id, slot=2, label="Custom Two", commentator_id=slot2_voice.id),
            MatchCustomBroadcast(match_id=match.id, slot=1, label="Custom One", commentator_id=slot1_voice.id),
        ]
    )
    await session.commit()

    resp = await public_client.get(f"/v1/matches/{match.id}")
    assert resp.status_code == 200, resp.text
    broadcasts = resp.json()["data"]["broadcasts"]
    assert [b["label"] for b in broadcasts[:2]] == ["Custom One", "Custom Two"]
    assert all(b["kind"] == "custom" for b in broadcasts[:2])
    assert [c["name"] for c in broadcasts[0]["commentators"]] == ["معلق الحدث الأول"]
    assert [c["name"] for c in broadcasts[1]["commentators"]] == ["معلق الحدث الثاني"]
    assert all(b["kind"] == "channel" for b in broadcasts[2:])


@pytest.mark.asyncio
async def test_match_list_payload_is_small(public_client):
    resp = await public_client.get("/v1/matches", params={"from": "2026-10-28T00:00:00Z", "to": "2026-10-29T00:00:00Z"})
    assert resp.status_code == 200
    compressed = gzip.compress(resp.content)
    assert len(compressed) <= 60000
