"""Arabic-insensitive normalization, identical to the ``ar_normalize`` SQL function.

The rules (from ``../old_app/migration/schema.sql`` and the old app's
``normalizeArabic``): lowercase, strip tashkeel and tatweel, أ/إ/آ/ٱ → ا, ة → ه,
ى/ئ → ي, ؤ → و, punctuation and symbols → space, collapse spaces, trim.
"""

from __future__ import annotations

import re

_TASHKEEL = re.compile(r"[ً-ْٰـ]")  # U+064B..U+0650 (fatha..sukun), U+0670, U+0640 (tatweel)
_TRANSLATE = str.maketrans("أإآٱةىئؤ", "ااااهييو")
_PUNCT = re.compile(
    r"[!-/:-@[-`{-~\u00a0-\u00bf\u00d7\u00f7\u060c\u061b\u061f"
    r"\u066a-\u066d\u06d4\u2000-\u206f\u2190-\u2bff"
    r"\U0001F000-\U0001FAFF]"
)
_WS = re.compile(r"[ \t\r\n]+")


def ar_normalize(value: str | None) -> str:
    if not value:
        return ""
    s = value.lower()
    s = _TASHKEEL.sub("", s)
    s = s.translate(_TRANSLATE)
    s = _PUNCT.sub(" ", s)
    s = _WS.sub(" ", s)
    return s.strip()
