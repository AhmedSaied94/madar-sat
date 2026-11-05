"""The deny list (T018, 005 research R4)."""

from __future__ import annotations

import pytest

from app.live import robots
from app.live.robots import FILGOAL_HOST, GOAL_HOST, YALLAKORA_HOST, is_allowed


@pytest.mark.parametrize(
    "path",
    [
        "/Match/EuroMatchStats2",
        "/ar/Match/EuroMatchStats2?id=1",
        "/x/Match/Matchsquad2",
        "/x/Match/MatchManOfTheMatch2",
        "/x/Match/GetTeamsHeadToHeadMatches",
        "/x/MatchMinByMinPaging/3",
        "/champions",
        "/champions-league/3066/match/1/x",
        "/arabic",
        "/arabic/x",
        "/a?b=1?c=2",
        "/search?q=x",
        "/services/x",
        "/cdn-cgi/challenge-platform/h/b",
    ],
)
def test_yallakora_denied_paths(path):
    assert is_allowed(YALLAKORA_HOST, path) is False


@pytest.mark.parametrize(
    "path",
    [
        "/matches-center",
        "/matches-center?date=11/3/2026",
        "/egypt-cup/3066/match/114019/",
        "/uefa/2919/match/1/x",
        "/asian-champions-league/3001/match/1/x",
        "/match-center",
    ],
)
def test_yallakora_allowed_paths(path):
    assert is_allowed(YALLAKORA_HOST, path) is True


@pytest.mark.parametrize(
    "path", ["/arabic/x.aspx", "/login/", "/register/a", "/account/me", "/articles/increaseviewcount/1"]
)
def test_filgoal_denied_paths(path):
    assert is_allowed(FILGOAL_HOST, path) is False


@pytest.mark.parametrize("path", ["/matches/", "/matches/378934/coverage/", "/arabic/x.html", "/articles/1"])
def test_filgoal_allowed_paths(path):
    assert is_allowed(FILGOAL_HOST, path) is True


@pytest.mark.parametrize("path", ["/ar-eg/%D8%A7/x/abc", "/robots.txt", "/en/anything?x=1"])
def test_goal_com_allows_everything_as_its_robots_file_does(path):
    assert robots.DENY_RULES[GOAL_HOST] == ()
    assert is_allowed(GOAL_HOST, path) is True


def test_goal_coms_copy_is_committed_and_disallows_nothing():
    text = robots.committed_copy(GOAL_HOST)

    assert "User-agent: *" in text
    assert "Allow: /" in text
    assert not [line for line in text.splitlines() if line.lower().startswith("disallow:")]


def test_an_unknown_host_is_never_allowed():
    assert is_allowed("www.example.com", "/") is False


def test_matching_is_case_sensitive_like_the_rules():
    assert is_allowed(FILGOAL_HOST, "/LOGIN/") is True


def test_a_non_ascii_query_rule_matches_only_non_ascii():
    assert is_allowed(YALLAKORA_HOST, "/x?q=abc") is True
    assert is_allowed(YALLAKORA_HOST, "/x?q=عربي") is False


@pytest.mark.parametrize("host", [FILGOAL_HOST, YALLAKORA_HOST, GOAL_HOST])
def test_the_deny_list_covers_every_disallow_of_the_committed_copy(host):
    lines = [line.split(":", 1)[1].strip() for line in robots.committed_copy(host).splitlines() if ":" in line]
    disallowed = {
        line.split(":", 1)[1].strip()
        for line in robots.committed_copy(host).splitlines()
        if line.lower().startswith("disallow:")
    }
    assert lines
    # The narrower `/search?…` forms are all covered by `/search*`.
    assert {rule for rule in disallowed if not rule.lower().startswith("/search")} <= set(robots.DENY_RULES[host])


def test_normalized_ignores_blank_lines_and_line_endings():
    assert robots.normalized("a\r\n\r\n b \n") == robots.normalized("a\nb")
