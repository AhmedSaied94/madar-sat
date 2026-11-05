"""Revision 0007: the live tables, aliases and the unresolved-names queue (T002, data-model)."""

from __future__ import annotations

from typing import Literal

import psycopg
import pytest
from alembic.config import Config
from pydantic import TypeAdapter
from sqlalchemy import text
from sqlalchemy.exc import IntegrityError

from alembic import command
from app.db.models import DATASET_NAMES
from app.domain.lockable import MATCH_LOCKABLE

TABLES = {
    "match_events",
    "match_lineups",
    "match_live_state",
    "match_source_readings",
    "live_source_state",
    "live_problems",
    "team_aliases",
    "competition_aliases",
    "channel_aliases",
    "unresolved_names",
}
COLUMNS = {
    *(
        f"match_events.{c}"
        for c in ("id", "match_id", "side", "type", "minute", "player_name", "source", "external_id", "created_at")
    ),
    *(f"match_lineups.{c}" for c in ("match_id", "side", "formation", "players", "source", "updated_at")),
    *(
        f"match_live_state.{c}"
        for c in (
            "match_id",
            "confirmed_home",
            "confirmed_away",
            "confirmed_home_pen",
            "confirmed_away_pen",
            "candidate",
            "disagreement_since",
            "has_page_slot",
            "last_reading_at",
            "updated_at",
        )
    ),
    *(
        f"match_source_readings.{c}"
        for c in (
            "match_id",
            "source",
            "status",
            "period",
            "minute",
            "home_score",
            "away_score",
            "home_pen",
            "away_pen",
            "read_at",
            "changed_at",
        )
    ),
    *(f"live_source_state.{c}" for c in ("source", "state", "consecutive_failures", "last_ok_at")),
    *(f"live_problems.{c}" for c in ("key", "opened_at", "closed_at", "raw_ref", "alerted_at", "recovered_alerted_at")),
    *(f"team_aliases.{c}" for c in ("source", "alias_norm", "competition_norm", "team_id", "created_by", "created_at")),
    *(f"competition_aliases.{c}" for c in ("source", "alias_norm", "competition_id", "created_by", "created_at")),
    *(f"channel_aliases.{c}" for c in ("source", "alias_norm", "channel_id", "created_by", "created_at")),
    *(
        f"unresolved_names.{c}"
        for c in (
            "id",
            "source",
            "kind",
            "name",
            "name_norm",
            "competition_norm",
            "context",
            "seen_count",
            "first_seen_at",
            "last_seen_at",
            "state",
            "target_id",
            "resolved_by",
            "resolved_at",
        )
    ),
    "matches.local_broadcaster_eg",
    "rights_holder_carriages.package",
}
INDEXES = {"match_live_state_last_reading_at_idx", "match_events_match_id_minute_idx", "unresolved_names_open_idx"}


def _alembic(url: str) -> Config:
    cfg = Config("alembic.ini")
    cfg.set_main_option("sqlalchemy.url", url.replace("postgresql://", "postgresql+psycopg://").replace("%", "%%"))
    return cfg


def _catalog(url: str) -> dict[str, set[str]]:
    with psycopg.connect(url) as conn:
        return {
            "tables": {
                r[0]
                for r in conn.execute("SELECT table_name FROM information_schema.tables WHERE table_schema = 'public'")
            },
            "columns": {
                r[0]
                for r in conn.execute(
                    "SELECT table_name || '.' || column_name FROM information_schema.columns "
                    "WHERE table_schema = 'public'"
                )
            },
            "indexes": {r[0] for r in conn.execute("SELECT indexname FROM pg_indexes WHERE schemaname = 'public'")},
        }


def test_upgrade_creates_everything_and_downgrade_removes_it(empty_database):
    cfg = _alembic(empty_database)
    command.upgrade(cfg, "head")

    found = _catalog(empty_database)
    assert TABLES <= found["tables"]
    assert COLUMNS <= found["columns"]
    assert INDEXES <= found["indexes"]
    with psycopg.connect(empty_database) as conn:
        kinds = dict(conn.execute("SELECT name, kind FROM sources").fetchall())
        versions = {r[0] for r in conn.execute("SELECT name FROM dataset_versions")}
    assert (kinds["filgoal"], kinds["yallakora"], kinds["live_poller"]) == ("internal", "scraper", "internal")
    assert versions == set(DATASET_NAMES)
    assert "unresolved_names" in versions

    command.downgrade(cfg, "0006")

    found = _catalog(empty_database)
    assert not TABLES & found["tables"]
    assert not {"matches.local_broadcaster_eg", "rights_holder_carriages.package"} & found["columns"]
    with psycopg.connect(empty_database) as conn:
        kinds = dict(conn.execute("SELECT name, kind FROM sources").fetchall())
        versions = {r[0] for r in conn.execute("SELECT name FROM dataset_versions")}
    assert "filgoal" not in kinds and "live_poller" not in kinds
    assert kinds["yallakora"] == "scraper"
    assert "unresolved_names" not in versions

    command.upgrade(cfg, "head")
    assert TABLES <= _catalog(empty_database)["tables"]


def test_the_previous_release_can_still_load_every_source_row(empty_database):
    """``SourceItem.kind`` at d42c7de: the API before 0007 must keep answering on the migrated schema."""
    previous = TypeAdapter(Literal["scraper", "api", "internal"])
    command.upgrade(_alembic(empty_database), "head")

    with psycopg.connect(empty_database) as conn:
        rows = conn.execute("SELECT name, kind FROM sources").fetchall()
        check = conn.execute(
            "SELECT pg_get_constraintdef(oid) FROM pg_constraint WHERE conname = 'ck_sources_kind'"
        ).fetchone()[0]

    assert {"filgoal", "yallakora", "live_poller"} <= {name for name, _ in rows}
    for _, kind in rows:
        previous.validate_python(kind)
    assert "fixtures" not in check
    assert "live_reader" not in check


def test_upgrade_and_downgrade_keep_existing_rows(empty_database):
    cfg = _alembic(empty_database)
    command.upgrade(cfg, "0006")
    with psycopg.connect(empty_database, autocommit=True) as conn:
        conn.execute(
            "INSERT INTO matches (source, match_date, competition_name, home_team_name, away_team_name, "
            "locked_fields, time_tbd) VALUES ('manual', '2026-11-04', 'كأس', 'أ', 'ب', '{status}', true)"
        )
        conn.execute("INSERT INTO rights_holders (name) VALUES ('حقوق')")
        conn.execute(
            "INSERT INTO rights_holder_carriages (rights_holder_id, position, access) "
            "SELECT id, 0, 'free' FROM rights_holders"
        )

    command.upgrade(cfg, "head")
    with psycopg.connect(empty_database) as conn:
        assert conn.execute("SELECT local_broadcaster_eg, locked_fields FROM matches").fetchall() == [
            (None, ["status"])
        ]
        assert conn.execute("SELECT package FROM rights_holder_carriages").fetchall() == [(None,)]

    command.downgrade(cfg, "0006")
    with psycopg.connect(empty_database) as conn:
        assert conn.execute("SELECT count(*) FROM matches").fetchone() == (1,)
        assert conn.execute("SELECT count(*) FROM rights_holder_carriages").fetchone() == (1,)


@pytest.fixture
def match_id(sync_session):
    return sync_session.execute(
        text(
            "INSERT INTO matches (source, match_date, competition_name, home_team_name, away_team_name, time_tbd) "
            "VALUES ('manual', '2026-11-04', 'كأس', 'أ', 'ب', true) RETURNING id"
        )
    ).scalar_one()


def _rejected(session, sql: str, **params) -> None:
    with pytest.raises(IntegrityError), session.begin_nested():
        session.execute(text(sql), params)


EVENT = (
    "INSERT INTO match_events (match_id, side, type, minute, source, external_id) "
    "VALUES (:m, :side, :type, :minute, 'filgoal', :ext)"
)


def test_match_events_are_unique_per_source_and_reject_unknown_types(sync_session, match_id):
    sync_session.execute(text(EVENT), {"m": match_id, "side": "home", "type": "goal", "minute": "23", "ext": "a"})

    _rejected(sync_session, EVENT, m=match_id, side="home", type="goal", minute="24", ext="a")
    _rejected(sync_session, EVENT, m=match_id, side="home", type="corner", minute="24", ext="b")
    _rejected(sync_session, EVENT, m=match_id, side="middle", type="goal", minute="24", ext="b")
    _rejected(sync_session, EVENT, m=match_id, side="home", type="goal", minute="soon", ext="b")
    for allowed in ("own_goal", "penalty", "missed_penalty", "red_card"):
        sync_session.execute(
            text(EVENT), {"m": match_id, "side": "away", "type": allowed, "minute": "45+2", "ext": allowed}
        )


def test_team_aliases_are_keyed_by_source_name_and_competition(sync_session):
    ids = [
        sync_session.execute(text("INSERT INTO teams (name) VALUES (:n) RETURNING id"), {"n": n}).scalar_one()
        for n in ("الأهلي المصري", "الأهلي السعودي")
    ]
    insert = (
        "INSERT INTO team_aliases (source, alias_norm, competition_norm, team_id) "
        "VALUES ('filgoal', 'الاهلي', :competition, :team)"
    )
    sync_session.execute(text(insert), {"competition": "الدوري المصري", "team": ids[0]})
    sync_session.execute(text(insert), {"competition": "الدوري السعودي", "team": ids[1]})
    sync_session.execute(text(insert), {"competition": "", "team": ids[0]})

    _rejected(sync_session, insert, competition="الدوري المصري", team=ids[1])


UNRESOLVED = (
    "INSERT INTO unresolved_names (source, kind, name, name_norm, competition_norm, state, target_id) "
    "VALUES ('yallakora', :kind, 'Al Ahli', 'al ahli', :competition, :state, :target)"
)


def test_unresolved_names_rules(sync_session):
    sync_session.execute(text(UNRESOLVED), {"kind": "team", "competition": "x", "state": "open", "target": None})

    _rejected(sync_session, UNRESOLVED, kind="team", competition="x", state="open", target=None)  # the unique key
    _rejected(sync_session, UNRESOLVED, kind="player", competition="y", state="open", target=None)
    _rejected(sync_session, UNRESOLVED, kind="team", competition="y", state="closed", target=None)
    _rejected(sync_session, UNRESOLVED, kind="team", competition="y", state="mapped", target=None)
    _rejected(sync_session, UNRESOLVED, kind="team", competition="y", state="created", target=None)
    sync_session.execute(text(UNRESOLVED), {"kind": "team", "competition": "y", "state": "mapped", "target": 1})
    sync_session.execute(text(UNRESOLVED), {"kind": "team", "competition": "z", "state": "ignored", "target": None})


def test_local_broadcaster_can_be_locked(sync_session, match_id):
    assert "local_broadcaster_eg" in MATCH_LOCKABLE
    sync_session.execute(
        text("UPDATE matches SET locked_fields = '{local_broadcaster_eg}' WHERE id = :m"), {"m": match_id}
    )
