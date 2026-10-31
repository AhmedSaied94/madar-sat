"""The Firestore bridge: typed values, links, orphans and the ysscores rule (T061, R19)."""

from __future__ import annotations

import dataclasses
import json
from datetime import date
from pathlib import Path

import pytest
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.adapters.base import RawPage
from app.adapters.satair_bridge import SatairBridgeAdapter
from app.adapters.upsert import UpsertPipeline
from app.db.models import Channel, Commentator, Match, MatchChannel, MatchExternalId

FIXTURES = Path(__file__).resolve().parents[1] / "fixtures" / "satair_bridge"
DAY = date(2026, 10, 31)


def _page(name: str = "2026-10-31.json", *, day: str = "2026-10-31") -> RawPage:
    return RawPage(
        url=f"https://firestore.googleapis.com/v1/projects/p/databases/(default)/documents/matchDays/{day}#{day}",
        status=200,
        body=(FIXTURES / name).read_bytes(),
    )


@pytest.fixture
def adapter() -> SatairBridgeAdapter:
    return SatairBridgeAdapter(fetcher=None, project_id="example-project", api_key="test-key")  # type: ignore[arg-type]


def channel_id(session: Session, legacy_id: str) -> int:
    return session.execute(select(Channel.id).where(Channel.legacy_id == legacy_id)).scalar_one()


class TestFetch:
    def test_the_request_is_one_get_per_day_to_the_match_days_document(self) -> None:
        calls: list[tuple[str, dict[str, str], dict[str, str]]] = []

        class Recorder:
            def get(
                self,
                url: str,
                allowed_hosts: frozenset[str],
                params: dict[str, str] | None = None,
                headers: dict[str, str] | None = None,
            ) -> RawPage:
                calls.append((url, params or {}, headers or {}))
                assert allowed_hosts == frozenset({"firestore.googleapis.com"})
                return RawPage(url=url, status=200, body=b'{"fields": {}}')

        from app.adapters.base import DateWindow

        bridge = SatairBridgeAdapter(fetcher=Recorder(), project_id="p-1", api_key="k-1")  # type: ignore[arg-type]
        bridge.fetch(DateWindow(days=(date(2026, 10, 31), date(2026, 11, 1))))
        assert [url for url, _, _ in calls] == [
            "https://firestore.googleapis.com/v1/projects/p-1/databases/(default)/documents/matchDays/2026-10-31",
            "https://firestore.googleapis.com/v1/projects/p-1/databases/(default)/documents/matchDays/2026-11-01",
        ]
        # The key travels in a header, never a query parameter: the URL is logged at INFO (B2-R2-5).
        assert all(params == {} for _, params, _ in calls)
        assert [headers.get("X-Goog-Api-Key") for _, _, headers in calls] == ["k-1", "k-1"]
        assert not any("key" in url for url, _, _ in calls)

    def test_a_missing_document_is_an_empty_day(self) -> None:
        from app.adapters.base import DateWindow
        from app.adapters.fetcher import FetchError

        class Missing:
            def get(
                self,
                url: str,
                allowed_hosts: frozenset[str],
                params: dict[str, str] | None = None,
                headers: dict[str, str] | None = None,
            ):
                raise FetchError(f"{url} answered 404", status=404)

        bridge = SatairBridgeAdapter(fetcher=Missing(), project_id="p-1", api_key="k-1")  # type: ignore[arg-type]
        (page,) = bridge.fetch(DateWindow(days=(date(2026, 11, 30),)))
        assert page.status == 404
        assert bridge.parse(page) == []


class TestParse:
    def test_the_typed_values_become_plain_json(self, adapter: SatairBridgeAdapter) -> None:
        items = {item.legacy_id: item for item in adapter.parse(_page())}
        new = items["bridge-new-1"]
        assert new.home == "الأهلي"
        assert new.away == "الزمالك"
        assert new.wall_time == "08:00 م"
        assert new.match_date == DAY
        assert new.competition == "الدوري المصري الممتاز"
        assert new.stage == "الجولة 10"
        assert new.ys_match_id is None  # an empty string is not an id

    def test_the_links_carry_the_hidden_flag_and_both_commentators(self, adapter: SatairBridgeAdapter) -> None:
        links = {link.channel_ref: link for link in adapter.parse(_page())[0].links}
        assert set(links) == {"ch-cyr", "ch-hidden", "orphan-channel-1"}
        assert links["ch-cyr"].hidden is False
        assert links["ch-cyr"].commentator == "معلق القناة الأولى"
        assert links["ch-hidden"].hidden is True
        assert links["ch-hidden"].commentator2 == "معلق ثان"
        assert links["orphan-channel-1"].commentator == "معلق قناة محذوفة"

    def test_placeholders_and_a_doubled_stage_are_cleaned(self, adapter: SatairBridgeAdapter) -> None:
        item = {i.legacy_id: i for i in adapter.parse(_page())}["bridge-placeholders-1"]
        normalized = adapter.normalize(item)
        assert normalized.home is None  # "" and "⚽" are placeholders, not teams
        assert normalized.competition is None  # «غير مدرج»
        assert normalized.stage == "نصف النهائي"
        assert normalized.time_tbd is True
        assert normalized.kickoff_at is None

    def test_no_card_sharing_label_is_read(self, adapter: SatairBridgeAdapter) -> None:
        item = {i.legacy_id: i for i in adapter.parse(_page())}["bridge-new-1"]
        normalized = adapter.normalize(item)
        stored = json.dumps(dataclasses.asdict(normalized), ensure_ascii=False, default=str)
        assert "يذكر أن" not in stored
        assert "شبكة قنوات اختبار" not in stored  # the manual broadcaster slot is not imported

    def test_a_day_without_matches_is_empty(self, adapter: SatairBridgeAdapter) -> None:
        page = RawPage(
            url="https://firestore.googleapis.com/v1/projects/p/databases/(default)/documents/matchDays/2026-11-03#2026-11-03",
            status=200,
            body=b'{"fields": {"matches": {"arrayValue": {}}}}',
        )
        assert adapter.parse(page) == []


class TestUpsert:
    def test_rows_key_on_the_sat_air_id_and_record_the_ysscores_one(
        self, sync_session: Session, loaded_snapshot
    ) -> None:
        adapter = SatairBridgeAdapter(fetcher=None, project_id="p", api_key="k")  # type: ignore[arg-type]
        items = [adapter.normalize(i) for i in adapter.parse(_page())]
        outcome = UpsertPipeline(sync_session, source="legacy").run(items)
        assert outcome.created >= 2

        joined = sync_session.execute(select(Match).where(Match.legacy_id == "bridge-new-1")).scalar_one()
        assert joined.source == "legacy"
        assert joined.competition_id is not None
        assert joined.home_team_id is not None
        # `ysMatchId` was empty for this one; the second row records 5802974 as an ysscores id.
        converged = sync_session.execute(
            select(MatchExternalId.match_id).where(
                MatchExternalId.source == "ysscores", MatchExternalId.external_id == "5802974"
            )
        ).scalar_one_or_none()
        assert converged is not None

    def test_an_orphan_channel_is_skipped_and_the_rest_linked(self, sync_session: Session, loaded_snapshot) -> None:
        adapter = SatairBridgeAdapter(fetcher=None, project_id="p", api_key="k")  # type: ignore[arg-type]
        items = [adapter.normalize(i) for i in adapter.parse(_page())]
        outcome = UpsertPipeline(sync_session, source="legacy").run(items)

        match_id = sync_session.execute(select(Match.id).where(Match.legacy_id == "bridge-new-1")).scalar_one()
        rows = {
            row.channel_id: row
            for row in sync_session.execute(select(MatchChannel).where(MatchChannel.match_id == match_id)).scalars()
        }
        assert set(rows) == {channel_id(sync_session, "ch-cyr"), channel_id(sync_session, "ch-hidden")}
        assert rows[channel_id(sync_session, "ch-hidden")].is_hidden is True
        assert rows[channel_id(sync_session, "ch-cyr")].commentator_id is not None
        # The orphan id exists nowhere, so it is not linked to another channel, and the run records it.
        assert all(row.source == "legacy" and row.imported_by == "legacy" for row in rows.values())
        assert {"ref": "orphan-channel-1", "reason": "channel_not_published"} in outcome.skipped

    def test_a_new_commentator_name_creates_one_row(self, sync_session: Session, loaded_snapshot) -> None:
        adapter = SatairBridgeAdapter(fetcher=None, project_id="p", api_key="k")  # type: ignore[arg-type]
        items = [adapter.normalize(i) for i in adapter.parse(_page("2026-11-02.json", day="2026-11-02"))]
        UpsertPipeline(sync_session, source="legacy").run(items)
        found = sync_session.execute(
            select(Commentator).where(Commentator.name == "معلق جديد تماماً")
        ).scalar_one_or_none()
        assert found is not None

    def test_a_match_with_a_ysscores_id_keeps_its_fields_and_only_its_legacy_links_change(
        self, sync_session: Session, loaded_snapshot
    ) -> None:
        # An ysscores fixture that the bridge lists with different names, time and competition.
        from tests.adapters.test_upsert import fixture

        UpsertPipeline(sync_session, source="ysscores").run([fixture(external_id="5802974")])
        before = sync_session.execute(
            select(Match)
            .join(MatchExternalId, MatchExternalId.match_id == Match.id)
            .where(MatchExternalId.source == "ysscores", MatchExternalId.external_id == "5802974")
        ).scalar_one()
        kept = (before.home_team_name, before.away_team_name, before.kickoff_at, before.competition_name)

        adapter = SatairBridgeAdapter(fetcher=None, project_id="p", api_key="k")  # type: ignore[arg-type]
        items = [adapter.normalize(i) for i in adapter.parse(_page())]
        UpsertPipeline(sync_session, source="legacy").run(items)

        sync_session.expire_all()
        after = sync_session.execute(select(Match).where(Match.id == before.id)).scalar_one()
        assert (after.home_team_name, after.away_team_name, after.kickoff_at, after.competition_name) == kept
        assert after.source == "ysscores"
        links = sync_session.execute(select(MatchChannel).where(MatchChannel.match_id == after.id)).scalars().all()
        assert links and all(link.source == "legacy" for link in links)


class TestTheKeyStaysOutOfTheLogs:
    def test_no_log_line_or_error_message_carries_the_api_key(self, capsys) -> None:
        """httpx logs every URL at INFO, and an oversize body used to put the query in the error (B2-R2-5)."""
        import logging

        import httpx

        from app.adapters.base import DateWindow
        from app.adapters.fetcher import HttpFetcher, ResponseTooLarge
        from app.workers import logs

        key = "SECRETKEY123"
        requests: list[httpx.Request] = []

        def handler(request: httpx.Request) -> httpx.Response:
            requests.append(request)
            if len(requests) == 1:
                return httpx.Response(200, json={"fields": {}})
            return httpx.Response(200, content=b"x" * (5 * 1024 * 1024 + 1))  # the fetcher's cap

        class Allowed:
            def take(self, host: str, now: float | None = None) -> bool:
                return True

        fetcher = HttpFetcher(
            limiter=Allowed(),
            user_agent="MadarSat/test",
            client=httpx.Client(transport=httpx.MockTransport(handler), follow_redirects=False),
        )
        bridge = SatairBridgeAdapter(fetcher=fetcher, project_id="p-1", api_key=key)

        root = logging.getLogger()
        before = (list(root.handlers), root.level)
        try:
            logs.setup_logging("INFO")
            assert bridge.fetch(DateWindow.next_days(date(2026, 10, 31), span=1))[0].status == 200
            with pytest.raises(ResponseTooLarge) as raised:
                bridge.fetch(DateWindow(days=(date(2026, 11, 1),)))
        finally:
            root.handlers[:] = before[0]
            root.setLevel(before[1])
            fetcher.close()

        assert key not in capsys.readouterr().out
        assert key not in str(raised.value)
        assert requests[0].headers["x-goog-api-key"] == key
        assert requests[0].url.query == b""  # nothing in the URL to log
