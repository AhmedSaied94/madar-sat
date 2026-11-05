"""A9: rights holders (T006, contracts/admin-api.md)."""

from __future__ import annotations

from sqlalchemy import select

from app.db.models import Competition, RightsHolder, RightsHolderCarriage, RightsHolderFrequency, Satellite

from .helpers import ADMIN, audit_rows, changed_datasets, create, dataset_versions, if_match, make_asset

URL = f"{ADMIN}/rights-holders"


def _freq(mhz: int = 11013, primary: bool = True) -> dict:
    return {"frequency_mhz": mhz, "polarization": "H", "symbol_rate": 27500, "is_primary": primary}


async def _refs(session) -> tuple[int, int]:
    competition = Competition(name="بطولة حقوق الاختبار")
    satellite = Satellite(
        slug="rights-sat", name_en="Rights Sat", name_ar="قمر الحقوق", kind="satellite", orbital_position=-7.0
    )
    session.add_all([competition, satellite])
    await session.flush()
    return competition.id, satellite.id


def _body(competition_id: int, satellite_id: int, **overrides) -> dict:
    body = {
        "name": "حقوق الاختبار",
        "competition_ids": [competition_id],
        "carriages": [
            {
                "access": "encrypted",
                "beam": "wide",
                "package": "الباقة الذهبية",
                "satellite_ids": [satellite_id],
                "frequencies": [_freq()],
            }
        ],
    }
    return {**body, **overrides}


async def _carriage_ids(session, holder_id: int) -> list[int]:
    query = select(RightsHolderCarriage.id).where(RightsHolderCarriage.rights_holder_id == holder_id)
    return list((await session.scalars(query)).all())


async def test_create_returns_the_editor_shape_audits_and_bumps(editor_client, session):
    competition_id, satellite_id = await _refs(session)
    logo = await make_asset(session, "rights-logo")
    before = await dataset_versions(session)

    created = await create(editor_client, URL, _body(competition_id, satellite_id, logo_asset_id=logo))

    assert created["name"] == "حقوق الاختبار"
    assert created["logo_asset_id"] == logo
    assert created["logo"]
    assert created["competition_ids"] == [competition_id]
    [carriage] = created["carriages"]
    assert carriage["package"] == "الباقة الذهبية"
    assert carriage["satellite_ids"] == [satellite_id]
    assert carriage["frequencies"] == [_freq()]
    assert created["_etag"] == created["etag"]
    assert await changed_datasets(session, before) == {"rights_holders", "competitions"}
    [audit] = await audit_rows(session, "rights_holder", created["id"])
    assert audit.action == "create"
    assert audit.diff["competition_ids"] == [[], [competition_id]]


async def test_list_and_detail_have_etags_and_answer_304(editor_client, session):
    competition_id, satellite_id = await _refs(session)
    created = await create(editor_client, URL, _body(competition_id, satellite_id))

    listed = await editor_client.get(URL)
    assert listed.status_code == 200, listed.text
    row = next(item for item in listed.json()["data"] if item["id"] == created["id"])
    assert row["etag"] == created["etag"]
    assert row["competitions"] == ["بطولة حقوق الاختبار"]
    assert row["satellites"] == ["قمر الحقوق"]
    assert (await editor_client.get(URL, headers={"If-None-Match": listed.headers["etag"]})).status_code == 304

    detail = await editor_client.get(f"{URL}/{created['id']}")
    assert detail.status_code == 200, detail.text
    assert detail.headers["etag"] == created["etag"]
    not_modified = await editor_client.get(f"{URL}/{created['id']}", headers={"If-None-Match": detail.headers["etag"]})
    assert not_modified.status_code == 304

    assert (await editor_client.get(f"{URL}/99999999")).status_code == 404


async def test_the_list_is_ordered_by_sort_order_then_name(editor_client, session):
    session.add_all(
        [
            RightsHolder(name="ي اختبار الترتيب", sort_order=1),
            RightsHolder(name="أ اختبار الترتيب", sort_order=2),
            RightsHolder(name="ب اختبار الترتيب", sort_order=2),
        ]
    )
    await session.flush()

    names = [row["name"] for row in (await editor_client.get(URL)).json()["data"] if "اختبار الترتيب" in row["name"]]

    assert names == ["ي اختبار الترتيب", "أ اختبار الترتيب", "ب اختبار الترتيب"]


async def test_patch_replaces_both_lists_together(editor_client, session):
    competition_id, satellite_id = await _refs(session)
    other = Competition(name="بطولة ثانية للحقوق")
    session.add(other)
    await session.flush()
    created = await create(editor_client, URL, _body(competition_id, satellite_id))
    before = await dataset_versions(session)

    response = await editor_client.patch(
        f"{URL}/{created['id']}",
        json={
            "competition_ids": [other.id],
            "carriages": [
                {"access": "free", "satellite_ids": [satellite_id], "frequencies": [_freq(12000)]},
                {"access": "encrypted", "satellite_ids": [], "frequencies": []},
            ],
        },
        headers=if_match(created["_etag"]),
    )

    assert response.status_code == 200, response.text
    data = response.json()["data"]
    assert data["competition_ids"] == [other.id]
    assert [carriage["access"] for carriage in data["carriages"]] == ["free", "encrypted"]
    assert data["carriages"][0]["frequencies"] == [_freq(12000)]
    assert data["etag"] != created["_etag"]
    assert response.headers["etag"] == data["etag"]
    assert await changed_datasets(session, before) == {"rights_holders", "competitions"}
    audits = await audit_rows(session, "rights_holder", created["id"])
    assert audits[-1].action == "update"
    assert audits[-1].diff["competition_ids"] == [[competition_id], [other.id]]
    frequencies = (await session.scalars(select(RightsHolderFrequency.frequency_mhz))).all()
    assert 11013 not in frequencies


async def test_a_patch_of_only_the_name_keeps_the_lists(editor_client, session):
    competition_id, satellite_id = await _refs(session)
    created = await create(editor_client, URL, _body(competition_id, satellite_id))

    response = await editor_client.patch(
        f"{URL}/{created['id']}", json={"name": "اسم جديد"}, headers=if_match(created["_etag"])
    )

    data = response.json()["data"]
    assert data["name"] == "اسم جديد"
    assert data["competition_ids"] == [competition_id]
    assert len(data["carriages"]) == 1


async def test_a_patch_that_changes_nothing_writes_nothing(editor_client, session):
    competition_id, satellite_id = await _refs(session)
    body = _body(competition_id, satellite_id)
    created = await create(editor_client, URL, body)
    carriage_ids = await _carriage_ids(session, created["id"])
    before = await dataset_versions(session)

    response = await editor_client.patch(f"{URL}/{created['id']}", json=body, headers=if_match(created["_etag"]))

    assert response.status_code == 200, response.text
    assert response.json()["data"]["etag"] == created["_etag"]
    assert await changed_datasets(session, before) == set()
    assert len(await audit_rows(session, "rights_holder", created["id"])) == 1
    assert await _carriage_ids(session, created["id"]) == carriage_ids


async def test_each_carriage_with_frequencies_needs_exactly_one_primary(editor_client, session):
    competition_id, satellite_id = await _refs(session)
    for frequencies in ([_freq(primary=False)], [_freq(11000), _freq(12000)]):
        body = _body(competition_id, satellite_id)
        body["carriages"][0]["frequencies"] = frequencies
        response = await editor_client.post(URL, json=body)
        assert response.status_code == 422, response.text
        assert response.json()["meta"]["errors"][0]["type"] == "exactly_one_primary"


async def test_bad_references_and_ranges_are_refused(editor_client, session):
    competition_id, satellite_id = await _refs(session)

    assert (await editor_client.post(URL, json=_body(99999999, satellite_id))).status_code == 422
    assert (await editor_client.post(URL, json=_body(competition_id, 99999999))).status_code == 422
    body = _body(competition_id, satellite_id)
    body["carriages"][0]["frequencies"] = [_freq(99)]
    response = await editor_client.post(URL, json=body)
    assert response.status_code == 422
    assert response.json()["meta"]["errors"][0]["type"] == "out_of_range"


async def test_a_card_sharing_name_is_refused(editor_client, session):
    competition_id, satellite_id = await _refs(session)

    response = await editor_client.post(URL, json=_body(competition_id, satellite_id, name="beIN VIP"))

    assert response.status_code == 422


async def test_writes_need_the_current_version(editor_client, session):
    competition_id, satellite_id = await _refs(session)
    created = await create(editor_client, URL, _body(competition_id, satellite_id))
    path = f"{URL}/{created['id']}"

    assert (await editor_client.patch(path, json={"name": "جديد"})).status_code == 428

    saved = await editor_client.patch(path, json={"name": "جديد"}, headers=if_match(created["_etag"]))
    assert saved.status_code == 200
    stale = await editor_client.patch(path, json={"name": "أجد"}, headers=if_match(created["_etag"]))
    assert stale.status_code == 409
    assert stale.json()["error"]["code"] == "edit_conflict"


async def test_only_an_admin_can_delete(editor_client, admin_client, session):
    competition_id, satellite_id = await _refs(session)
    created = await create(editor_client, URL, _body(competition_id, satellite_id))
    path = f"{URL}/{created['id']}"

    assert (await editor_client.delete(path, headers=if_match(created["_etag"]))).status_code == 403
    assert (await admin_client.delete(path)).status_code == 428
    before = await dataset_versions(session)
    deleted = await admin_client.delete(path, headers=if_match(created["_etag"]))

    assert deleted.status_code == 200, deleted.text
    assert (await admin_client.get(path)).status_code == 404
    assert await changed_datasets(session, before) == {"rights_holders", "competitions"}
    assert (await audit_rows(session, "rights_holder", created["id"]))[-1].action == "delete"


async def test_reorder_sets_sort_order_and_rejects_a_stale_item(editor_client, session):
    competition_id, satellite_id = await _refs(session)
    first = await create(editor_client, URL, _body(competition_id, satellite_id, name="الأول"))
    second = await create(editor_client, URL, _body(competition_id, satellite_id, name="الثاني"))
    before = await dataset_versions(session)

    response = await editor_client.post(
        f"{URL}/reorder",
        json={
            "items": [
                {"id": second["id"], "if_match": second["_etag"]},
                {"id": first["id"], "if_match": first["_etag"]},
            ]
        },
    )

    assert response.status_code == 200, response.text
    updated = {item["id"]: item["etag"] for item in response.json()["data"]["updated"]}
    assert await changed_datasets(session, before) == {"rights_holders", "competitions"}
    detail = (await editor_client.get(f"{URL}/{second['id']}")).json()["data"]
    assert detail["sort_order"] == 1
    assert detail["etag"] == updated[second["id"]]

    stale = await editor_client.post(
        f"{URL}/reorder", json={"items": [{"id": first["id"], "if_match": first["_etag"]}]}
    )
    assert stale.status_code == 409
    assert stale.json()["meta"]["stale_ids"] == [first["id"]]
