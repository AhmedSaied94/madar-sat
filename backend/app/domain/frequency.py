"""Frequency parsing and domain checks (README rule 5, data-model "Frequencies").

A DVB-S tuning looks like ``"11843 H 27500"``. The Cyrillic ``Н`` (U+041D) that appears
in the snapshot is replaced with a Latin ``H`` before matching. Values that don't parse
become a ``frequency_note``; values outside the MHz / symbol-rate domains are rejected.
"""

from __future__ import annotations

import re
from collections.abc import Iterable
from dataclasses import dataclass

# MHz (4–5 digits), polarization (H/V/L/R), symbol rate (4–5 digits).
_FREQ_RE = re.compile(r"^(\d{4,5})\s+([HVLR])\s+(\d{4,5})$")

MHZ_MIN = 2000
MHZ_MAX = 13000
SR_MIN = 500
SR_MAX = 60000


@dataclass(frozen=True)
class Frequency:
    mhz: int
    pol: str  # H | V | L | R
    sr: int


UNPARSEABLE = "unparseable"
OUT_OF_DOMAIN = "out_of_domain"


def parse_frequency(value: str | None) -> tuple[Frequency | None, str | None]:
    """Return ``(frequency, reason)``.

    ``reason`` is ``None`` on success, else ``"unparseable"`` (kept as a note) or
    ``"out_of_domain"`` (rejected and logged).
    """
    if not value:
        return None, UNPARSEABLE
    text = value.strip().replace("Н", "H")  # Cyrillic Н -> Latin H
    m = _FREQ_RE.match(text)
    if not m:
        return None, UNPARSEABLE
    mhz = int(m.group(1))
    pol = m.group(2)
    sr = int(m.group(3))
    if not (MHZ_MIN <= mhz <= MHZ_MAX) or not (SR_MIN <= sr <= SR_MAX):
        return None, OUT_OF_DOMAIN
    return Frequency(mhz, pol, sr), None


def unique_frequencies(frequencies: Iterable[Frequency]) -> list[Frequency]:
    """Drop repeated tunings (one rights carriage lists some twice), keeping first-seen order."""
    return list(dict.fromkeys(frequencies))
