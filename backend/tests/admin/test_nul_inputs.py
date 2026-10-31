"""A NUL byte in any admin text input is a 422 with the envelope, never a 500 (B1-R1-2, FR-013).

PostgreSQL text can't hold it and asyncpg raises, so the schemas refuse it before the database is
reached. The contract tests draw it from Hypothesis; these cases name every route that takes text.
"""

from __future__ import annotations

import pytest

from tests.admin.helpers import ADMIN, new_match

NUL = "\u0000"


@pytest.mark.parametrize(
    ("method", "path", "payload"),
    [
        ("post", f"{ADMIN}/hidden-channel-names", {"name": f"قناة{NUL}"}),
        ("post", f"{ADMIN}/teams", {"name": f"فريق{NUL}"}),
        ("post", f"{ADMIN}/competitions", {"name": f"بطولة{NUL}"}),
        ("post", f"{ADMIN}/satellites", {"name_ar": f"قمر{NUL}", "name_en": "nul", "slug": "nul-nul"}),
        ("post", f"{ADMIN}/commentators", {"name": f"معلق{NUL}"}),
        (
            "post",
            f"{ADMIN}/matches",
            {
                "kickoff_at": "2026-10-31T18:00:00Z",
                "match_date": "2026-10-31",
                "home": {"name": f"فريق{NUL}"},
                "away": {"name": "فريق ب"},
                "competition_name": "بطولة",
            },
        ),
    ],
)
async def test_a_nul_in_a_create_body_is_a_validation_error(editor_client, method, path, payload):
    response = await getattr(editor_client, method)(path, json=payload)

    assert response.status_code == 422, response.text
    body = response.json()
    assert body["success"] is False
    assert body["error"]["code"] == "validation_error"


async def test_a_nul_in_a_patch_body_is_a_validation_error(editor_client):
    match = await new_match(editor_client)

    response = await editor_client.patch(
        f"{ADMIN}/matches/{match['id']}",
        json={"fields": {"stadium": f"ملعب{NUL}"}},
        headers={"If-Match": match["_etag"]},
    )

    assert response.status_code == 422, response.text
    assert response.json()["error"]["code"] == "validation_error"


@pytest.mark.parametrize("path", [f"{ADMIN}/teams", f"{ADMIN}/channels", f"{ADMIN}/commentators"])
async def test_a_nul_in_a_search_query_is_a_validation_error(editor_client, path):
    response = await editor_client.get(path, params={"q": f"a{NUL}"})

    assert response.status_code == 422, response.text
    assert response.json()["error"]["code"] == "validation_error"


async def test_a_nul_in_the_hidden_name_path_is_a_validation_error(editor_client):
    response = await editor_client.delete(f"{ADMIN}/hidden-channel-names/%00")

    assert response.status_code == 422, response.text
    assert response.json()["error"]["code"] == "validation_error"
