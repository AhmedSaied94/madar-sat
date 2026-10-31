"""Structured JSON logs on stdout for every worker process (constitution IX, review B2-R1-15).

The default Celery logging at WARNING drops ``log.info`` lines and every ``extra=`` field, so the
"a run was skipped because the lock was held" events never reached anyone. ``setup_logging`` is
connected to Celery's ``setup_logging`` signal, which each worker, beat and the CLI fire once.

What a record carries is not ours to trust (B1-R2-7). Celery attaches the whole task payload to a
failure (``data`` with ``args`` and ``kwargs``, up to 2 MB of pages), and ``httpx`` logs every
request's full URL at INFO, which for the bridge carries the old project's API key (D15, FR-027).
So the payload is dropped, every field and the traceback are capped, and ``httpx``/``httpcore``
stay at WARNING.
"""

from __future__ import annotations

import json
import logging
import sys
from datetime import UTC, datetime
from typing import Any

from celery import signals

# The attributes every LogRecord carries; anything else came from ``extra=``.
RESERVED = frozenset(logging.LogRecord("", 0, "", 0, "", (), None).__dict__) | {"message", "asctime"}

# Never copied: a task payload. It duplicates ``args``/``kwargs`` and holds every scraped page.
DROPPED = frozenset({"data", "args", "kwargs"})

# A field is a diagnostic, not a payload. Caps keep one record on one readable line.
MAX_FIELD_CHARS = 256
MAX_MESSAGE_CHARS = 512
MAX_EXC_CHARS = 2048
MAX_LINE_CHARS = 8192

# These log every request's URL at INFO, which is where the bridge's key used to land.
QUIET_LOGGERS = ("httpx", "httpcore")


def _cap(text: str, limit: int) -> str:
    if len(text) <= limit:
        return text
    return f"{text[:limit]}…({len(text)} chars)"


def _field(value: Any) -> Any:
    """One ``extra=`` value: a scalar stays as is, anything else becomes capped text."""
    if isinstance(value, (bool, int, float)) or value is None:
        return value
    text = value if isinstance(value, str) else json.dumps(value, ensure_ascii=False, default=str)
    return _cap(text, MAX_FIELD_CHARS)


class JsonFormatter(logging.Formatter):
    """One JSON object per line: time, level, logger, message, then every capped ``extra=`` key."""

    def format(self, record: logging.LogRecord) -> str:
        payload: dict[str, Any] = {
            "ts": datetime.fromtimestamp(record.created, UTC).isoformat().replace("+00:00", "Z"),
            "level": record.levelname,
            "logger": record.name,
            "message": _cap(record.getMessage(), MAX_MESSAGE_CHARS),
        }
        for key, value in record.__dict__.items():
            if key in RESERVED or key in DROPPED or key.startswith("_"):
                continue
            payload[key] = _field(value)
        if record.exc_info is not None:
            payload["exc"] = _cap(self.formatException(record.exc_info), MAX_EXC_CHARS)
        line = json.dumps(payload, ensure_ascii=False, default=str)
        if len(line) <= MAX_LINE_CHARS:
            return line
        # A traceback is the other thing that grows without bound: keep the headers, drop the rest.
        payload.pop("exc", None)
        payload["truncated"] = True
        line = json.dumps(payload, ensure_ascii=False, default=str)
        if len(line) <= MAX_LINE_CHARS:
            return line
        return json.dumps(
            {k: payload[k] for k in ("ts", "level", "logger", "message") if k in payload} | {"truncated": True},
            ensure_ascii=False,
            default=str,
        )


def setup_logging(level: str = "INFO") -> None:
    """Send the root logger to stdout as JSON, with the chatty HTTP clients quiet."""
    handler = logging.StreamHandler(sys.stdout)
    handler.setFormatter(JsonFormatter())
    root = logging.getLogger()
    root.handlers[:] = [handler]
    root.setLevel(level)
    for name in QUIET_LOGGERS:
        # INFO on httpx writes "HTTP Request: GET <full URL>"; a URL can carry a key or a token.
        logging.getLogger(name).setLevel(logging.WARNING)


@signals.setup_logging.connect  # type: ignore[untyped-decorator]  # celery's decorator is untyped
def _configure(**_: Any) -> None:
    setup_logging()
