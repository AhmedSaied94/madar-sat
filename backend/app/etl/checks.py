"""Post-write checks for the load report (contracts/load-report.md ``checks``, SC-002, FR-005).

``card_sharing_labels_found`` is a real scan: after the load, every stored text column of
every table the ETL writes is read back and searched for the card-sharing labels that the
old ``encryption`` field held (README rule 9, constitution O3). It must be 0.
"""

from __future__ import annotations

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

# The label helpers moved to app.domain.content (the admin API uses them too); the loader's
# modules and tests still import them from here.
from app.domain.content import CARD_SHARING_LABELS as CARD_SHARING_LABELS
from app.domain.content import find_card_sharing_label as find_card_sharing_label
from app.domain.content import strip_card_sharing_labels as strip_card_sharing_labels

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
