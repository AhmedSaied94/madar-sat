"""Entity versions: the strong ETag every admin write is checked against (T021, R5)."""

from __future__ import annotations

import hashlib
import json
import re
from datetime import UTC, date, datetime

import pytest
from sqlalchemy import inspect

from app.db.models import Channel, Match, MatchChannel, MatchCustomBroadcast, Team
from app.services.admin import versions

ETAG_FORMAT = re.compile(r'^"[0-9a-f]{32}"$')
KICKOFF = datetime(2026, 10, 28, 19, 0, tzinfo=UTC)
EXCLUDED = {"created_at", "updated_at", "minute", "period", "status_updated_at"}


def _match(**overrides) -> Match:
    values = {
        "id": 7,
        "sport": "football",
        "source": "manual",
        "match_date": date(2026, 10, 28),
        "kickoff_at": KICKOFF,
        "competition_id": 3,
        "competition_name": "الدوري",
        "home_team_id": 1,
        "home_team_name": "الأهلي",
        "away_team_id": 2,
        "away_team_name": "الزمالك",
        "stadium": "ستاد القاهرة",
        "status": "scheduled",
        "status_source": "clock",
        "time_tbd": False,
        "is_live": False,
        "locked_fields": [],
        "created_at": KICKOFF,
        "updated_at": KICKOFF,
    }
    return Match(**{**values, **overrides})


def _link(channel_id: int = 10, **overrides) -> MatchChannel:
    values = {
        "match_id": 7,
        "channel_id": channel_id,
        "source": "manual",
        "imported_by": None,
        "is_hidden": False,
        "commentator_id": None,
        "commentator2_id": None,
        "created_at": KICKOFF,
    }
    return MatchChannel(**{**values, **overrides})


def _slot(slot: int = 1, **overrides) -> MatchCustomBroadcast:
    values = {"match_id": 7, "slot": slot, "label": "beIN", "logo_asset_id": None, "commentator_id": None}
    return MatchCustomBroadcast(**{**values, **overrides})


def _version(match: Match, links=(), slots=()) -> str:
    return versions.etag_of(versions.match_state(match, links, slots))


def test_the_etag_is_32_hex_characters_of_a_sha256_over_canonical_json_in_quotes():
    state = {"b": 2, "a": [3, 1]}

    etag = versions.etag_of(state)

    expected = hashlib.sha256(json.dumps(state, sort_keys=True, separators=(",", ":")).encode()).hexdigest()[:32]
    assert ETAG_FORMAT.match(etag)
    assert etag == f'"{expected}"'


def test_key_order_does_not_change_the_etag():
    assert versions.etag_of({"a": 1, "b": 2}) == versions.etag_of({"b": 2, "a": 1})


class TestMatchColumns:
    def test_the_state_holds_every_column_except_the_two_timestamps(self):
        columns = {column.key for column in inspect(Match).column_attrs}

        state = versions.match_state(_match(), [], [])

        assert set(state["match"]) == columns - EXCLUDED

    def test_the_timestamps_do_not_change_the_version(self):
        before = _version(_match())

        after = _version(
            _match(created_at=datetime(2020, 1, 1, tzinfo=UTC), updated_at=datetime(2030, 1, 1, tzinfo=UTC))
        )

        assert before == after

    @pytest.mark.parametrize(
        ("column", "value"),
        [
            ("kickoff_at", datetime(2026, 10, 28, 20, 0, tzinfo=UTC)),
            ("time_tbd", True),
            ("stadium", "برج العرب"),
            ("competition_id", 4),
            ("home_team_name", "بيراميدز"),
            ("status", "live"),
            ("status_source", "manual"),
            ("home_score", 2),
            ("locked_fields", ["stadium"]),
            ("match_date", date(2026, 10, 29)),
            ("source", "ysscores"),
        ],
    )
    def test_any_other_column_changes_the_version(self, column, value):
        assert _version(_match(**{column: value})) != _version(_match())

    def test_the_same_stored_state_gives_the_same_version(self):
        assert _version(_match()) == _version(_match())

    def test_locked_fields_are_compared_as_a_set(self):
        assert _version(_match(locked_fields=["stadium", "status"])) == _version(
            _match(locked_fields=["status", "stadium"])
        )


class TestMatchLinks:
    def test_adding_a_link_changes_the_version(self):
        assert _version(_match(), [_link()]) != _version(_match())

    @pytest.mark.parametrize(
        ("column", "value"),
        [
            ("channel_id", 11),
            ("source", "ysscores"),
            ("imported_by", "ysscores"),
            ("is_hidden", True),
            ("commentator_id", 5),
            ("commentator2_id", 6),
        ],
    )
    def test_each_hashed_link_column_changes_the_version(self, column, value):
        assert _version(_match(), [_link(**{column: value})]) != _version(_match(), [_link()])

    def test_a_links_created_at_does_not_change_the_version(self):
        other = _link(created_at=datetime(2030, 1, 1, tzinfo=UTC))

        assert _version(_match(), [other]) == _version(_match(), [_link()])

    def test_row_order_does_not_change_the_version(self):
        links = [_link(10), _link(11, is_hidden=True), _link(12)]

        assert _version(_match(), links) == _version(_match(), list(reversed(links)))


class TestMatchSlots:
    def test_adding_a_slot_changes_the_version(self):
        assert _version(_match(), slots=[_slot()]) != _version(_match())

    @pytest.mark.parametrize(
        ("column", "value"),
        [("slot", 2), ("label", "الكأس"), ("logo_asset_id", 9), ("commentator_id", 4)],
    )
    def test_each_slot_column_changes_the_version(self, column, value):
        assert _version(_match(), slots=[_slot(**{column: value})]) != _version(_match(), slots=[_slot()])

    def test_slot_order_does_not_change_the_version(self):
        slots = [_slot(1), _slot(2, label="الكأس")]

        assert _version(_match(), slots=slots) == _version(_match(), slots=list(reversed(slots)))


def test_renaming_a_team_does_not_change_the_version_of_its_matches():
    home = Team(id=1, name="الأهلي", sport="football")
    before = _version(_match(home_team_id=home.id))

    home.name = "النادي الأهلي"

    assert _version(_match(home_team_id=home.id)) == before


class TestTeams:
    def _team(self, **overrides) -> Team:
        values = {"id": 1, "sport": "football", "name": "الأهلي", "country": "EG", "created_at": KICKOFF}
        return Team(**{**values, **overrides})

    def test_the_version_includes_the_competition_ids(self):
        team = self._team()

        one = versions.etag_of(versions.team_state(team, [3]))
        two = versions.etag_of(versions.team_state(team, [3, 4]))

        assert one != two

    def test_competition_ids_are_compared_as_a_set(self):
        team = self._team()

        first = versions.etag_of(versions.team_state(team, [3, 4]))
        assert first == versions.etag_of(versions.team_state(team, [4, 3]))

    def test_a_team_column_changes_the_version(self):
        assert versions.etag_of(versions.team_state(self._team(country="SA"), [])) != versions.etag_of(
            versions.team_state(self._team(), [])
        )

    def test_the_generated_name_norm_is_not_hashed(self):
        state = versions.team_state(self._team(), [])

        assert "name_norm" not in state["team"]


class TestOtherEntities:
    def test_a_channels_own_columns_are_hashed(self):
        base = Channel(id=1, kind="satellite", name="beIN 1", show_in_match=False, locked_fields=[])
        changed = Channel(id=1, kind="satellite", name="beIN 1", show_in_match=True, locked_fields=[])

        assert versions.etag_of(versions.row_state(base)) != versions.etag_of(versions.row_state(changed))

    def test_a_deleted_channel_has_another_version(self):
        live = Channel(id=1, kind="satellite", name="beIN 1", locked_fields=[])
        gone = Channel(id=1, kind="satellite", name="beIN 1", locked_fields=[], deleted_at=KICKOFF)

        assert versions.etag_of(versions.row_state(live)) != versions.etag_of(versions.row_state(gone))
