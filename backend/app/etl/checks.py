"""Post-write checks for the load report (contracts/load-report.md ``checks``, SC-002, FR-005).

``card_sharing_labels_found`` is a real scan: after the load, every stored text column of
every table the ETL writes is read back and searched for the card-sharing labels that the
old ``encryption`` field held (README rule 9, constitution O3). It must be 0.
"""

from __future__ import annotations

import re
from dataclasses import dataclass
from typing import Any

from sqlalchemy import ARRAY, String, Text, select
from sqlalchemy.orm import Session
from sqlalchemy.sql.schema import Column

from app.db.models import (
    BroadcastPreset,
    Channel,
    Commentator,
    Competition,
    Feed,
    HiddenChannelName,
    LivesoccertvTeam,
    Match,
    MatchChannel,
    MatchCustomBroadcast,
    MatchExternalId,
    MediaAsset,
    RightsHolder,
    RightsHolderCarriage,
    Satellite,
    Team,
    TeamExternalId,
)

CARD_SHARING_LABELS = ("Mega Share", "Apollo", "VIP", "ليست مكسورة", "BISS")

# Latin labels match as whole words in any case ("beIN VIP", "Biss : 12 34"), so names
# that merely contain the letters ("Guinea-Bissau", "Apollon") are not flagged. The
# Arabic label also matches its ar_normalize spelling (ة → ه).
_LABEL_RE = re.compile(r"\b(?:mega\s*share|apollo|vip|biss)\b|ليست\s*مكسور[ةه]", re.IGNORECASE)
# Separators a removed label leaves at either end: "beIN Sports - VIP" → "beIN Sports".
_EDGE_RE = re.compile(r"^[\s\-–—|:/]+|[\s\-–—|:/]+$")

# Every table the snapshot loader or the media rehoster writes.
SCANNED_MODELS: tuple[Any, ...] = (
    Satellite,
    Competition,
    Team,
    TeamExternalId,
    LivesoccertvTeam,
    Commentator,
    BroadcastPreset,
    HiddenChannelName,
    Channel,
    RightsHolder,
    RightsHolderCarriage,
    Match,
    MatchExternalId,
    MatchChannel,
    MatchCustomBroadcast,
    Feed,
    MediaAsset,
)


@dataclass(frozen=True)
class LabelHit:
    table: str
    column: str
    key: str  # the row's primary key, for the report
    label: str  # the matched text


def find_card_sharing_label(value: str | None) -> str | None:
    """Return the first card-sharing label in ``value`` (as written there), or ``None``."""
    if not value:
        return None
    m = _LABEL_RE.search(value)
    return m.group(0) if m else None


def strip_card_sharing_labels(value: str | None) -> str | None:
    """Return ``value`` without its card-sharing labels, or ``None`` if nothing else is left.

    A value with no label (``""`` and ``None`` included) comes back unchanged. Some real
    channel names carry a label ("CCTV Sports VIP"); the channel is kept under the rest of
    its name.
    """
    if not value or _LABEL_RE.search(value) is None:
        return value
    return _EDGE_RE.sub("", " ".join(_LABEL_RE.sub(" ", value).split())) or None


def _text_columns(model: Any) -> list[Column[Any]]:
    """Stored text columns: Text/String and text[], skipping generated ``*_norm`` columns."""
    cols: list[Column[Any]] = []
    for col in model.__table__.columns:
        if col.computed is not None:
            continue
        if isinstance(col.type, String | Text) or (
            isinstance(col.type, ARRAY) and isinstance(col.type.item_type, String | Text)
        ):
            cols.append(col)
    return cols


def scan_card_sharing_labels(session: Session) -> list[LabelHit]:
    """Read back every stored text value the ETL writes and return each label found."""
    session.flush()
    hits: list[LabelHit] = []
    for model in SCANNED_MODELS:
        table = model.__table__
        pk = list(table.primary_key.columns)
        cols = _text_columns(model)
        for row in session.execute(select(*pk, *cols)):
            key = "/".join(str(v) for v in row[: len(pk)])
            for col, value in zip(cols, row[len(pk) :], strict=True):
                values = value if isinstance(value, list) else [value]
                for v in values:
                    label = find_card_sharing_label(v)
                    if label is not None:
                        hits.append(LabelHit(table.name, col.name, key, label))
    return hits
