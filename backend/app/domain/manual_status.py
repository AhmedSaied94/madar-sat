"""Which fields each manual match status allows (data-model.md, "Match status: manual override").

Pure: no database, no schemas. ``validate`` returns one ``{"loc": [field], "type": reason}`` per bad
field; the admin handler prefixes the path of the request body and answers ``422 validation_error``.
The database CHECKs (``ck_matches_*``) stay the last line of defense.
"""

from __future__ import annotations

import re
from typing import Protocol

STATUS_LABEL_MAX = 80  # the column allows 120; the editor's cap leaves room
MINUTE_PATTERN = re.compile(r"^\d{1,3}(\+\d{1,2})?$")
MINUTE_MAX = 8

REGULAR_PERIODS = frozenset({"1H", "2H"})
EXTRA_PERIODS = frozenset({"ET1", "ET2"})

# status -> (score, penalties, periods, minute). score: "required" | "optional" | "no";
# penalties: allowed or not (only meaningful with a score); periods: the allowed set (empty: none).
_RULES: dict[str, tuple[str, bool, frozenset[str], bool]] = {
    "scheduled": ("no", False, frozenset(), False),
    "postponed": ("no", False, frozenset(), False),
    "cancelled": ("no", False, frozenset(), False),
    "live": ("required", False, REGULAR_PERIODS, True),
    "halftime": ("required", False, frozenset(), False),
    "extra_time": ("required", False, EXTRA_PERIODS, True),
    "penalties": ("required", True, frozenset(), False),
    "finished": ("required", True, frozenset(), False),
    "abandoned": ("optional", False, frozenset(), True),
}
STATUSES = tuple(_RULES)


class ScoreLike(Protocol):
    @property
    def home_pen(self) -> int | None: ...

    @property
    def away_pen(self) -> int | None: ...


def _error(field: str, reason: str) -> dict[str, object]:
    return {"loc": [field], "type": reason}


def validate(
    status: str,
    period: str | None,
    minute: str | None,
    score: ScoreLike | None,
    status_label: str | None,
) -> list[dict[str, object]]:
    """Every problem with the combination, one entry per field; an empty list means it may be stored."""
    rule = _RULES.get(status)
    if rule is None:
        return [_error("status", "invalid_value")]
    score_rule, penalties_allowed, periods, minute_allowed = rule

    errors: list[dict[str, object]] = []

    if score is None:
        if score_rule == "required":
            errors.append(_error("score", "required"))
    elif score_rule == "no":
        errors.append(_error("score", "not_allowed"))
    elif not penalties_allowed and (score.home_pen is not None or score.away_pen is not None):
        errors.append(_error("score", "not_allowed"))

    if period is not None and period not in periods:
        errors.append(_error("period", "not_allowed" if not periods else "invalid_value"))

    if minute is not None:
        if not minute_allowed:
            errors.append(_error("minute", "not_allowed"))
        elif len(minute) > MINUTE_MAX or not MINUTE_PATTERN.fullmatch(minute):
            errors.append(_error("minute", "invalid_format"))

    if status_label is not None and len(status_label) > STATUS_LABEL_MAX:
        errors.append(_error("status_label", "too_long"))

    return errors
