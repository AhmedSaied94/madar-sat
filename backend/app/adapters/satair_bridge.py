"""The read-only Firestore bridge to the old Sat Air data (T074, R19, FR-027).

It reads the old app's own `matchDays` documents through Firestore's REST API, one GET per
Cairo day, and feeds the same upsert pipeline as ysscores as source ``legacy``:

- the id in the document is the Sat Air match id, which is ``matches.legacy_id`` (D1's key for
  these rows), so a snapshot row and its bridge update stay one row;
- ``ysMatchId`` is recorded as an ysscores external id, so the two sources converge;
- a ``404`` means the old app has no document for that day: not an error, an empty day;
- the old project's id and key come from VPS-2's environment only (D15, FR-052) and are never
  logged, tested with, or committed.
"""

from __future__ import annotations

import json
from datetime import date
from typing import Any
from urllib.parse import urlsplit

from app.adapters.base import (
    DateWindow,
    FixtureLink,
    LayoutChanged,
    NormalizedFixture,
    ParsedFixture,
    RawPage,
    clean_text,
    normalize_fixture,
)
from app.adapters.config import get_adapter_settings
from app.adapters.fetcher import FetchError, HttpFetcher

DOCS_URL = "https://firestore.googleapis.com/v1/projects/{project}/databases/(default)/documents/matchDays/{day}"
ALLOWED_HOSTS = frozenset({"firestore.googleapis.com"})
PLACEHOLDER_KEYS = frozenset({"", "-", "غير مدرج", "غير محدد"})


class BridgeNotConfigured(RuntimeError):
    """SATAIR_FIREBASE_PROJECT_ID and SATAIR_FIREBASE_API_KEY are missing from the environment."""


class SatairBridgeAdapter:
    name = "legacy"
    allowed_hosts = ALLOWED_HOSTS

    def __init__(self, fetcher: HttpFetcher | None, project_id: str | None = None, api_key: str | None = None) -> None:
        self.fetcher = fetcher
        self._project_id = project_id
        self._api_key = api_key
        # The pages fetched so far: the fetch task saves them when the next day fails (B2-R1-9).
        self.pages: list[RawPage] = []

    def _credentials(self) -> tuple[str, str]:
        if self._project_id and self._api_key:
            return self._project_id, self._api_key
        settings = get_adapter_settings()
        try:
            return settings.require_bridge()
        except RuntimeError as exc:  # the bridge is the only reader, so it fails here and nowhere else
            raise BridgeNotConfigured(str(exc)) from exc

    # --- fetch ---------------------------------------------------------------------------

    def document_url(self, day: date) -> str:
        project, _ = self._credentials()
        return DOCS_URL.format(project=project, day=day.isoformat())

    def fetch(self, window: DateWindow) -> list[RawPage]:
        if self.fetcher is None:
            raise RuntimeError("the bridge needs a fetcher to fetch")
        _, api_key = self._credentials()
        pages: list[RawPage] = []
        self.pages = pages
        for day in window:
            url = self.document_url(day)
            try:
                # The key travels in a header, never in the URL: httpx logs the URL at INFO and a
                # 2 MB body's error message carries it too (B2-R2-5, D15).
                page = self.fetcher.get(url, allowed_hosts=self.allowed_hosts, headers={"X-Goog-Api-Key": api_key})
            except FetchError as exc:
                if exc.status == 404:  # the old app has no document for that day
                    pages.append(RawPage(url=f"{url}#{day.isoformat()}", status=404, body=b""))
                    continue
                raise
            pages.append(
                RawPage(
                    url=f"{url}#{day.isoformat()}",
                    status=page.status,
                    body=page.body,
                    content_type=page.content_type,
                    fetched_at=page.fetched_at,
                )
            )
        return pages

    # --- parse (pure) --------------------------------------------------------------------

    def parse(self, page: RawPage) -> list[ParsedFixture]:
        if page.status == 404 or not page.body:
            return []
        day = day_of(page.url)
        document = _json(page)
        fields = document.get("fields")
        if not isinstance(fields, dict):
            raise LayoutChanged("the document has no fields")
        raw_matches = _plain(fields.get("matches"))
        if raw_matches is None:
            return []  # a document with no fixtures is a quiet day, not a layout change
        if not isinstance(raw_matches, list):
            raise LayoutChanged("matches is not an array")
        items: list[ParsedFixture] = []
        for raw in raw_matches:
            if not isinstance(raw, dict):
                continue
            items.append(self._item(raw, day))
        return items

    def _item(self, raw: dict[str, Any], day: date) -> ParsedFixture:
        legacy_id = _text(raw.get("id"))
        return ParsedFixture(
            external_id=None,  # ysscores' own id, if the old app ever carries one
            url=None,
            competition=_text(raw.get("competition")),
            competition_logo=None,
            stage=_text(raw.get("competitionStage")),
            home=_text(raw.get("team1")),
            away=_text(raw.get("team2")),
            home_logo=None,
            away_logo=None,
            home_external_id=None,
            away_external_id=None,
            wall_time=_text(raw.get("time")) or "--:--",
            match_date=day,
            links=tuple(_links(raw)),
            ys_match_id=_text(raw.get("ysMatchId")),
            legacy_id=legacy_id,
        )

    # --- normalize -----------------------------------------------------------------------

    def normalize(self, item: ParsedFixture) -> NormalizedFixture:
        return normalize_fixture(item)


def _links(raw: dict[str, Any]) -> list[FixtureLink]:
    """The channel links the document lists, with their hidden flag and commentators (R19)."""
    channel_ids = _as_list(raw.get("channelIds"))
    hidden = set(_as_list(raw.get("hiddenChannels")))
    commentators = raw.get("channelCommentators")
    commentators = commentators if isinstance(commentators, dict) else {}
    links: list[FixtureLink] = []
    for channel_id in channel_ids:
        ref = _text(channel_id)
        if not ref:
            continue
        entry = commentators.get(ref)
        entry = entry if isinstance(entry, dict) else {}
        first = clean_text(_text(entry.get("name")))
        second = clean_text(_text(entry.get("name2")))
        if second is not None and (first is None or second == first):
            second = None
        links.append(FixtureLink(channel_ref=ref, hidden=ref in hidden, commentator=first, commentator2=second))
    return links


def _text(value: Any) -> str | None:
    if value is None:
        return None
    if isinstance(value, bool):
        return None
    text = " ".join(str(value).split())
    if not text or text in PLACEHOLDER_KEYS:
        return None
    return text


def _as_list(value: Any) -> list[Any]:
    return value if isinstance(value, list) else []


def _json(page: RawPage) -> dict[str, Any]:
    try:
        document = json.loads(page.body.decode("utf-8"))
    except (UnicodeDecodeError, json.JSONDecodeError) as exc:
        raise LayoutChanged("the response is not JSON") from exc
    if not isinstance(document, dict):
        raise LayoutChanged("the response is not a document")
    return document


def _plain(value: Any) -> Any:
    """Firestore's typed values to plain JSON, as ``export-firestore.mjs`` does (R19).

    Accepts both the REST shape (``{"stringValue": ...}``) and values the caller already converted,
    so a saved fixture and a live response parse the same way.
    """
    if not isinstance(value, dict):
        return value
    if "stringValue" in value:
        return value["stringValue"]
    if "integerValue" in value:
        raw = value["integerValue"]
        return int(raw) if str(raw).lstrip("-").isdigit() else raw
    if "doubleValue" in value:
        return float(value["doubleValue"])
    if "booleanValue" in value:
        return bool(value["booleanValue"])
    if "timestampValue" in value:
        return value["timestampValue"]
    if "nullValue" in value:
        return None
    if "mapValue" in value:
        inner = value["mapValue"]
        fields = inner.get("fields", {}) if isinstance(inner, dict) else {}
        return {key: _plain(field) for key, field in fields.items()}
    if "arrayValue" in value:
        inner = value["arrayValue"]
        values = inner.get("values", []) if isinstance(inner, dict) else []
        return [_plain(item) for item in values]
    return value


def day_of(url: str) -> date:
    """The Cairo day a page answers, carried in the URL fragment by ``fetch``."""
    try:
        return date.fromisoformat(urlsplit(url).fragment)
    except ValueError as exc:  # pragma: no cover - a caller bug, not a page problem
        raise ValueError(f"the page URL must carry its day as #YYYY-MM-DD, got {url!r}") from exc
