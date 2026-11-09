"""sporteventz's pure parse and normalize on the pages captured from the site (D6 T053, R21).

The fixtures under ``fixtures/sporteventz/2026-11-06`` are one sport page and its data answer for
each of the four sports, plus the site's ``robots.txt``, captured from the host on 2026-11-06. The
data URLs carry ``client_tz_offset=%2B0300``: the site answered 05:00 for ``+0300`` and 02:00 for
``+0000`` for the same event, so the offset is honoured and this adapter converts with it.
"""

from __future__ import annotations

import json
from datetime import UTC, date, datetime
from pathlib import Path
from typing import Any
from urllib.robotparser import RobotFileParser

import pytest

from app.adapters.base import LayoutChanged, RawPage
from app.adapters.sporteventz import PAGE_URL, SPORTS, SporteventzAdapter

FIXTURES = Path(__file__).resolve().parents[1] / "fixtures" / "sporteventz" / "2026-11-06"


def _data_url(sport: str = "basketball") -> str:
    method, url = (FIXTURES / f"{sport}.url.txt").read_text(encoding="utf-8").split()
    assert method == "post"  # the old tool tries POST first, and the site answered it (T052)
    return url


def _data_page(
    body: bytes | None = None,
    *,
    sport: str = "basketball",
    url: str | None = None,
) -> RawPage:
    return RawPage(
        url=url or _data_url(sport),
        status=200,
        body=(FIXTURES / f"{sport}.json").read_bytes() if body is None else body,
        content_type="text/plain",
    )


def _payload(*records: dict[str, Any]) -> bytes:
    return json.dumps({"Result": "OK", "Records": list(records)}, ensure_ascii=False).encode()


def _record(**overrides: Any) -> dict[str, Any]:
    record: dict[str, Any] = {
        "@id": "900001",
        "Begin": "Friday, 06 November 2026 05:00",
        "Sport": {"#text": "Basketball"},
        "Team1": {"#text": "Phoenix Suns"},
        "Team2": {"#text": "Orlando Magic"},
        "Tournament": {"#text": "NBA"},
        "Category": {"#text": "USA"},
        "Channels": {"Channel": []},
    }
    record.update(overrides)
    return record


def _adapter() -> SporteventzAdapter:
    return SporteventzAdapter(fetcher=None)


def test_an_access_page_is_not_a_data_page() -> None:
    page = RawPage(
        url=PAGE_URL.format(slug="basketball"),
        status=200,
        body=(FIXTURES / "basketball.html").read_bytes(),
        content_type="text/html",
    )

    assert _adapter().parse(page) == []


def test_parse_reads_every_field_of_a_real_answer() -> None:
    adapter = _adapter()

    items = adapter.parse(_data_page())

    item = next(found for found in items if found.external_id == "73719544")
    assert (item.home, item.away) == ("Phoenix Suns", "Orlando Magic")
    assert (item.sport, item.match_date) == ("basketball", date(2026, 11, 6))
    assert (item.competition, item.stage) == ("NBA", "USA")
    assert item.wall_time == "05:00"
    assert (item.home_logo, item.away_logo, item.competition_logo) == (None, None, None)
    assert item.home_external_id is None and item.away_external_id is None
    # Both channels are German, so the site's order is kept and slot 2 is the only one left.
    assert item.broadcasts == ("Sky Sport Mix HD", "Sky Sport Top Event HD")
    assert adapter.skipped == []


def test_every_other_sport_on_a_page_is_skipped_and_counted() -> None:
    adapter = _adapter()
    page = _data_page(
        _payload(
            _record(**{"@id": "1"}),
            _record(**{"@id": "2", "Sport": {"#text": "Football"}}),
            _record(**{"@id": "3", "Sport": {"#text": "Rugby"}}),
        ),
        url=_data_url(),
    )

    items = adapter.parse(page)

    assert [item.external_id for item in items] == ["1"]
    assert adapter.skipped == [
        {"ref": "2", "reason": "football"},
        {"ref": "3", "reason": "other_sport"},
    ]


def test_a_team_playing_itself_is_skipped() -> None:
    """The source has broken records such as «Flamengo RJ × Flamengo RJ» (SPORTS.html line 313)."""
    adapter = _adapter()

    items = adapter.parse(
        _data_page(_payload(_record(**{"@id": "1", "Team2": {"#text": "Phoenix Suns"}})), url=_data_url())
    )

    assert items == []
    assert adapter.skipped == [{"ref": "1", "reason": "same_team_twice"}]


def test_a_missing_records_key_is_a_changed_page() -> None:
    page = _data_page(json.dumps({"Result": "OK"}).encode(), url=_data_url())

    with pytest.raises(LayoutChanged, match="Records"):
        _adapter().parse(page)


def test_a_missing_access_key_is_a_changed_page() -> None:
    page = _data_page(b"", url=_data_url())

    with pytest.raises(LayoutChanged, match="access key"):
        _adapter().parse(page)


def test_a_non_ok_result_is_a_changed_page() -> None:
    page = _data_page(json.dumps({"Result": "ERROR", "Records": []}).encode(), url=_data_url())

    with pytest.raises(LayoutChanged, match="ERROR"):
        _adapter().parse(page)


def test_the_printed_time_is_converted_from_the_offset_the_request_sent() -> None:
    adapter = _adapter()

    item = next(found for found in adapter.parse(_data_page()) if found.external_id == "73719544")
    normalized = adapter.normalize(item)

    # 05:00 at +0300 is 02:00 UTC; Cairo's own clock would be an hour off in winter.
    assert normalized.kickoff_at == datetime(2026, 11, 6, 2, 0, tzinfo=UTC)
    assert normalized.kickoff_at is not None and normalized.kickoff_at.utcoffset() == UTC.utcoffset(None)
    assert normalized.time_tbd is False


def test_a_record_with_no_clock_has_no_kickoff() -> None:
    adapter = _adapter()

    [item] = adapter.parse(_data_page(_payload(_record(Begin="Friday, 06 November 2026")), url=_data_url()))
    normalized = adapter.normalize(item)

    assert item.wall_time == ""
    assert (normalized.kickoff_at, normalized.time_tbd) == (None, True)


def test_the_channels_are_ranked_and_slot_two_is_cut_at_a_whole_name() -> None:
    adapter = _adapter()
    channels = {
        "Channel": [
            {"Name": "Sky Sport DE", "Country": "DE"},
            {"Name": "beIN Sports 1", "Country": "QA"},
            {"Name": "Some Channel", "Country": "EG"},
            {"Name": "SSC 1", "Country": "SA"},
            {"Name": "Another Channel", "Country": "US"},
        ]
    }

    [item] = adapter.parse(_data_page(_payload(_record(Channels=channels)), url=_data_url()))

    assert item.broadcasts == (
        "beIN Sports 1",
        "SSC 1 · Some Channel · Sky Sport DE · Another Channel",
    )

    long_names = {
        "Channel": [
            {"Name": "First Channel Of The Site", "Country": "DE"},
            {"Name": "Second Very Long Channel Name", "Country": "DE"},
            {"Name": "Third Very Long Channel Name", "Country": "DE"},
            {"Name": "Fourth Very Long Channel Name", "Country": "DE"},
            {"Name": "Fifth Very Long Channel Name", "Country": "DE"},
        ]
    }
    [cut] = adapter.parse(_data_page(_payload(_record(Channels=long_names)), url=_data_url()))
    assert cut.broadcasts is not None
    assert len(cut.broadcasts[1]) <= 80
    assert cut.broadcasts[1] == "Second Very Long Channel Name · Third Very Long Channel Name"


def test_the_saved_robots_txt_allows_both_paths_this_adapter_reads() -> None:
    robots = RobotFileParser()
    robots.parse((FIXTURES / "robots.txt").read_text(encoding="utf-8").splitlines())

    assert robots.can_fetch("*", PAGE_URL.format(slug="basketball")) is True
    assert robots.can_fetch("*", _data_url()) is True
    assert robots.can_fetch("*", "https://www.sporteventz.com/administrator/") is False


def test_every_sport_of_the_run_has_a_saved_page_and_answer() -> None:
    assert SPORTS == ("basketball", "handball", "volleyball", "tennis")
    for sport in SPORTS:
        assert (FIXTURES / f"{sport}.html").is_file()
        assert (FIXTURES / f"{sport}.json").is_file()
        items = _adapter().parse(_data_page(sport=sport))
        assert items, sport
        assert {item.sport for item in items} == {sport}


# --- a changed record shape (B2-R1-1) -----------------------------------------------------------


def _saved_records(sport: str = "basketball") -> list[dict[str, Any]]:
    records = json.loads((FIXTURES / f"{sport}.json").read_bytes())["Records"]
    assert isinstance(records, list) and records
    return records


def _renamed(key: str, to: str, sport: str = "basketball") -> bytes:
    """The saved answer with one record field renamed in every record, as a site change would."""
    payload = json.loads((FIXTURES / f"{sport}.json").read_bytes())
    payload["Records"] = [
        {(to if name == key else name): value for name, value in record.items()} for record in payload["Records"]
    ]
    return json.dumps(payload, ensure_ascii=False).encode()


@pytest.mark.parametrize(
    ("key", "reason"), [("Team1", "missing_teams"), ("Begin", "unreadable_begin"), ("Sport", "missing_sport")]
)
def test_a_saved_answer_with_a_field_renamed_is_a_changed_page(key: str, reason: str) -> None:
    """FR-037: records that no longer read are a changed page at once, not a quiet week."""
    adapter = _adapter()

    with pytest.raises(LayoutChanged, match=reason):
        adapter.parse(_data_page(_renamed(key, key + "Name"), url=_data_url()))

    # The refused records are still counted, so the failed run can say why.
    assert len(adapter.skipped) == len(_saved_records())
    assert {entry["reason"] for entry in adapter.skipped} == {reason}


def test_a_saved_answer_with_sport_reshaped_is_a_changed_page() -> None:
    """FR-037: a ``Sport`` that no longer carries ``#text`` is a moved field, not another sport."""
    payload = json.loads((FIXTURES / "basketball.json").read_bytes())
    for record in payload["Records"]:
        record["Sport"] = {"name": "Basketball"}
    adapter = _adapter()

    with pytest.raises(LayoutChanged, match="missing_sport"):
        adapter.parse(_data_page(json.dumps(payload, ensure_ascii=False).encode(), url=_data_url()))

    assert {entry["reason"] for entry in adapter.skipped} == {"missing_sport"}


def test_one_record_without_a_sport_among_good_ones_is_skipped_as_missing_sport() -> None:
    adapter = _adapter()
    page = _data_page(_payload(_record(**{"@id": "1"}), _record(**{"@id": "2", "Sport": None})), url=_data_url())

    assert [item.external_id for item in adapter.parse(page)] == ["1"]
    assert adapter.skipped == [{"ref": "2", "reason": "missing_sport"}]


def test_records_that_are_not_objects_are_a_changed_page() -> None:
    with pytest.raises(LayoutChanged, match="not_an_object"):
        _adapter().parse(_data_page(_payload("73719544", "73719545"), url=_data_url()))  # type: ignore[arg-type]


def test_an_answer_of_other_sports_only_is_not_a_changed_page() -> None:
    adapter = _adapter()
    page = _data_page(
        _payload(
            _record(**{"@id": "1", "Sport": {"#text": "Football"}}),
            _record(**{"@id": "2", "Sport": {"#text": "Rugby"}}),
        ),
        url=_data_url(),
    )

    assert adapter.parse(page) == []
    assert [entry["reason"] for entry in adapter.skipped] == ["football", "other_sport"]


def test_one_unreadable_record_among_good_ones_is_skipped_and_counted() -> None:
    adapter = _adapter()
    page = _data_page(_payload(_record(**{"@id": "1"}), _record(**{"@id": "2", "Team1": None})), url=_data_url())

    items = adapter.parse(page)

    assert [item.external_id for item in items] == ["1"]
    assert adapter.skipped == [{"ref": "2", "reason": "missing_teams"}]
    assert adapter.skip_counts() == {"missing_teams": 1}


def test_an_answer_with_no_records_is_a_quiet_day_not_a_changed_page() -> None:
    adapter = _adapter()

    assert adapter.parse(_data_page(_payload(), url=_data_url())) == []
    assert adapter.skipped == []


class TestTheFetchTask:
    """The run, through ``adapters.fetch``, on the saved pages served by a mock transport."""

    def _serve(self, monkeypatch: pytest.MonkeyPatch, answer: Any) -> list[Any]:
        import httpx

        from app.adapters import tasks as module
        from app.adapters.fetcher import HttpFetcher

        def handler(request: httpx.Request) -> httpx.Response:
            path = request.url.path
            if path.startswith("/en/other-sport/"):
                sport = path.rsplit("/", 1)[1].removesuffix(".html")
                return httpx.Response(200, content=(FIXTURES / f"{sport}.html").read_bytes())
            sport = next(
                sport for sport in SPORTS if _data_url(sport).split("accesskey=")[1].split("&")[0] in str(request.url)
            )
            return httpx.Response(200, content=answer(sport))

        class Allowed:
            def take(self, host: str, now: float | None = None) -> bool:
                return True

        sent: list[Any] = []
        monkeypatch.setattr(
            module,
            "http_fetcher",
            lambda: HttpFetcher(
                limiter=Allowed(),  # type: ignore[arg-type]
                user_agent="MadarSat/test",
                client=httpx.Client(transport=httpx.MockTransport(handler), follow_redirects=False),
            ),
        )
        monkeypatch.setattr(module, "send_ingest", sent.append)
        return sent

    def test_a_renamed_team1_fails_the_run_with_its_skip_counts(self, redis_client, monkeypatch) -> None:
        from app.adapters.tasks import fetch

        sent = self._serve(monkeypatch, lambda sport: _renamed("Team1", "HomeTeam", sport))

        fetch.apply(args=("sporteventz", "2026-11-06")).get()

        assert len(sent) == 1
        assert sent[0].error == "layout_changed"
        assert sent[0].items == []
        # The first sport's records are what failed it; they travel with the run (FR-030).
        assert sent[0].parse_skipped == {"missing_teams": len(_saved_records("basketball"))}

    def test_a_good_run_carries_its_skip_counts_to_ingest(self, redis_client, monkeypatch) -> None:
        from app.adapters.tasks import fetch

        def with_rugby(sport: str) -> bytes:
            payload = json.loads((FIXTURES / f"{sport}.json").read_bytes())
            payload["Records"].append(_record(**{"@id": "rugby-1", "Sport": {"#text": "Rugby"}}))
            return json.dumps(payload, ensure_ascii=False).encode()

        sent = self._serve(monkeypatch, with_rugby)

        fetch.apply(args=("sporteventz", "2026-11-06")).get()

        assert sent[0].error is None
        assert len(sent[0].items) == 191
        assert sent[0].parse_skipped == {"other_sport": 4}
