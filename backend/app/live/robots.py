"""The paths each site's ``robots.txt`` forbids, checked before every request (005 research R4).

The rules are a committed copy, never parsed at runtime: a silent change on the site must not widen
or narrow what the poller does. ``live.check_robots`` compares each live file with the copy in
``app/live/robots/`` and alerts the owner, who updates both by hand.

Matching follows RFC 9309: a rule is a prefix of the path and query, ``*`` matches anything, and
matching is case sensitive. A host that isn't listed is never allowed.
"""

from __future__ import annotations

import re
from pathlib import Path

FILGOAL_HOST = "www.filgoal.com"
YALLAKORA_HOST = "www.yallakora.com"

DENY_RULES: dict[str, tuple[str, ...]] = {
    FILGOAL_HOST: (
        "/arabic/*.aspx",
        "/login/",
        "/register/",
        "/account/",
        "/articles/increaseviewcount",
    ),
    YALLAKORA_HOST: (
        "*/App_Data",
        "*/app_data",
        "*/bin",
        "*/services",
        "*/app_globalresources",
        "*/YKAds",
        "*/ykads",
        "*/YKNow",
        "*/yknow",
        "*/IP2Location",
        "*/GetLocation",
        "*/beta",
        "*/arabic",
        "*/champions",
        "*/ykchampions",
        "*/Match/EuroMatchStats2",
        "*/Match/Matchsquad2",
        "*/Match/MatchManOfTheMatch2",
        "*/Match/GetTeamsHeadToHeadMatches",
        "*/Match/MatchTemasNews2",
        "*/Match/MatchTemasVideos",
        "*/cdn-cgi/challenge-platform*",
        "*/404.html",
        "/search*",
        "/Search*",
        "/*?*?*",
        "/*?V?*",
        "/*FF168*",
        r"/*?q=*[^\x00-\x7F]*",
        r"/*?cat=*[^\x00-\x7F]*",
        "*TestTrack*",
        "*testtrack*",
        "*ExternalLogin*",
        "*MatchMinByMinPaging*",
        "*insertPollVote*",
        "*Article/GetNewsDetailsByIds*",
    ),
}

_NON_ASCII = r"[^\x00-\x7F]"


def _compile(rule: str) -> re.Pattern[str]:
    parts = rule.split(_NON_ASCII)
    body = _NON_ASCII.join(re.escape(part).replace(r"\*", ".*") for part in parts)
    return re.compile(body)


_COMPILED = {host: tuple(_compile(rule) for rule in rules) for host, rules in DENY_RULES.items()}

ROBOTS_DIR = Path(__file__).with_name("robots")
ROBOTS_COPIES = {FILGOAL_HOST: ROBOTS_DIR / "filgoal.txt", YALLAKORA_HOST: ROBOTS_DIR / "yallakora.txt"}


def is_allowed(host: str, path: str) -> bool:
    """Whether ``path`` (with its query, if any) may be requested from ``host``."""
    rules = _COMPILED.get(host)
    if rules is None:
        return False
    return not any(rule.match(path) for rule in rules)


def committed_copy(host: str) -> str:
    return ROBOTS_COPIES[host].read_text(encoding="utf-8")


def normalized(text: str) -> str:
    """A ``robots.txt`` without blank lines or line-ending differences, for the daily comparison."""
    return "\n".join(line.strip() for line in text.splitlines() if line.strip())
