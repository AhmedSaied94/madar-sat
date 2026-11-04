"""A13's queue of names the importers couldn't match (T005, contracts/admin-api.md, research R9)."""

from __future__ import annotations

from datetime import timedelta

from sqlalchemy import select

from app.db.models import Channel, Competition, CompetitionAlias, Team, TeamAlias, UnresolvedName
from app.domain.arabic import ar_normalize

from .helpers import ADMIN, audit_rows, changed_datasets, dataset_versions, if_match

URL = f"{ADMIN}/unresolved-names"


async def _name(session, now, name: str, *, kind="team", source="yallakora", competition="", minutes_ago=0, **fields):
    row = UnresolvedName(
        source=source,
        kind=kind,
        name=name,
        name_norm=ar_normalize(name),
        competition_norm=ar_normalize(competition),
        context={"home": name, "away": "فريق", "competition": competition, "match_id": 1, "kickoff_at": None},
        seen_count=1,
        first_seen_at=now - timedelta(minutes=minutes_ago),
        last_seen_at=now - timedelta(minutes=minutes_ago),
        **fields,
    )
    session.add(row)
    await session.flush()
    return row


async def _team(session, name: str, competition: Competition | None = None) -> Team:
    team = Team(name=name, primary_competition_id=competition.id if competition else None)
    session.add(team)
    await session.flush()
    return team


async def _listed(client, row_id: int) -> dict:
    response = await client.get(URL, params={"limit": 100})
    assert response.status_code == 200, response.text
    return next(item for item in response.json()["data"] if item["id"] == row_id)


async def test_the_list_filters_orders_and_pages(editor_client, session, frozen_now):
    older = await _name(session, frozen_now, "الأول", minutes_ago=10)
    newer = await _name(session, frozen_now, "الثاني", minutes_ago=1)
    other = await _name(session, frozen_now, "قناة", kind="channel", source="livesoccertv", minutes_ago=2)
    ignored = await _name(session, frozen_now, "متجاهل", state="ignored", minutes_ago=3)

    first = (await editor_client.get(URL, params={"limit": 2})).json()
    assert [row["id"] for row in first["data"]] == [newer.id, other.id]
    assert first["meta"]["open_count"] == 3
    second = (await editor_client.get(URL, params={"limit": 2, "cursor": first["meta"]["next_cursor"]})).json()
    assert [row["id"] for row in second["data"]] == [older.id]
    assert second["meta"]["next_cursor"] is None

    by_kind = (await editor_client.get(URL, params={"kind": "channel"})).json()["data"]
    assert [row["id"] for row in by_kind] == [other.id]
    by_source = (await editor_client.get(URL, params={"source": "livesoccertv"})).json()["data"]
    assert [row["id"] for row in by_source] == [other.id]
    by_state = (await editor_client.get(URL, params={"state": "ignored"})).json()["data"]
    assert [row["id"] for row in by_state] == [ignored.id]


async def test_a_bad_limit_or_cursor_is_refused(editor_client):
    assert (await editor_client.get(URL, params={"limit": 101})).status_code == 422
    assert (await editor_client.get(URL, params={"cursor": "!!!"})).status_code == 422


async def test_suggestions_put_exact_first_and_stop_at_three(editor_client, session, frozen_now):
    competition = Competition(name="الدوري القطري للاختبار")
    session.add(competition)
    await session.flush()
    exact = await _team(session, "نادي الوكرة التجريبي", competition)
    await _team(session, "نادي الوكرة التجريبي الأول")
    await _team(session, "نادي الوكرة التجريبي الثاني")
    await _team(session, "نادي الوكرة التجريبي الثالث")
    await _team(session, "مختلف تماما كليا")
    row = await _name(session, frozen_now, "نادي الوكرة التجريبي")

    suggestions = (await _listed(editor_client, row.id))["suggestions"]

    assert len(suggestions) == 3
    assert suggestions[0] == {
        "id": exact.id,
        "name": "نادي الوكرة التجريبي",
        "detail": "الدوري القطري للاختبار",
        "confidence": 100,
        "exact": True,
    }
    assert all(item["exact"] is False and 30 <= item["confidence"] < 100 for item in suggestions[1:])


async def test_a_latin_name_gets_no_arabic_suggestion(editor_client, session, frozen_now):
    await _team(session, "ناساف قرشي")
    row = await _name(session, frozen_now, "Nasaf Qarshi")

    assert (await _listed(editor_client, row.id))["suggestions"] == []


async def test_suggestions_search_the_row_kind(editor_client, session, frozen_now):
    competition = Competition(name="كأس الاختبار الكبرى")
    channel = Channel(kind="platform", name="قناة الاختبار الكبرى", locked_fields=[])
    hidden = Channel(
        kind="platform", name="قناة الاختبار الكبرى 2", locked_fields=[], placeholder_source="livesoccertv"
    )
    session.add_all([competition, channel, hidden])
    await session.flush()
    for_competition = await _name(session, frozen_now, "كأس الاختبار الكبرى", kind="competition")
    for_channel = await _name(session, frozen_now, "قناة الاختبار الكبرى", kind="channel")

    assert (await _listed(editor_client, for_competition.id))["suggestions"][0]["id"] == competition.id
    channel_suggestions = (await _listed(editor_client, for_channel.id))["suggestions"]
    assert channel_suggestions[0]["id"] == channel.id
    assert hidden.id not in [item["id"] for item in channel_suggestions]


async def test_map_writes_the_alias_audits_and_bumps(editor_client, session, frozen_now):
    team = await _team(session, "فريق الربط")
    row = await _name(session, frozen_now, "Link Team", competition="دوري الربط")
    etag = (await _listed(editor_client, row.id))["etag"]
    before = await dataset_versions(session)

    response = await editor_client.post(
        f"{URL}/{row.id}/map", json={"target_id": team.id, "scope_to_competition": True}, headers=if_match(etag)
    )

    assert response.status_code == 200, response.text
    data = response.json()["data"]
    assert data["state"] == "mapped"
    assert data["etag"] != etag
    alias = await session.get(TeamAlias, ("yallakora", ar_normalize("Link Team"), ar_normalize("دوري الربط")))
    assert alias is not None and alias.team_id == team.id and alias.created_by == editor_client.admin.id
    assert await changed_datasets(session, before) == {"unresolved_names"}
    [audit] = await audit_rows(session, "unresolved_name", row.id)
    assert audit.diff["state"] == ["open", "mapped"]


async def test_map_without_scope_writes_an_any_competition_alias(editor_client, session, frozen_now):
    team = await _team(session, "فريق بلا نطاق")
    row = await _name(session, frozen_now, "No Scope", competition="دوري ما")
    etag = (await _listed(editor_client, row.id))["etag"]

    response = await editor_client.post(f"{URL}/{row.id}/map", json={"target_id": team.id}, headers=if_match(etag))

    assert response.status_code == 200, response.text
    assert await session.get(TeamAlias, ("yallakora", ar_normalize("No Scope"), "")) is not None


async def test_map_with_created_sets_the_created_state(editor_client, session, frozen_now):
    competition = Competition(name="بطولة جديدة للاختبار")
    session.add(competition)
    await session.flush()
    row = await _name(session, frozen_now, "New Cup", kind="competition")
    etag = (await _listed(editor_client, row.id))["etag"]

    response = await editor_client.post(
        f"{URL}/{row.id}/map", json={"target_id": competition.id, "created": True}, headers=if_match(etag)
    )

    assert response.status_code == 200, response.text
    assert response.json()["data"]["state"] == "created"
    alias = await session.get(CompetitionAlias, ("yallakora", ar_normalize("New Cup")))
    assert alias is not None and alias.competition_id == competition.id


async def test_scope_is_required_when_several_teams_share_the_name(editor_client, session, frozen_now):
    first = await _team(session, "الاسم المشترك للاختبار")
    await _team(session, "الاسم المشترك للاختبار")
    row = await _name(session, frozen_now, "الاسم المشترك للاختبار", competition="دوري")
    etag = (await _listed(editor_client, row.id))["etag"]

    refused = await editor_client.post(f"{URL}/{row.id}/map", json={"target_id": first.id}, headers=if_match(etag))
    assert refused.status_code == 422
    assert refused.json()["meta"]["errors"][0]["loc"] == ["body", "scope_to_competition"]

    accepted = await editor_client.post(
        f"{URL}/{row.id}/map", json={"target_id": first.id, "scope_to_competition": True}, headers=if_match(etag)
    )
    assert accepted.status_code == 200, accepted.text


async def test_an_alias_with_another_target_conflicts(editor_client, session, frozen_now):
    taken = await _team(session, "فريق محجوز")
    other = await _team(session, "فريق آخر")
    session.add(TeamAlias(source="yallakora", alias_norm=ar_normalize("Taken"), competition_norm="", team_id=taken.id))
    row = await _name(session, frozen_now, "Taken")
    etag = (await _listed(editor_client, row.id))["etag"]

    response = await editor_client.post(f"{URL}/{row.id}/map", json={"target_id": other.id}, headers=if_match(etag))

    assert response.status_code == 409
    assert response.json()["error"]["code"] == "alias_conflict"
    current = await session.scalar(
        select(UnresolvedName.state).where(UnresolvedName.id == row.id).execution_options(populate_existing=True)
    )
    assert current == "open"


async def test_the_same_alias_again_is_accepted(editor_client, session, frozen_now):
    team = await _team(session, "فريق مكرر")
    session.add(TeamAlias(source="yallakora", alias_norm=ar_normalize("Again"), competition_norm="", team_id=team.id))
    row = await _name(session, frozen_now, "Again")
    etag = (await _listed(editor_client, row.id))["etag"]

    response = await editor_client.post(f"{URL}/{row.id}/map", json={"target_id": team.id}, headers=if_match(etag))

    assert response.status_code == 200, response.text


async def test_an_unknown_target_is_404(editor_client, session, frozen_now):
    row = await _name(session, frozen_now, "Ghost")
    etag = (await _listed(editor_client, row.id))["etag"]

    response = await editor_client.post(f"{URL}/{row.id}/map", json={"target_id": 99999999}, headers=if_match(etag))

    assert response.status_code == 404
    assert response.json()["error"]["code"] == "team_not_found"


async def test_a_row_that_is_not_open_conflicts(editor_client, session, frozen_now):
    team = await _team(session, "فريق مغلق")
    row = await _name(session, frozen_now, "Closed")
    etag = (await _listed(editor_client, row.id))["etag"]
    ignored = await editor_client.post(f"{URL}/{row.id}/ignore", headers=if_match(etag))
    assert ignored.status_code == 200, ignored.text
    new_etag = ignored.json()["data"]["etag"]

    with_stale = await editor_client.post(f"{URL}/{row.id}/map", json={"target_id": team.id}, headers=if_match(etag))
    with_fresh = await editor_client.post(
        f"{URL}/{row.id}/map", json={"target_id": team.id}, headers=if_match(new_etag)
    )
    again = await editor_client.post(f"{URL}/{row.id}/ignore", headers=if_match(new_etag))

    assert with_stale.status_code == 409 and with_stale.json()["error"]["code"] == "edit_conflict"
    assert with_fresh.status_code == 409 and with_fresh.json()["error"]["code"] == "edit_conflict"
    assert again.status_code == 409 and again.json()["error"]["code"] == "edit_conflict"


async def test_writes_need_if_match(editor_client, session, frozen_now):
    row = await _name(session, frozen_now, "No Header")

    assert (await editor_client.post(f"{URL}/{row.id}/map", json={"target_id": 1})).status_code == 428
    assert (await editor_client.post(f"{URL}/{row.id}/ignore")).status_code == 428


async def test_ignore_audits_and_bumps(editor_client, session, frozen_now):
    row = await _name(session, frozen_now, "Ignore Me")
    etag = (await _listed(editor_client, row.id))["etag"]
    before = await dataset_versions(session)

    response = await editor_client.post(f"{URL}/{row.id}/ignore", headers=if_match(etag))

    assert response.status_code == 200, response.text
    assert response.json()["data"]["state"] == "ignored"
    assert await changed_datasets(session, before) == {"unresolved_names"}
    [audit] = await audit_rows(session, "unresolved_name", row.id)
    assert audit.diff["state"] == ["open", "ignored"]


async def test_a_new_sighting_does_not_make_the_copy_stale(editor_client, session, frozen_now):
    row = await _name(session, frozen_now, "Seen Again")
    etag = (await _listed(editor_client, row.id))["etag"]
    row.seen_count = 5
    row.last_seen_at = frozen_now + timedelta(minutes=1)
    await session.flush()

    response = await editor_client.post(f"{URL}/{row.id}/ignore", headers=if_match(etag))

    assert response.status_code == 200, response.text


async def test_the_list_etag_follows_the_dataset(editor_client, session, frozen_now):
    row = await _name(session, frozen_now, "Etag Row")
    first = await editor_client.get(URL)
    assert (await editor_client.get(URL, headers={"If-None-Match": first.headers["etag"]})).status_code == 304

    etag = (await _listed(editor_client, row.id))["etag"]
    await editor_client.post(f"{URL}/{row.id}/ignore", headers=if_match(etag))

    after = await editor_client.get(URL, headers={"If-None-Match": first.headers["etag"]})
    assert after.status_code == 200
    assert after.headers["etag"] != first.headers["etag"]


async def test_an_editor_is_required(anon_admin_client, session, frozen_now):
    row = await _name(session, frozen_now, "No Auth")

    assert (await anon_admin_client.get(URL)).status_code == 401
    assert (await anon_admin_client.post(f"{URL}/{row.id}/ignore")).status_code == 401
