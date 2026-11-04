"""The queue of names no importer or poller could match (D5 T054, FR-022, data-model).

One row per ``(source, kind, name_norm, competition_norm)``. A repeat raises ``seen_count`` and
refreshes the context of an ``open`` row, and an editor's decision (``mapped``, ``created``,
``ignored``) is never reopened. Nothing here creates a team, a competition or a channel.

Revision ``0007`` (Lane B1) adds the table; this module names it in SQL rather than through
``app.db.models``, as ``health.py`` does.
"""

from __future__ import annotations

import json
from typing import Any, Literal

from sqlalchemy import text

from app.domain.arabic import ar_normalize

Kind = Literal["team", "competition", "channel"]
MAX_NAME = 200

UPSERT_SQL = """
INSERT INTO unresolved_names (source, kind, name, name_norm, competition_norm, context)
VALUES (:source, :kind, :name, :name_norm, :competition_norm, CAST(:context AS jsonb))
ON CONFLICT (source, kind, name_norm, competition_norm) DO UPDATE
   SET seen_count = unresolved_names.seen_count + 1,
       context = EXCLUDED.context,
       last_seen_at = now()
 WHERE unresolved_names.state = 'open'
RETURNING id
"""


def record_unresolved(
    session: Any,
    *,
    source: str,
    kind: Kind,
    name: str,
    competition: str | None,
    context: dict[str, Any],
) -> bool:
    """Queue one unmatched name; return whether a row changed.

    The caller bumps ``unresolved_names`` once, as the last statement of its transaction, when
    any call returned ``True`` (constitution VI, VII).
    """
    capped = name.strip()[:MAX_NAME]
    normal = ar_normalize(capped)
    if not normal:
        return False
    row = session.execute(
        text(UPSERT_SQL),
        {
            "source": source,
            "kind": kind,
            "name": capped,
            "name_norm": normal,
            "competition_norm": ar_normalize(competition),
            "context": json.dumps(context, ensure_ascii=False, default=_json_value),
        },
    ).first()
    return row is not None


def _json_value(value: Any) -> str:
    """A ``datetime`` in the context: ISO-8601, which is how the admin reads it."""
    return value.isoformat() if hasattr(value, "isoformat") else str(value)
