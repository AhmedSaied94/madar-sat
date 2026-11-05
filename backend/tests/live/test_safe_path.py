"""The one check for a link a page gave us (B1-R1-7, B1-R2-2)."""

from __future__ import annotations

import pytest

from app.live.sources.common import safe_path


@pytest.mark.parametrize(
    ("link", "path"),
    [
        ("/league/1/match/9/x", "/league/1/match/9/x"),
        ("/league/1/match/9/x#MC_MatcheDetails", "/league/1/match/9/x"),
        ("/matches/9/coverage/?a=1", "/matches/9/coverage/"),
        ("https://www.yallakora.com/league/1/match/9/x", "/league/1/match/9/x"),
        ("/a..b/c", "/a..b/c"),
        ("/مباريات/9", "/مباريات/9"),
    ],
)
def test_a_plain_link_gives_its_path(link, path):
    assert safe_path(link) == path


@pytest.mark.parametrize(
    "link",
    [
        None,
        "",
        ":abc/x",
        ":8080/x",
        "@evil.example/x",
        "javascript:void(0)",
        "x/y",
        "//[x/y",
        "//evil.example//x",
        "/a/../login",
        "/a/./login",
        "/a/..",
        "/a\\b",
        "/a:b",
        "/a@b",
        "/a b",
        "/a\nb",
        "/a\x7fb",
    ],
)
def test_anything_else_gives_none(link):
    assert safe_path(link) is None
