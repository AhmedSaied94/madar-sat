"""Goal.com, the third source: its list page and match page, from ``__NEXT_DATA__`` (research R8).

The list page gives status, period, minute and score for every match in one request, so it's the real
source, and a match page is a bonus for events, lineups and stats. Commentary, venues, articles, images,
ratings and tips are never read: facts only. FootballCo's approval is recorded in ``docs/owner-actions.md``,
and ``LIVE_GOAL_ENABLED`` switches this reader off in one change.

Statuses come from saved pages. A row with any other keeps its score and nothing else (FR-001).
"""

from __future__ import annotations

import hashlib
import json
import re
from datetime import date, datetime
from typing import Any
from urllib.parse import quote

from app.live.sources.common import UNKNOWN_LABEL_CHARS, clean, parse_document, require_name
from app.live.types import Event, LayoutChanged, Lineups, LineupSide, Score, SourceReading

SOURCE = "goal"
HOST = "www.goal.com"
LIST_PATH = "/ar-eg/" + quote("مباريات-جارية-حاليًا")
MAX_PLAYERS_PER_SIDE = 40
EVENT_ID_CHARS = 16

# A match that's being played says which half in ``period.type``. The label is what a client reads.
LIVE_PERIODS: dict[str, tuple[str, str | None, str]] = {
    "FIRST_HALF": ("live", "1H", "الشوط الأول"),
    "HALF_TIME": ("halftime", None, "استراحة"),
    "SECOND_HALF": ("live", "2H", "الشوط الثاني"),
}
STATUSES: dict[str, tuple[str, str | None, str]] = {
    "FIXTURE": ("scheduled", None, "لم تبدأ"),
    "RESULT": ("finished", None, "انتهت"),
    "POSTPONED": ("postponed", None, "تأجيل"),
}
PLAYED_STATUSES = frozenset({"live", "halftime", "finished"})

EVENT_TYPES = {"GOAL": "goal", "GOAL_OWN": "own_goal", "GOAL_PENALTY": "penalty"}
SKIPPED_EVENT_PREFIX = "PERIOD_"
SKIPPED_EVENT_TYPES = frozenset({"CARD_YELLOW"})
SIDES = {"TEAM_A": "home", "TEAM_B": "away"}

_NEXT_DATA = re.compile(r'<script id="__NEXT_DATA__"[^>]*>(.*?)</script>', re.S)
_MATCH_HREF = re.compile(r'href="(/[^"#?]+/([A-Za-z0-9_-]+))"')


def _content(body: bytes) -> dict[str, Any]:
    text = body.decode("utf-8", "replace")
    parse_document(body, SOURCE)
    blob = _NEXT_DATA.search(text)
    if blob is None:
        raise LayoutChanged("goal: no page data")
    try:
        content = json.loads(blob.group(1))["props"]["pageProps"]["content"]
    except (ValueError, KeyError, TypeError) as exc:
        raise LayoutChanged("goal: unreadable page data") from exc
    if not isinstance(content, dict):
        raise LayoutChanged("goal: page data with no content")
    return content


def _field(value: dict[str, Any], name: str) -> Any:
    if name not in value:
        raise LayoutChanged(f"goal: no {name}")
    return value[name]


def _number_pair(value: Any, what: str) -> tuple[int, int] | None:
    if value is None:
        return None
    home, away = value.get("teamA"), value.get("teamB")
    if home is None and away is None:
        return None
    if not isinstance(home, int) or not isinstance(away, int):
        raise LayoutChanged(f"goal: a {what} that isn't a number")
    return home, away


def _score(match: dict[str, Any]) -> Score | None:
    goals = _number_pair(_field(match, "score"), "score")
    if goals is None:
        return None
    penalties = _number_pair(match.get("penalty"), "penalty score")
    return Score(goals[0], goals[1], *(penalties or (None, None)))


def _minute(period: dict[str, Any]) -> str | None:
    minute, extra = period.get("minute"), period.get("extra")
    if not isinstance(minute, int) or minute < 0:
        return None
    return f"{minute}+{extra}" if isinstance(extra, int) and extra > 0 else str(minute)


def _state(match: dict[str, Any]) -> tuple[str | None, str | None, str | None, str | None]:
    """``(status, period, label, unknown_status)``: an unknown one leaves the first three empty."""
    name = require_name(clean(_field(match, "status")), "status")
    if name == "LIVE":
        period = (match.get("period") or {}).get("type")
        found = LIVE_PERIODS.get(period or "")
        name = f"LIVE/{period}"
    else:
        found = STATUSES.get(name)
    if found is None:
        return None, None, None, name[:UNKNOWN_LABEL_CHARS]
    return found[0], found[1], found[2], None


def _team_name(match: dict[str, Any], key: str) -> str:
    return require_name(clean(_field(match, key).get("name")), key)


def _kickoff(match: dict[str, Any]) -> datetime | None:
    value = _field(match, "startDate")
    if value is None:
        return None
    try:
        return datetime.fromisoformat(value)
    except (TypeError, ValueError) as exc:
        raise LayoutChanged("goal: an unreadable kickoff") from exc


def _reading(match: dict[str, Any], competition: str | None, page_path: str | None) -> SourceReading:
    status, period, label, unknown = _state(match)
    # A match that hasn't been played shows no result: a postponed one reads 0–0.
    score = _score(match) if status in PLAYED_STATUSES or unknown is not None else None
    minute = _minute(match.get("period") or {}) if status == "live" else None
    return SourceReading(
        source=SOURCE,
        external_id=require_name(clean(_field(match, "id")), "match id"),
        home=_team_name(match, "teamA"),
        away=_team_name(match, "teamB"),
        competition=competition or None,
        kickoff_at=_kickoff(match),
        status=status,
        period=period,
        minute=minute,
        score=score,
        status_label=label,
        page_path=page_path,
        unknown_status=unknown,
    )


def parse_list(body: bytes, *, today: date | None = None) -> list[SourceReading]:
    """Every match row. ``today`` is here to match the other readers: a row carries its own date."""
    content = _content(body)
    groups = _field(content, "liveScores")
    if not isinstance(groups, list):
        raise LayoutChanged("goal: no match list on the page")
    links = {found.group(2): found.group(1) for found in _MATCH_HREF.finditer(body.decode("utf-8", "replace"))}
    rows: dict[str, SourceReading] = {}
    for group in groups:
        competition = clean((group.get("competition") or {}).get("name"))
        for match in _field(group, "matches"):
            reading = _reading(match, competition, links.get(str(match.get("id"))))
            rows.setdefault(reading.external_id, reading)
    return list(rows.values())


def _event_id(kind: str, side: str, period: dict[str, Any], who: dict[str, Any], seen: dict[str, int]) -> str:
    """Goal.com's events have no ID. Nothing here moves between polls, and the running score isn't used."""
    key = f"{kind}|{side}|{period.get('minute')}|{period.get('extra')}|{who.get('id') or who.get('name')}"
    digest = hashlib.sha256(key.encode()).hexdigest()[:EVENT_ID_CHARS]
    seen[digest] = seen.get(digest, 0) + 1
    return digest if seen[digest] == 1 else f"{digest}-{seen[digest]}"


def _events(match: dict[str, Any]) -> tuple[tuple[Event, ...], tuple[str, ...]]:
    events: list[Event] = []
    ignored: set[str] = set()
    seen: dict[str, int] = {}
    for item in match.get("events") or []:
        name = clean(item.get("type"))
        if name.startswith(SKIPPED_EVENT_PREFIX) or name in SKIPPED_EVENT_TYPES:
            continue
        kind = EVENT_TYPES.get(name)
        if kind is None:
            ignored.add(name or "unnamed")
            continue
        side = SIDES.get(item.get("side") or "")
        if side is None:
            raise LayoutChanged("goal: an event for neither team")
        period = item.get("period") or {}
        minute = _minute(period)
        if minute is None:
            raise LayoutChanged("goal: an event without a minute")
        who = item.get("scorer") or item.get("player") or {}
        events.append(
            Event(
                external_id=_event_id(name, side, period, who, seen),
                type=kind,
                side=side,  # already the side the goal counts for, own goals too (research R7)
                minute=minute,
                player=clean(who.get("name")) or None,
            )
        )
    return tuple(events), tuple(sorted(ignored))


def _formation(value: Any) -> str | None:
    """``3412`` as the other source writes it: ``3-4-1-2``."""
    text = clean(str(value)) if value is not None else ""
    return "-".join(text) if text.isdigit() else text or None


def _players(rows: list[dict[str, Any]], *, starter: bool) -> list[dict[str, Any]]:
    """Names and shirt numbers. ``score`` is Goal.com's player rating, which isn't ours to store."""
    return [
        {
            "name": clean((row.get("person") or {}).get("name")),
            "number": row.get("shirtNumber"),
            "position": None,
            "is_starter": starter,
        }
        for row in rows
    ]


def _side(side: dict[str, Any] | None) -> LineupSide | None:
    if not side or not side.get("lineup"):
        return None
    players = _players(side["lineup"], starter=True) + _players(side.get("substitutes") or [], starter=False)
    return LineupSide(formation=_formation(side.get("formation")), players=tuple(players[:MAX_PLAYERS_PER_SIDE]))


def _lineups(match: dict[str, Any]) -> Lineups | None:
    value = match.get("lineups") or {}
    home, away = _side(value.get("teamA")), _side(value.get("teamB"))
    return Lineups(home, away) if home is not None or away is not None else None


def _stats(match: dict[str, Any]) -> tuple[dict[str, Any], ...] | None:
    summary = (match.get("stats") or {}).get("summary") or []
    rows = tuple({"type": row["type"], "home": row.get("teamA"), "away": row.get("teamB")} for row in summary)
    return rows or None


def parse_match(body: bytes) -> SourceReading:
    """One match from ``content.match``, adding events, lineups and the stats summary to the row's fields."""
    match = _field(_content(body), "match")
    if not isinstance(match, dict):
        raise LayoutChanged("goal: no match on the page")
    reading = _reading(match, clean((match.get("competition") or {}).get("name")), None)
    events, ignored = _events(match)
    return SourceReading(
        source=reading.source,
        external_id=reading.external_id,
        home=reading.home,
        away=reading.away,
        competition=reading.competition,
        kickoff_at=reading.kickoff_at,
        status=reading.status,
        period=reading.period,
        minute=reading.minute,
        score=reading.score,
        events=events,
        lineups=_lineups(match),
        status_label=reading.status_label,
        ignored_event_types=ignored,
        unknown_status=reading.unknown_status,
        stats=_stats(match),
    )
