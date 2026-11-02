"""A6/A7: one request sets the whole new order (T027)."""

from __future__ import annotations

import pytest
from sqlalchemy import select

from app.db.models import AuditLog, Competition, DatasetVersion, Satellite
from tests.admin.helpers import if_match


async def _competition(session, name: str, priority: int | None) -> Competition:
    row = Competition(name=name, priority=priority)
    session.add(row)
    await session.flush()
    return row


async def _satellite(session, slug: str, priority: int | None) -> Satellite:
    row = Satellite(slug=slug, name_en=slug, name_ar="قمر", kind="satellite", orbital_position=1.0, priority=priority)
    session.add(row)
    await session.flush()
    return row


async def _etag(client, path: str) -> str:
    response = await client.get(path)
    assert response.status_code == 200, response.text
    return response.headers["etag"]


async def _version(session, name: str) -> int:
    return int((await session.execute(select(DatasetVersion.version).where(DatasetVersion.name == name))).scalar_one())


async def test_competition_order_sets_priorities_audits_and_bumps(editor_client, session):
    first = await _competition(session, "order-a", 5)
    second = await _competition(session, "order-b", 6)
    etags = {
        "a": await _etag(editor_client, f"/admin/api/competitions/{first.id}"),
        "b": await _etag(editor_client, f"/admin/api/competitions/{second.id}"),
    }
    before = (await _version(session, "competitions"), await _version(session, "matches"))

    response = await editor_client.put(
        "/admin/api/competitions/order",
        json={"items": [{"id": second.id, "if_match": etags["b"]}, {"id": first.id, "if_match": etags["a"]}]},
    )

    assert response.status_code == 200, response.text
    assert [row["id"] for row in response.json()["data"]["updated"]] == [second.id, first.id]
    await session.refresh(first)
    await session.refresh(second)
    assert (second.priority, first.priority) == (1, 2)
    assert await _version(session, "competitions") == before[0] + 1
    assert await _version(session, "matches") == before[1] + 1
    audits = (
        await session.scalars(
            select(AuditLog).where(
                AuditLog.entity == "competition",
                AuditLog.action == "update",
                AuditLog.entity_id.in_([first.id, second.id]),
            )
        )
    ).all()
    assert {audit.entity_id for audit in audits} == {first.id, second.id}


async def test_unlisted_rows_keep_their_order_after_the_listed_ones(editor_client, session):
    first = await _competition(session, "order-c", 3)
    second = await _competition(session, "order-d", 4)
    other = await _competition(session, "order-e", 2)
    etags = [
        await _etag(editor_client, f"/admin/api/competitions/{first.id}"),
        await _etag(editor_client, f"/admin/api/competitions/{second.id}"),
    ]

    response = await editor_client.put(
        "/admin/api/competitions/order",
        json={
            "items": [
                {"id": second.id, "if_match": etags[1]},
                {"id": first.id, "if_match": etags[0]},
            ]
        },
    )

    assert response.status_code == 200, response.text
    await session.refresh(first)
    await session.refresh(second)
    await session.refresh(other)
    assert (second.priority, first.priority) == (1, 2)
    assert other.priority is not None and other.priority > 2  # kept, after the listed ones


async def test_one_stale_item_rejects_all_of_them(editor_client, session):
    first = await _competition(session, "order-f", 7)
    second = await _competition(session, "order-g", 8)
    etag = await _etag(editor_client, f"/admin/api/competitions/{second.id}")

    response = await editor_client.put(
        "/admin/api/competitions/order",
        json={
            "items": [
                {"id": first.id, "if_match": '"not-the-version"'},
                {"id": second.id, "if_match": etag},
            ]
        },
    )

    assert response.status_code == 409
    payload = response.json()
    assert payload["error"]["code"] == "edit_conflict"
    assert payload["meta"]["stale_ids"] == [first.id]
    await session.refresh(first)
    await session.refresh(second)
    assert (first.priority, second.priority) == (7, 8)


async def test_repeated_and_unknown_ids_are_422(editor_client, session):
    row = await _competition(session, "order-h", 9)
    etag = await _etag(editor_client, f"/admin/api/competitions/{row.id}")

    repeated = await editor_client.put(
        "/admin/api/competitions/order",
        json={"items": [{"id": row.id, "if_match": etag}, {"id": row.id, "if_match": etag}]},
    )
    unknown = await editor_client.put(
        "/admin/api/competitions/order", json={"items": [{"id": 99999999, "if_match": etag}]}
    )

    assert repeated.status_code == 422
    assert unknown.status_code == 422
    assert repeated.json()["error"]["code"] == "validation_error"
    assert unknown.json()["error"]["code"] == "validation_error"


async def test_satellites_order_bumps_satellites(editor_client, session):
    first = await _satellite(session, "order-sat-a", 4)
    second = await _satellite(session, "order-sat-b", 5)
    etags = [
        await _etag(editor_client, f"/admin/api/satellites/{first.id}"),
        await _etag(editor_client, f"/admin/api/satellites/{second.id}"),
    ]
    before = await _version(session, "satellites")

    response = await editor_client.put(
        "/admin/api/satellites/order",
        json={
            "items": [
                {"id": second.id, "if_match": etags[1]},
                {"id": first.id, "if_match": etags[0]},
            ]
        },
    )

    assert response.status_code == 200, response.text
    await session.refresh(first)
    await session.refresh(second)
    assert (second.priority, first.priority) == (1, 2)
    assert await _version(session, "satellites") == before + 1


# --- B1-R2-2: the list rows carry the version the reorder checks (A-R1-1) ----------------------------

LISTED = [
    pytest.param("competitions", _competition, {"name": "order-renamed"}, id="competitions"),
    pytest.param("satellites", _satellite, {"name_en": "order-renamed-sat"}, id="satellites"),
]


async def _listed(client, entity: str) -> dict[int, str]:
    """``{id: etag}`` of the whole list, as an open A6/A7 page holds it."""
    response = await client.get(f"/admin/api/{entity}")
    assert response.status_code == 200, response.text
    return {row["id"]: row["etag"] for row in response.json()["data"]}


@pytest.mark.parametrize(("entity", "make", "change"), LISTED)
async def test_a_list_row_carries_the_version_its_detail_and_the_order_check_use(
    editor_client, session, entity, make, change
):
    row = await make(session, f"etag-{entity}", 31)

    listed = await _listed(editor_client, entity)

    assert listed[row.id] == await _etag(editor_client, f"/admin/api/{entity}/{row.id}")


@pytest.mark.parametrize(("entity", "make", "change"), LISTED)
async def test_a_reorder_from_a_stale_list_is_409_edit_conflict(editor_client, session, entity, make, change):
    """Editor A's list is older than editor B's rename: A's drag must not overwrite B's change silently."""
    first = await make(session, f"stale-{entity}-a", 41)
    second = await make(session, f"stale-{entity}-b", 42)
    stale = await _listed(editor_client, entity)
    order = f"/admin/api/{entity}/order"
    body = {"items": [{"id": second.id, "if_match": stale[second.id]}, {"id": first.id, "if_match": stale[first.id]}]}

    renamed = await editor_client.patch(
        f"/admin/api/{entity}/{first.id}", json=change, headers=if_match(stale[first.id])
    )
    assert renamed.status_code == 200, renamed.text
    conflict = await editor_client.put(order, json=body)

    assert conflict.status_code == 409
    assert conflict.json()["error"]["code"] == "edit_conflict"
    assert conflict.json()["meta"]["stale_ids"] == [first.id]
    await session.refresh(first)
    await session.refresh(second)
    assert (first.priority, second.priority) == (41, 42)

    fresh = await _listed(editor_client, entity)
    retried = await editor_client.put(
        order,
        json={
            "items": [{"id": second.id, "if_match": fresh[second.id]}, {"id": first.id, "if_match": fresh[first.id]}]
        },
    )
    assert retried.status_code == 200, retried.text
