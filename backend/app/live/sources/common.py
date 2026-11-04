"""What both parsers share: text clean-up, Western digits and the state a status string means."""

from __future__ import annotations

import re
from datetime import UTC, date, datetime, time
from typing import Any

# lxml ships no stubs and the project has no override for it (see app/adapters/ysscores.py).
from lxml import html as lxml_html  # type: ignore[import-untyped]

from app.domain.time import CAIRO
from app.live.types import LayoutChanged, Score

_WS = re.compile(r"\s+")
_DIGITS = str.maketrans("٠١٢٣٤٥٦٧٨٩۰۱۲۳۴۵۶۷۸۹", "01234567890123456789")
_CLOCK = re.compile(r"^(\d{1,2}):(\d{2})$")

# A status that needs a score: anything from kickoff on.
SCORED_STATUSES = frozenset({"live", "halftime", "extra_time", "penalties", "finished"})


def parse_document(body: bytes, source: str) -> Any:
    """The parsed page. An empty body or one lxml can't read fails validation."""
    text = body.decode("utf-8", "replace").strip()
    if not text:
        raise LayoutChanged(f"{source}: empty body")
    try:
        return lxml_html.fromstring(text)
    except (ValueError, lxml_html.etree.ParserError) as exc:
        raise LayoutChanged(f"{source}: not a page") from exc


def clean(text: str | None) -> str:
    return _WS.sub(" ", text or "").strip()


def text_of(node: Any) -> str:
    return clean(node.text_content()) if node is not None else ""


def first(nodes: list[Any]) -> Any | None:
    return nodes[0] if nodes else None


def western(text: str) -> str:
    return text.translate(_DIGITS)


def score_part(text: str) -> int | None:
    """A displayed score: ``None`` for the placeholder a match without a score shows."""
    value = western(clean(text))
    if value in {"", "-", "–"}:
        return None
    if not value.isascii() or not value.isdigit():
        raise LayoutChanged(f"not a score: {value[:20]!r}")
    return int(value)


def pair(home: int | None, away: int | None) -> Score | None:
    if home is None and away is None:
        return None
    if home is None or away is None:
        raise LayoutChanged("only one side has a score")
    return Score(home, away)


def require_score(status: str, score: Score | None) -> None:
    if status in SCORED_STATUSES and score is None:
        raise LayoutChanged(f"status {status} has no score")


def require_name(value: str, what: str) -> str:
    if not value:
        raise LayoutChanged(f"missing {what}")
    return value


def cairo_kickoff(day: date, clock: str) -> datetime | None:
    """``17:00`` on a Cairo date, in UTC; ``None`` when the row shows no time (a finished match)."""
    match = _CLOCK.match(western(clean(clock)))
    if match is None:
        return None
    hour, minute = int(match.group(1)), int(match.group(2))
    if hour > 23 or minute > 59:
        return None
    return datetime.combine(day, time(hour, minute), tzinfo=CAIRO).astimezone(UTC)
