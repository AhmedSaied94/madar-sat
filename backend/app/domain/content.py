"""Content rules that apply to every writer: no card-sharing labels (constitution, Content and legal; O3).

D1's snapshot loader strips them from imported names and its load report scans for leftovers; the admin API
refuses them with ``422 validation_error``. One definition keeps the three in step.
"""

from __future__ import annotations

import re

CARD_SHARING_LABELS = ("Mega Share", "Apollo", "VIP", "ليست مكسورة", "BISS")

# Latin labels match as whole words in any case ("beIN VIP", "Biss : 12 34"), so names
# that merely contain the letters ("Guinea-Bissau", "Apollon") are not flagged. The
# Arabic label also matches its ar_normalize spelling (ة → ه).
_LABEL_RE = re.compile(r"\b(?:mega\s*share|apollo|vip|biss)\b|ليست\s*مكسور[ةه]", re.IGNORECASE)
# Separators a removed label leaves at either end: "beIN Sports - VIP" → "beIN Sports".
_EDGE_RE = re.compile(r"^[\s\-–—|:/]+|[\s\-–—|:/]+$")


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
