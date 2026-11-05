"""FilGoal: the list page and the JSON model in a match's coverage page (SD §6.7, research R1).

Status strings come from saved pages' ``MatchStatusHistory``. A row with any other keeps its score and
nothing else (FR-001), and the cycle tells the owner. ``Comments`` and every other written field are
never read: facts only.
"""

from __future__ import annotations

import json
import re
from datetime import UTC, date, datetime
from typing import Any

from app.domain.time import CAIRO
from app.live.sources.common import (
    UNKNOWN_LABEL_CHARS,
    cairo_kickoff,
    clean,
    first,
    pair,
    parse_document,
    require_name,
    require_score,
    score_part,
    text_of,
)
from app.live.types import Event, LayoutChanged, Lineups, LineupSide, Score, SourceReading

SOURCE = "filgoal"
HOST = "www.filgoal.com"
LIST_PATH = "/matches/"
MAX_PLAYERS_PER_SIDE = 40

# Status name → (§6.2.3 status, period).
STATUS_MAP: dict[str, tuple[str, str | None]] = {
    "لم تبدأ": ("scheduled", None),
    "بعد قليل": ("scheduled", None),
    "الشوط الاول": ("live", "1H"),
    "الشوط الأول": ("live", "1H"),
    "استراحة": ("halftime", None),
    "الشوط الثاني": ("live", "2H"),
    "انتهت": ("finished", None),
    "تأجيل": ("postponed", None),
}
# The minute a period starts from.
PERIOD_BASE = {"1H": 0, "2H": 45}
# Elapsed time in a period past its length, beyond which the clock isn't a match minute (research R4).
MAX_STOPPAGE_MINUTES = 15
# ``TimeElapsed`` comes back shifted by whole hours, so a negative value is this many minutes short.
CLOCK_SHIFT_MINUTES = 60

# ``MatchEventTypeId`` → our type. Yellow cards (3) aren't served. Others are logged, not guessed.
EVENT_TYPES = {1: "goal", 4: "red_card", 8: "penalty", 9: "missed_penalty", 20: "own_goal", 21: "red_card"}
NOT_SERVED_EVENT_TYPES = frozenset({3})
OWN_GOAL_TYPE = 20

_MODEL = re.compile(r"viewModelData\s*=\s*")
_DECODER = json.JSONDecoder()


def match_path(external_id: str) -> str:
    return f"/matches/{external_id}/coverage/"


def _status(name: str) -> tuple[str | None, str | None, str | None]:
    """``(status, period, unknown_status)``: an unknown one leaves the first two empty."""
    state = STATUS_MAP.get(clean(name))
    return (state[0], state[1], None) if state is not None else (None, None, clean(name)[:UNKNOWN_LABEL_CHARS])


def parse_list(body: bytes, *, today: date) -> list[SourceReading]:
    """Every match row. ``today`` is the Cairo date the page shows: a row holds only a clock time."""
    doc = parse_document(body, SOURCE)
    if not doc.xpath("//*[@id='match-slider-holder']"):
        raise LayoutChanged("filgoal: no match list on the page")
    found: dict[str, SourceReading] = {}
    for row in doc.xpath("//*[@data-match-id]"):
        external_id = row.get("data-match-id") or ""
        if external_id and external_id not in found:
            found[external_id] = _list_row(row, external_id, today)
    return list(found.values())


def _list_row(row: Any, external_id: str, today: date) -> SourceReading:
    label = text_of(first(row.xpath(".//*[contains(concat(' ', normalize-space(@class), ' '), ' status ')]")))
    status, period, unknown = _status(require_name(label, "status"))
    names = row.xpath(".//div/div/span")
    if len(names) < 2:
        raise LayoutChanged("filgoal: a row without two teams")
    home_score = first(row.xpath(".//*[contains(@class, 'home-score')]"))
    away_score = first(row.xpath(".//*[contains(@class, 'away-score')]"))
    if home_score is None or away_score is None:
        raise LayoutChanged("filgoal: a row without its scores")
    score = pair(score_part(home_score.text_content()), score_part(away_score.text_content()))
    if status is not None:
        require_score(status, score)
    return SourceReading(
        source=SOURCE,
        external_id=external_id,
        home=require_name(text_of(names[0]), "home team"),
        away=require_name(text_of(names[1]), "away team"),
        competition=text_of(first(row.xpath(".//h6"))) or None,
        kickoff_at=cairo_kickoff(today, text_of(first(row.xpath(".//span[@class='time']")))),
        status=status,
        period=period,
        minute=None,
        score=score,
        status_label=None if unknown else label,
        page_path=match_path(external_id),
        unknown_status=unknown,
    )


def _model(body: bytes) -> dict[str, Any]:
    text = body.decode("utf-8", "replace")
    for found in _MODEL.finditer(text):
        try:
            value, _ = _DECODER.raw_decode(text[found.end() :])
        except ValueError:
            continue
        if isinstance(value, dict) and "HomeTeamName" in value:
            return value
    raise LayoutChanged("filgoal: no match model on the page")


def _field(model: dict[str, Any], name: str) -> Any:
    if name not in model:
        raise LayoutChanged(f"filgoal: the model has no {name}")
    return model[name]


def _minute(current: dict[str, Any], period: str | None) -> str | None:
    """``TimeElapsed`` counts from this period's start; past its length it shows as stoppage time.

    FilGoal's start time is shifted by whole hours, flipping between server groups, so the value can be
    negative: −98 at minute 22 (research R4). The limit is on elapsed time in the period, before the base
    is added, or every second-half minute past 60 would disappear.
    """
    if period is None or not current.get("IsCounterEnabled"):
        return None
    elapsed = (current.get("TimeElapsed") or {}).get("Minutes")
    if not isinstance(elapsed, int):
        return None
    if elapsed < 0:
        elapsed %= CLOCK_SHIFT_MINUTES
    base = PERIOD_BASE[period]
    length = current.get("MatchStatusMaxTime")
    if isinstance(length, int):
        if elapsed > length + MAX_STOPPAGE_MINUTES:
            return None
        if elapsed > length:
            return f"{base + length}+{elapsed - length}"
    return str(base + elapsed)


def _score(model: dict[str, Any]) -> Score | None:
    home, away = _field(model, "HomeScore"), _field(model, "AwayScore")
    if home is None and away is None:
        return None
    if not isinstance(home, int) or not isinstance(away, int):
        raise LayoutChanged("filgoal: a score that isn't a number")
    home_pen, away_pen = model.get("HomePenaltyScore"), model.get("AwayPenaltyScore")
    if not all(pen is None or isinstance(pen, int) for pen in (home_pen, away_pen)):
        raise LayoutChanged("filgoal: a penalty score that isn't a number")
    return Score(home, away, home_pen, away_pen)


def _event_minute(event: dict[str, Any]) -> str:
    minute = event.get("CalculatedTime")
    if not isinstance(minute, int) or minute < 0:
        raise LayoutChanged("filgoal: an event without a minute")
    extra = event.get("CalculatedAdditionalTime")
    return f"{minute}+{extra}" if isinstance(extra, int) and extra > 0 else str(minute)


def _events(model: dict[str, Any]) -> tuple[tuple[Event, ...], tuple[str, ...]]:
    home_id, away_id = _field(model, "HomeTeamId"), _field(model, "AwayTeamId")
    events: list[Event] = []
    ignored: set[str] = set()
    for item in model.get("Events") or []:
        type_id = item.get("MatchEventTypeId")
        if type_id in NOT_SERVED_EVENT_TYPES:
            continue
        kind = EVENT_TYPES.get(type_id)
        if kind is None:
            ignored.add(clean(item.get("MatchEventTypeName")) or str(type_id))
            continue
        team = item.get("TeamId")
        if team not in (home_id, away_id):
            raise LayoutChanged("filgoal: an event for neither team")
        # ``TeamId`` is the player's team, and an own goal counts for the other one (research R7).
        counts_for_home = (team == home_id) != (type_id == OWN_GOAL_TYPE)
        events.append(
            Event(
                external_id=str(_field(item, "Id")),
                type=kind,
                side="home" if counts_for_home else "away",
                minute=_event_minute(item),
                player=clean(item.get("PlayerAName")) or None,
            )
        )
    return tuple(events), tuple(sorted(ignored))


def _side(model: dict[str, Any], team_id: Any, formation_key: str) -> LineupSide | None:
    rows = [row for row in model.get("MatchTeamsSquads") or [] if row.get("TeamId") == team_id]
    if not rows:
        return None
    rows.sort(key=lambda row: (bool(row.get("IsSpare")), row.get("Order") or 0))
    players = tuple(
        {
            "name": clean(row.get("PersonName")),
            "number": row.get("ShirtNumber"),
            "position": clean(row.get("PlayerPositionName")) or None,
            "is_starter": not row.get("IsSpare"),
        }
        for row in rows[:MAX_PLAYERS_PER_SIDE]
    )
    return LineupSide(formation=clean(model.get(formation_key)) or None, players=players)


def _lineups(model: dict[str, Any]) -> Lineups | None:
    home = _side(model, model.get("HomeTeamId"), "HomeTeamFormationName")
    away = _side(model, model.get("AwayTeamId"), "AwayTeamFormationName")
    return Lineups(home, away) if home is not None or away is not None else None


def _kickoff(model: dict[str, Any]) -> datetime | None:
    """``Date`` is Cairo wall-clock time: FilGoal's 22:00 kickoffs are 20:00 UTC in winter."""
    value = _field(model, "Date")
    try:
        parsed = datetime.fromisoformat(value)
    except (TypeError, ValueError) as exc:
        raise LayoutChanged("filgoal: an unreadable kickoff") from exc
    return parsed.replace(tzinfo=CAIRO).astimezone(UTC)


def parse_match(body: bytes) -> SourceReading:
    """One match from the page's model. Written commentary (``Comments``) is never read."""
    model = _model(body)
    current = _field(model, "CurrentMatchStatus")
    if not isinstance(current, dict):
        raise LayoutChanged("filgoal: the model has no current status")
    label = clean(_field(current, "MatchStatusName"))
    status, period, unknown = _status(require_name(label, "status"))
    score = _score(model)
    if status is not None:
        require_score(status, score)
    events, ignored = _events(model)
    return SourceReading(
        source=SOURCE,
        external_id=str(_field(model, "Id")),
        home=require_name(clean(_field(model, "HomeTeamName")), "home team"),
        away=require_name(clean(_field(model, "AwayTeamName")), "away team"),
        competition=clean(model.get("ChampionshipName")) or None,
        kickoff_at=_kickoff(model),
        status=status,
        period=period,
        minute=_minute(current, period),
        score=score,
        events=events,
        lineups=_lineups(model),
        status_label=None if unknown else label,
        page_path=match_path(str(model["Id"])),
        ignored_event_types=ignored,
        unknown_status=unknown,
    )
