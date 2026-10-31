"""The versioned ``ScrapeResult`` message between the fetch host and VPS-2 (T070, R15/R21).

Pages travel gzipped and base64-encoded inside the message, because the home box has no shared
disk and no database (FR-028). The whole message is capped at 2 MB; ``ingest`` accepts the current
schema and, once a second version exists, the one before it, and rejects anything else loudly.
"""

from __future__ import annotations

import base64
import gzip
import json
import warnings
import zlib
from collections.abc import Sequence
from datetime import datetime
from typing import Any, Self

from pydantic import BaseModel, ConfigDict, Field, field_validator, model_validator

from app.adapters.base import ParsedFixture, RawPage

CURRENT_SCHEMA = 1
MAX_BYTES = 2 * 1024 * 1024
MAX_ERROR = 120
# The fetcher's per-page cap. The compressed message is capped at 2 MB, but gzip can inflate
# 1.5 MB into gigabytes, so the inflate itself is bounded (B2-R1-13).
MAX_PAGE_BYTES = 5 * 1024 * 1024
# A window (today to +3) is at most four pages, and the whole run is bounded too: 250 small pages
# fit under 2 MB compressed and still inflate to gigabytes (B2-R2-16).
MAX_PAGES = 4
MAX_TOTAL_BYTES = 16 * 1024 * 1024


class MessageTooLarge(Exception):
    """The message would exceed 2 MB and must be split or trimmed before it is queued."""


class UnsupportedSchema(Exception):
    """The sender speaks a schema this worker does not know."""


class PageMessage(BaseModel):
    model_config = ConfigDict(extra="forbid")

    url: str
    status: int = Field(ge=100, le=599)
    fetched_at: datetime
    gz_b64: str


# ``schema`` is the wire name in contracts/ingestion.md. It shadows ``BaseModel.schema()``, a
# method pydantic deprecated: the warning is about that method, not about this field.
with warnings.catch_warnings():
    warnings.simplefilter("ignore", UserWarning)

    class ScrapeResult(BaseModel):
        """contracts/ingestion.md §ScrapeResult message (schema 1)."""

        model_config = ConfigDict(extra="forbid")

        # `schema` is the wire name (contracts/ingestion.md); pydantic's BaseModel has a deprecated
        # `schema()` method, hence the ignore.
        schema: int  # type: ignore[assignment]
        source: str
        run_id: str
        started_at: datetime
        finished_at: datetime
        fetched_on: str
        pages: list[PageMessage] = Field(default_factory=list)
        items: list[ParsedFixture] = Field(default_factory=list)
        http_errors: int = 0
        error: str | None = None

        @classmethod
        def accepted_schemas(cls, current: int = CURRENT_SCHEMA) -> frozenset[int]:
            """The current schema, and the previous one from the first change on (R21)."""
            return frozenset({current}) if current <= 1 else frozenset({current - 1, current})

        @field_validator("schema")
        @classmethod
        def _known_schema(cls, value: int) -> int:
            if value not in cls.accepted_schemas():
                raise UnsupportedSchema(f"ScrapeResult schema {value} is not accepted by this worker")
            return value

        @field_validator("error")
        @classmethod
        def _short_error(cls, value: str | None) -> str | None:
            return value[:MAX_ERROR] if value else None

        @model_validator(mode="after")
        def _size_cap(self) -> Self:
            if len(self.model_dump_json().encode("utf-8")) > MAX_BYTES:
                raise MessageTooLarge(f"the message is over the {MAX_BYTES} byte cap; split the run")
            return self

        @model_validator(mode="before")
        @classmethod
        def _refuse_before_parsing(cls, data: Any) -> Any:
            """Check the wire size before pydantic copies the payload into models (B2-R2-16)."""
            if isinstance(data, dict):
                encoded = json.dumps(data, ensure_ascii=False, default=str)
                if len(encoded.encode("utf-8")) > MAX_BYTES:
                    raise MessageTooLarge(f"the message is over the {MAX_BYTES} byte cap; split the run")
            return data

        @classmethod
        def build(
            cls,
            *,
            source: str,
            run_id: str,
            started_at: datetime,
            finished_at: datetime,
            fetched_on: str,
            pages: Sequence[RawPage],
            items: Sequence[ParsedFixture] = (),
            http_errors: int = 0,
            error: str | None = None,
        ) -> ScrapeResult:
            if len(pages) > MAX_PAGES:
                raise MessageTooLarge(
                    f"the message carries {len(pages)} pages; a window is at most {MAX_PAGES} (B2-R2-16)"
                )
            return cls(
                schema=CURRENT_SCHEMA,
                source=source,
                run_id=run_id,
                started_at=started_at,
                finished_at=finished_at,
                fetched_on=fetched_on,
                pages=[_encode_page(page) for page in pages],
                items=list(items),
                http_errors=http_errors,
                error=error,
            )

        @classmethod
        def failed(
            cls,
            *,
            source: str,
            run_id: str,
            started_at: datetime,
            finished_at: datetime,
            fetched_on: str,
            http_errors: int,
            error: str,
        ) -> ScrapeResult:
            """A failed fetch still travels, so the run row records the failure (R15)."""
            return cls.build(
                source=source,
                run_id=run_id,
                started_at=started_at,
                finished_at=finished_at,
                fetched_on=fetched_on,
                pages=[],
                items=[],
                http_errors=http_errors,
                error=error,
            )

        def raw_pages(self) -> list[RawPage]:
            if len(self.pages) > MAX_PAGES:
                raise MessageTooLarge(f"the message carries {len(self.pages)} pages; at most {MAX_PAGES} are expected")
            pages: list[RawPage] = []
            total = 0
            for page in self.pages:
                body = _inflate(page)
                total += len(body)
                if total > MAX_TOTAL_BYTES:
                    # Each page is under its own cap; a run of many pages is still a bomb (B2-R2-16).
                    raise MessageTooLarge(f"the run inflates past the {MAX_TOTAL_BYTES} byte total cap")
                pages.append(RawPage(url=page.url, status=page.status, body=body, fetched_at=page.fetched_at))
            return pages

        def as_task_arg(self) -> dict[str, Any]:
            """The payload ``adapters.ingest`` receives (JSON-serialisable)."""
            return self.model_dump(mode="json")


def _inflate(page: PageMessage) -> bytes:
    """Inflate one page, refusing more than the fetcher's cap (B2-R1-13).

    ``zlib.decompressobj.decompress(data, max_length)`` stops at ``max_length`` and keeps the rest in
    ``unconsumed_tail``: a bomb therefore costs 5 MB, not the gigabytes it would expand to.
    """
    inflater = zlib.decompressobj(16 + zlib.MAX_WBITS)  # 16: gzip framing
    body = inflater.decompress(base64.b64decode(page.gz_b64), MAX_PAGE_BYTES + 1)
    if len(body) > MAX_PAGE_BYTES or inflater.unconsumed_tail:
        raise MessageTooLarge(f"{page.url} inflates past the {MAX_PAGE_BYTES} byte page cap")
    return body


def _encode_page(page: RawPage) -> PageMessage:
    return PageMessage(
        url=page.url,
        status=page.status,
        fetched_at=page.fetched_at,
        gz_b64=base64.b64encode(gzip.compress(page.body, mtime=0)).decode("ascii"),
    )
