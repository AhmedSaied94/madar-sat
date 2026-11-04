"""Snapshot load: reconciliation, idempotency and README rules 1–17 (T014).

Every test loads the T013 fixture inside ``sync_session`` (a per-test transaction that
is rolled back), so tests are order-independent. Rule 16 (media) is asserted in
``test_rehost_media.py``.
"""

from __future__ import annotations

import json
from pathlib import Path
from typing import Any

import pytest
from sqlalchemy import text
from sqlalchemy.orm import Session

from app.domain.arabic import ar_normalize
from app.etl.checks import find_card_sharing_label, scan_card_sharing_labels, strip_card_sharing_labels
from app.etl.report import Report
from app.etl.snapshot import load
from app.etl.types import read_snapshot

SNAPSHOT_DIR = str(Path(__file__).resolve().parents[1] / "fixtures" / "snapshot")

# Every table the loader writes (row counts must not change on a re-run, FR-004).
LOADER_TABLES = (
    "satellites",
    "competitions",
    "teams",
    "team_external_ids",
    "team_competitions",
    "livesoccertv_teams",
    "commentators",
    "broadcast_presets",
    "hidden_channel_names",
    "channels",
    "rights_holders",
    "rights_holder_competitions",
    "rights_holder_carriages",
    "rights_holder_carriage_satellites",
    "rights_holder_frequencies",
    "matches",
    "match_external_ids",
    "match_channels",
    "match_custom_broadcasts",
    "feeds",
)


def _load(session: Session) -> Report:
    report = Report("load-snapshot", SNAPSHOT_DIR)
    load(session, read_snapshot(SNAPSHOT_DIR), report)
    session.commit()  # releases the test's savepoint; the fixture rolls everything back
    return report


@pytest.fixture
def db(sync_session: Session) -> tuple[Session, Report]:
    return sync_session, _load(sync_session)


def _one(s: Session, sql: str, **params: Any) -> Any:
    return s.execute(text(sql), params).one()


def _scalar(s: Session, sql: str, **params: Any) -> Any:
    return s.execute(text(sql), params).scalar_one()


def _row_counts(s: Session) -> dict[str, int]:
    # Table names come from the constant tuple above, never from input.
    return {t: s.execute(text(f"SELECT count(*) FROM {t}")).scalar_one() for t in LOADER_TABLES}  # noqa: S608


def _warnings(report: Report, code: str) -> list[dict[str, str]]:
    return [w for w in report.warnings if w["code"] == code]


def _fixture_rows(sub: str, name: str) -> list[dict[str, Any]]:
    rows: list[dict[str, Any]] = json.loads((Path(SNAPSHOT_DIR) / sub / f"{name}.json").read_text(encoding="utf-8"))
    return rows


# --- Report, idempotency, details --------------------------------------------


def test_report_reconciles(db):
    _, report = db
    assert report.reconciled, report.as_dict(report.started_at, "-")
    for name, stats in report.collections.items():
        assert stats.source_rows == stats.loaded + stats.merged + stats.skipped, name
        assert sum(stats.skip_reasons.values()) == stats.skipped, name
    assert report.checks == {"card_sharing_labels_found": 0, "frequencies_out_of_domain": 0}

    counts = {k: (v.source_rows, v.loaded, v.merged, v.skipped) for k, v in report.collections.items()}
    assert counts["channels"] == (15, 12, 2, 1)
    assert counts["matches"] == (8, 6, 2, 0)
    assert counts["match_channels"] == (16, 12, 3, 1)
    assert counts["match_channel_refs"] == (15, 13, 0, 2)
    assert counts["channel_order"] == (14, 13, 0, 1)
    assert counts["rights_order"] == (3, 2, 0, 1)
    assert counts["feeds"] == (3, 3, 0, 0)
    assert counts["commentators_from_matches"] == (4, 4, 0, 0)
    assert report.collections["match_channels"].skip_reasons == {"channel_not_published": 1}
    assert report.collections["rights_order"].skip_reasons == {"rights_order_unknown_id": 1}


def test_load_is_idempotent(db):
    s, report1 = db
    counts1 = _row_counts(s)
    report2 = _load(s)
    counts2 = _row_counts(s)

    def _shape(r: Report) -> dict[str, Any]:
        return {
            "collections": {k: v.as_dict() for k, v in r.collections.items()},
            "kinds": r.kinds,
            "warnings": r.warnings,
            "details": r.details,
            "checks": r.checks,
        }

    assert _shape(report1) == _shape(report2)
    assert counts1 == counts2
    assert all(counts1[t] > 0 for t in LOADER_TABLES), counts1


def test_dataset_versions_bumped_once_per_run(sync_session):
    before = dict(sync_session.execute(text("SELECT name, version FROM dataset_versions")).all())
    _load(sync_session)
    after = dict(sync_session.execute(text("SELECT name, version FROM dataset_versions")).all())
    assert len(after) == 11  # 0004 added `broadcast_presets` and `sources`, 0007 `unresolved_names`
    assert {k: after[k] - before[k] for k in after} == dict.fromkeys(after, 1)


def test_report_files_list_every_merge_and_skip(db, tmp_path):
    _, report = db
    json_path, details_path = report.write(str(tmp_path))
    data = json.loads(json_path.read_text(encoding="utf-8"))
    assert data["command"] == "load-snapshot"
    assert data["reconciled"] is True
    assert data["details_file"] == details_path.name
    assert data["kinds"]["channels"] == {"satellite": 8, "terrestrial": 1, "platform": 6}

    lines = [json.loads(line) for line in details_path.read_text(encoding="utf-8").splitlines()]
    assert all(set(line) <= {"collection", "legacy_id", "action", "reason", "into"} for line in lines)

    # Each merged or skipped count traces back to exactly that many lines.
    for name, stats in data["collections"].items():
        merges = [d for d in lines if d["collection"] == name and d["action"] == "merge"]
        skips = [d for d in lines if d["collection"] == name and d["action"] == "skip"]
        assert len(merges) == stats["merged"], name
        assert len(skips) == stats["skipped"], name
        for reason, n in stats["skip_reasons"].items():
            assert sum(1 for d in skips if d["reason"] == reason) == n, (name, reason)

    def has(**kv: Any) -> bool:
        return any(all(d.get(k) == v for k, v in kv.items()) for d in lines)

    assert has(collection="channels", legacy_id="ch-carriage-dup-b", action="merge", into="ch-carriage-dup-a")
    assert has(collection="channels", legacy_id="ch-platform-dup-b", action="merge", into="ch-platform-dup-a")
    assert has(collection="matches", legacy_id="m-1b", action="merge", reason="duplicate_listing", into="m-1")
    assert has(collection="matches", legacy_id="m-dup2-b", action="merge", reason="duplicate_listing", into="m-dup2-a")
    assert has(collection="match_channels", legacy_id="m-1/orphan-channel-1", action="skip")
    assert has(collection="match_channel_refs", legacy_id="m-1/orphan-imported-1", reason="channel_not_published")
    assert has(collection="match_channel_refs", legacy_id="m-1/orphan-commentator-1", reason="channel_not_published")
    assert has(collection="channel_order", legacy_id="orphan-channel-order-1", reason="channel_not_published")
    assert has(collection="rights_order", legacy_id="orphan-right-1", reason="rights_order_unknown_id")
    assert has(collection="match_channels", legacy_id="m-1b/ch-cyr", reason="duplicate_listing", into="m-1/ch-cyr")
    assert has(collection="match_channels", legacy_id="m-unmarked/ch-carriage-dup-b", reason="duplicate_carriage")
    assert has(
        collection="channels", legacy_id="ch-platform-label-only", action="skip", reason="name_is_card_sharing_label"
    )


# --- FR-005 / SC-002: card-sharing labels --------------------------------------


@pytest.mark.parametrize(
    ("value", "label"),
    [
        ("Mega Share", "Mega Share"),
        ("mega share", "mega share"),
        ("MegaShare HD", "MegaShare"),
        ("VIP", "VIP"),
        ("beIN VIP", "VIP"),
        ("Apollo", "Apollo"),
        ("BISS", "BISS"),
        ("Biss : 12 34", "Biss"),
        ("ليست مكسورة", "ليست مكسورة"),
        ("قناة ليست مكسوره", "ليست مكسوره"),
    ],
)
def test_label_finder_flags_card_sharing_labels(value, label):
    assert find_card_sharing_label(value) == label


@pytest.mark.parametrize("value", ["", "Guinea-Bissau", "Apollon", "VIPER", "beIN SPORTS", "11843 H 27500"])
def test_label_finder_ignores_other_words(value):
    assert find_card_sharing_label(value) is None


@pytest.mark.parametrize(
    ("value", "stripped"),
    [
        ("CCTV Sports VIP", "CCTV Sports"),
        ("VIP CCTV", "CCTV"),
        ("beIN Sports - VIP", "beIN Sports"),
        ("Sport Mega Share HD", "Sport HD"),
        ("قناة ليست مكسورة", "قناة"),
        ("VIP", None),
        (" - VIP | ", None),
        ("Guinea-Bissau", "Guinea-Bissau"),
        ("VIPER", "VIPER"),
        ("beIN SPORTS 1", "beIN SPORTS 1"),
        ("", ""),
        (None, None),
    ],
)
def test_label_stripper_removes_only_the_label_words(value, stripped):
    assert strip_card_sharing_labels(value) == stripped


def test_channel_names_lose_their_card_sharing_labels(db):
    s, report = db
    assert _one(s, "SELECT name, display_name FROM channels WHERE legacy_id = 'ch-platform-labelled'") == (
        "Fixture Sports",
        "FS",
    )
    assert {(w["ref"], w["value"]) for w in _warnings(report, "card_sharing_label_stripped")} == {
        ("ch-platform-labelled", "name: Fixture Sports VIP → Fixture Sports"),
        ("ch-platform-labelled", "displayName: FS - VIP → FS"),
    }
    # A name that is nothing but a label leaves no channel to show.
    assert _scalar(s, "SELECT count(*) FROM channels WHERE legacy_id = 'ch-platform-label-only'") == 0
    assert report.collections["channels"].skip_reasons == {"name_is_card_sharing_label": 1}
    assert report.reconciled


def test_no_stored_text_contains_a_card_sharing_label(db):
    s, report = db
    assert report.checks["card_sharing_labels_found"] == 0
    assert scan_card_sharing_labels(s) == []
    # The fixture does carry every label in `encryption`, so the zero is meaningful.
    encryption = {c["encryption"] for c in _fixture_rows("hosting", "channels")}
    assert {"Mega Share", "Apollo", "VIP", "ليست مكسورة", "BISS"} <= encryption


def test_label_scan_covers_every_loader_table(db):
    s, _ = db
    s.execute(text("UPDATE channels SET provider = 'Mega Share' WHERE legacy_id = 'ch-cyr'"))
    s.execute(text("UPDATE teams SET stadium = 'VIP Lounge' WHERE legacy_id = 'team-zamalek'"))
    s.execute(text("UPDATE match_custom_broadcasts SET label = 'Apollo HD' WHERE slot = 2"))
    s.execute(text("UPDATE feeds SET lines = ARRAY['x', 'ليست مكسورة'] WHERE legacy_id = 'feed-3'"))
    s.execute(text("UPDATE livesoccertv_teams SET en_name = 'Mega Share FC' WHERE slug = 'fixture-national'"))
    hits = {(h.table, h.column, h.label) for h in scan_card_sharing_labels(s)}
    assert hits == {
        ("channels", "provider", "Mega Share"),
        ("teams", "stadium", "VIP"),
        ("match_custom_broadcasts", "label", "Apollo"),
        ("feeds", "lines", "ليست مكسورة"),
        ("livesoccertv_teams", "en_name", "Mega Share"),
    }


# --- Rules 1–3: source files, lagging hosting, orphans -------------------------


def test_rule_1_loads_the_given_snapshot_dir(db):
    _, report = db
    assert report.snapshot_dir == SNAPSHOT_DIR
    for name in ("satellites", "channels", "competitions", "teams", "rights"):
        collection = "rights_holders" if name == "rights" else name
        assert report.collections[collection].source_rows == len(_fixture_rows("hosting", name)), name


def test_rules_2_3_orphans_are_skipped_and_logged(db):
    s, report = db
    # matchDays.channelIds orphan: no link row.
    assert (
        _scalar(
            s, "SELECT count(*) FROM match_channels mc JOIN matches m ON m.id = mc.match_id WHERE m.legacy_id = 'm-1'"
        )
        == 5
    )
    # importedChannelIds / channelCommentators orphans: no commentator created from them.
    assert _scalar(s, "SELECT count(*) FROM commentators WHERE name = 'معلق قناة محذوفة'") == 0
    # channelOrder orphan: sort_order follows the full list, so later rows keep their index.
    assert _scalar(s, "SELECT sort_order FROM channels WHERE legacy_id = 'ch-platform-dup-a'") == 8
    # rightsOrder orphan.
    assert _scalar(s, "SELECT sort_order FROM rights_holders WHERE legacy_id = 'right-2'") == 2
    assert report.collections["channel_order"].skip_reasons == {"channel_not_published": 1}


# --- Rule 4: links that exist only by name -------------------------------------


def test_rule_4_ambiguous_team_broken_by_competition(db):
    s, report = db
    home = _scalar(
        s, "SELECT t.legacy_id FROM matches m JOIN teams t ON t.id = m.home_team_id WHERE m.legacy_id = 'm-1'"
    )
    assert home == "team-ahly-eg"
    # m-amb's competition is not in the snapshot, so the tie stays unresolved.
    home_id, home_name, away_id, away_name = _one(
        s, "SELECT home_team_id, home_team_name, away_team_id, away_team_name FROM matches WHERE legacy_id = 'm-amb'"
    )
    assert (home_id, home_name) == (None, "الأهلي")
    assert (away_id, away_name) == (None, "فريق غير موجود")
    assert {"ref": "m-amb team1", "value": "الأهلي"} in [
        {"ref": w["ref"], "value": w["value"]} for w in _warnings(report, "team_name_ambiguous")
    ]
    assert any(w["ref"] == "m-amb team2" for w in _warnings(report, "team_name_unresolved"))


def test_rule_4_commentators_found_only_on_matches(db):
    s, _ = db
    names = set(s.execute(text("SELECT name FROM commentators")).scalars())
    assert names == {
        "معلق تجريبي",
        "معلق على القناة فقط",
        "معلق ثان على المباراة",
        "معلق ثان فقط",
        "معلق القائمة المكررة",
    }
    link_commentator = _scalar(
        s,
        "SELECT c.name FROM match_channels mc JOIN matches m ON m.id = mc.match_id "
        "JOIN channels ch ON ch.id = mc.channel_id JOIN commentators c ON c.id = mc.commentator_id "
        "WHERE m.legacy_id = 'm-1' AND ch.legacy_id = 'ch-cyr'",
    )
    assert link_commentator == "معلق على القناة فقط"


def test_rule_4_unresolved_competition_names_are_logged(db):
    _, report = db
    assert {w["value"] for w in _warnings(report, "rights_competition_unresolved")} == {"بطولة غير موجودة"}


# --- Rule 5: frequencies --------------------------------------------------------


def test_rule_5_cyrillic_frequency_parses(db):
    s, _ = db
    assert _one(s, "SELECT frequency_mhz, polarization, symbol_rate FROM channels WHERE legacy_id = 'ch-cyr'") == (
        12604,
        "H",
        30000,
    )


def test_rule_5_unparseable_frequency_becomes_note_and_warns(db):
    s, report = db
    assert _one(s, "SELECT frequency_mhz, frequency_note FROM channels WHERE legacy_id = 'ch-nosr'") == (
        None,
        "12054 H",
    )
    assert _one(s, "SELECT frequency_mhz, frequency_note FROM channels WHERE legacy_id = 'ch-terr'") == (
        None,
        "UHF 32",
    )
    channel_warnings = {(w["ref"], w["value"]) for w in _warnings(report, "frequency_unparseable")}
    assert {("ch-nosr", "12054 H"), ("ch-terr", "UHF 32"), ("right-2", "12054 H")} <= channel_warnings


def test_rule_5_platform_junk_frequency_is_dropped(db):
    # T008 case at the loader level: «كازاخستان» on a platform row is not kept as a note.
    s, report = db
    assert _one(s, "SELECT frequency_mhz, frequency_note FROM channels WHERE legacy_id = 'ch-platform-kz'") == (
        None,
        None,
    )
    assert not any(w["value"] == "كازاخستان" for w in _warnings(report, "frequency_unparseable"))


def test_rule_5_satellite_frequency_without_polarization_warns(db):
    # T008 case at the loader level: NULL tuning plus a warning for an admin.
    s, report = db
    assert _one(
        s,
        "SELECT best_frequency_mhz, best_polarization, best_symbol_rate FROM satellites WHERE legacy_id = 'sat-astra'",
    ) == (None, None, None)
    assert {
        "code": "satellite_frequency_missing_polarization",
        "ref": "Astra 19.2E bestFreq",
        "value": "12166 29700",
    } in (report.warnings)
    assert _one(
        s,
        "SELECT best_frequency_mhz, best_polarization, best_symbol_rate, worst_frequency_mhz "
        "FROM satellites WHERE legacy_id = 'sat-nilesat'",
    ) == (12054, "V", 27500, 11373)


def test_rule_5_rights_frequencies_deduplicated_with_one_primary(db):
    s, _ = db
    rows = s.execute(
        text(
            "SELECT rh.legacy_id, c.position, f.frequency_mhz, f.polarization, f.symbol_rate, f.is_primary "
            "FROM rights_holder_frequencies f JOIN rights_holder_carriages c ON c.id = f.carriage_id "
            "JOIN rights_holders rh ON rh.id = c.rights_holder_id ORDER BY 1, 2, 3, 4"
        )
    ).all()
    assert [tuple(r) for r in rows] == [
        ("right-1", 0, 11278, "V", 27500, True),
        ("right-1", 0, 11488, "H", 27500, False),
        ("right-2", 0, 11938, "H", 27500, True),  # Cyrillic Н, primary
        ("right-2", 0, 11938, "V", 27500, False),
        ("right-2", 1, 11555, "V", 30000, False),  # no primary on this carriage
    ]


# --- Rule 6: placeholders ------------------------------------------------------


def test_rule_6_placeholders_become_null(db):
    s, _ = db
    # "⚽" is m-1's logo2 (away); rehosting must leave it NULL too (test_rehost_media).
    assert _scalar(s, "SELECT away_logo_asset_id FROM matches WHERE legacy_id = 'm-1'") is None
    # «غير مدرج» commentator.
    assert _scalar(s, "SELECT commentator_id FROM matches WHERE legacy_id = 'm-tbd'") is None
    # "" strings.
    assert _one(s, "SELECT competition_stage, stadium FROM matches WHERE legacy_id = 'm-amb'") == (None, None)
    assert _one(s, "SELECT country, display_name FROM channels WHERE legacy_id = 'ch-cyr'") == (None, "Test HD")
    assert _scalar(s, "SELECT reception_url FROM satellites WHERE legacy_id = 'sat-badr'") is None


# --- Rule 7: kickoff -----------------------------------------------------------


@pytest.mark.parametrize(
    ("legacy_id", "cairo_wall_clock"),
    [
        ("m-1", "2026-10-28 22:00"),  # "10:00 م" (PM)
        ("m-amb", "2026-10-28 02:30"),  # "02:30 ص" (AM)
        ("m-unmarked", "2026-10-28 14:30"),  # "02:30", no marker → PM
        ("m-today", "2026-10-29 20:00"),  # "08:00 م"
    ],
)
def test_rule_7_kickoff_is_cairo_wall_clock_in_utc(db, legacy_id, cairo_wall_clock):
    s, _ = db
    same = _scalar(
        s,
        "SELECT kickoff_at = (CAST(:wall AS timestamp) AT TIME ZONE 'Africa/Cairo') FROM matches WHERE legacy_id = :id",
        wall=cairo_wall_clock,
        id=legacy_id,
    )
    assert same is True
    assert _scalar(s, "SELECT time_tbd FROM matches WHERE legacy_id = :id", id=legacy_id) is False


def test_rule_7_unknown_time_is_tbd(db):
    s, _ = db
    assert _one(s, "SELECT kickoff_at, time_tbd FROM matches WHERE legacy_id = 'm-tbd'") == (None, True)


def test_is_live_is_ignored_and_rows_are_clock_scheduled(db):
    s, _ = db
    assert _one(s, "SELECT is_live, status, status_source FROM matches WHERE legacy_id = 'm-tbd'") == (
        False,
        "scheduled",
        "clock",
    )
    assert _scalar(s, "SELECT count(*) FROM matches WHERE status <> 'scheduled' OR status_source <> 'clock'") == 0


# --- Rule 8: matches and source ids ----------------------------------------------


def test_rule_8_source_is_legacy(db):
    s, _ = db
    assert set(s.execute(text("SELECT DISTINCT source FROM matches")).scalars()) == {"legacy"}


def test_rule_8_external_ids(db):
    s, _ = db
    rows = {
        (r.source, r.external_id): (r.legacy_id, r.url)
        for r in s.execute(
            text(
                "SELECT e.source, e.external_id, m.legacy_id, e.url FROM match_external_ids e "
                "JOIN matches m ON m.id = e.match_id"
            )
        )
    }
    assert rows[("ysscores", "9000001")] == ("m-1", None)
    assert rows[("livesoccertv", "/match/fixture/m-1-listing/")] == (
        "m-1",
        "https://www.livesoccertv.com/match/fixture/m-1-listing/",
    )
    # The merged listing's LiveSoccerTV id moves onto the surviving row.
    assert rows[("livesoccertv", "/match/fixture/m-1b-listing/")][0] == "m-1"
    assert rows[("sporteventz", "se-fixture-1")] == ("m-amb", None)
    assert rows[("ysscores", "9000006")] == ("m-dup2-a", None)


def test_rule_8_duplicate_ys_match_id_keeps_one_row_per_fixture(db):
    s, _ = db
    ids = set(s.execute(text("SELECT legacy_id FROM matches")).scalars())
    assert ids == {"m-1", "m-tbd", "m-amb", "m-unmarked", "m-today", "m-dup2-a"}
    # m-1b is listed a day earlier but has no kickoff on its date; m-1 does, so it wins.
    assert str(_scalar(s, "SELECT match_date FROM matches WHERE legacy_id = 'm-1'")) == "2026-10-28"
    # Both m-dup2 listings match their own date: the earlier one wins.
    assert str(_scalar(s, "SELECT match_date FROM matches WHERE legacy_id = 'm-dup2-a'")) == "2026-10-29"


def test_rule_8_merged_listing_moves_links_with_flags_and_commentators(db):
    s, _ = db
    links = {
        r.channel: (r.is_hidden, r.source, r.commentator)
        for r in s.execute(
            text(
                "SELECT ch.legacy_id AS channel, mc.is_hidden, mc.source, c.name AS commentator "
                "FROM match_channels mc JOIN matches m ON m.id = mc.match_id "
                "JOIN channels ch ON ch.id = mc.channel_id LEFT JOIN commentators c ON c.id = mc.commentator_id "
                "WHERE m.legacy_id = 'm-1'"
            )
        )
    }
    assert links["ch-badr-enc"] == (False, "legacy", "معلق القائمة المكررة")  # moved from m-1b
    assert links["ch-terr"] == (True, "legacy", None)  # moved, hidden flag kept
    # ch-cyr is on both listings: hidden only on m-1b, so it stays visible; one copy is
    # legacy, so the importer may not remove it.
    assert links["ch-cyr"] == (False, "legacy", "معلق على القناة فقط")
    assert links["ch-hidden"][0] is True
    m_dup2 = _scalar(
        s, "SELECT count(*) FROM match_channels mc JOIN matches m ON m.id = mc.match_id WHERE m.legacy_id = 'm-dup2-a'"
    )
    assert m_dup2 == 1


# --- Rule 9: channels -----------------------------------------------------------


def test_rule_9_kind_access_beam(db):
    s, report = db
    rows = {
        r.legacy_id: (r.kind, r.access, r.beam)
        for r in s.execute(text("SELECT legacy_id, kind, access, beam FROM channels"))
    }
    assert rows["ch-cyr"] == ("satellite", "free", "wide")
    assert rows["ch-nosr"] == ("satellite", "encrypted", "narrow")
    assert rows["ch-terr"] == ("terrestrial", "free", "wide")
    assert rows["ch-platform-kz"] == ("platform", None, None)  # not free → unknown; beam dropped
    assert rows["ch-platform-mega"] == ("platform", "free", None)
    assert rows["ch-badr-enc"] == ("satellite", "encrypted", None)  # bundle ""
    assert rows["ch-bundle-mega"] == ("satellite", "encrypted", None)  # bundle "Mega Share"
    assert report.kinds["channels"] == {"satellite": 8, "terrestrial": 1, "platform": 6}
    assert _scalar(s, "SELECT count(*) FROM channels WHERE provider IS NOT NULL OR package IS NOT NULL") == 0


def test_rule_9_satellite_resolved_by_raw_name(db):
    s, _ = db
    sats = dict(
        s.execute(
            text(
                "SELECT ch.legacy_id, sat.legacy_id FROM channels ch "
                "LEFT JOIN satellites sat ON sat.id = ch.satellite_id"
            )
        ).all()
    )
    assert sats["ch-cyr"] == "sat-eutel"
    assert sats["ch-nosr"] == "sat-eutel-africa"  # satelliteEn " Eutel 16.0E"
    assert sats["ch-terr"] == "sat-dvbt2"
    assert sats["ch-platform-mega"] is None


def test_rule_9_duplicates_merge_into_lowest_channel_order(db):
    s, _ = db
    legacy_ids = set(s.execute(text("SELECT legacy_id FROM channels")).scalars())
    assert "ch-carriage-dup-b" not in legacy_ids and "ch-carriage-dup-a" in legacy_ids
    assert "ch-platform-dup-b" not in legacy_ids and "ch-platform-dup-a" in legacy_ids
    # The merged rows' match links moved onto the survivor (collapsed into one link).
    rows = {
        (r.match, r.channel): (r.is_hidden, r.commentator)
        for r in s.execute(
            text(
                "SELECT m.legacy_id AS match, ch.legacy_id AS channel, mc.is_hidden, c.name AS commentator "
                "FROM match_channels mc JOIN matches m ON m.id = mc.match_id JOIN channels ch ON ch.id = mc.channel_id "
                "LEFT JOIN commentators c ON c.id = mc.commentator_id"
            )
        )
    }
    # dup-a is hidden but dup-b isn't: the channel was still shown, so the link is visible,
    # and it takes dup-b's commentator.
    assert rows[("m-unmarked", "ch-carriage-dup-a")] == (False, "معلق تجريبي")
    # Both platform copies hidden → the collapsed link stays hidden.
    assert rows[("m-today", "ch-platform-dup-a")] == (True, None)


def test_rule_9_sort_order_and_show_in_match(db):
    s, _ = db
    # sort_order comes from settings/channelOrder, never from the dropped `order` field.
    assert _scalar(s, "SELECT sort_order FROM channels WHERE legacy_id = 'ch-cyr'") == 0
    assert _scalar(s, "SELECT show_in_match FROM channels WHERE legacy_id = 'ch-bundle-mega'") is True


# --- Rules 10–11: rights and match_channels.source --------------------------------


def test_rule_10_rights_holders(db):
    s, report = db
    assert _one(s, "SELECT name, sort_order FROM rights_holders WHERE legacy_id = 'right-1'") == ("CANAL+SPORT", 0)
    carriages = s.execute(
        text(
            "SELECT c.position, c.access, c.beam, array_agg(sat.legacy_id ORDER BY sat.legacy_id) AS sats "
            "FROM rights_holder_carriages c JOIN rights_holders rh ON rh.id = c.rights_holder_id "
            "LEFT JOIN rights_holder_carriage_satellites cs ON cs.carriage_id = c.id "
            "LEFT JOIN satellites sat ON sat.id = cs.satellite_id "
            "WHERE rh.legacy_id = 'right-2' GROUP BY c.position, c.access, c.beam ORDER BY c.position"
        )
    ).all()
    assert [tuple(c) for c in carriages] == [
        (0, "free", "narrow", ["sat-badr", "sat-nilesat"]),
        (1, "encrypted", None, ["sat-eutel"]),
    ]
    comps = set(
        s.execute(
            text(
                "SELECT c.legacy_id FROM rights_holder_competitions rc JOIN competitions c ON c.id = rc.competition_id "
                "JOIN rights_holders rh ON rh.id = rc.rights_holder_id WHERE rh.legacy_id = 'right-2'"
            )
        ).scalars()
    )
    assert comps == {"comp-2"}
    # satellite[] is dropped; right-2's list differs from its carriages' union → check by hand.
    assert [w["ref"] for w in _warnings(report, "rights_satellites_mismatch")] == ["right-2"]


def test_rule_11_match_channel_source(db):
    s, _ = db
    sources = {
        (r.match, r.channel): r.source
        for r in s.execute(
            text(
                "SELECT m.legacy_id AS match, ch.legacy_id AS channel, mc.source FROM match_channels mc "
                "JOIN matches m ON m.id = mc.match_id JOIN channels ch ON ch.id = mc.channel_id"
            )
        )
    }
    assert sources[("m-unmarked", "ch-badr-enc")] == "ysscores"  # in importedChannelIds
    assert sources[("m-unmarked", "ch-platform-mega")] == "legacy"
    assert sources[("m-1", "ch-nilesat-free")] == "legacy"


def test_channel_commentators_respect_the_pair_constraint(db):
    s, _ = db
    pairs = {
        r.match: (r.c1, r.c2)
        for r in s.execute(
            text(
                "SELECT m.legacy_id AS match, c1.name AS c1, mc.commentator2_id AS c2 FROM match_channels mc "
                "JOIN matches m ON m.id = mc.match_id JOIN channels ch ON ch.id = mc.channel_id "
                "LEFT JOIN commentators c1 ON c1.id = mc.commentator_id WHERE ch.legacy_id = 'ch-nilesat-free' "
                "AND m.legacy_id IN ('m-1', 'm-tbd')"
            )
        )
    }
    assert pairs["m-1"] == ("معلق تجريبي", None)  # name2 == name → dropped
    assert pairs["m-tbd"] == ("معلق ثان فقط", None)  # name2 without name → moved to slot 1


def test_custom_broadcasts(db):
    s, _ = db
    rows = s.execute(
        text(
            "SELECT b.slot, b.label, c.name FROM match_custom_broadcasts b JOIN matches m ON m.id = b.match_id "
            "LEFT JOIN commentators c ON c.id = b.commentator_id WHERE m.legacy_id = 'm-1' ORDER BY b.slot"
        )
    ).all()
    assert [tuple(r) for r in rows] == [
        (1, "قناة مخصصة", "معلق تجريبي"),
        (2, "قناة مخصصة ثانية", "معلق ثان على المباراة"),
    ]


def test_feeds_load_with_match_id(db):
    s, report = db
    feeds = {
        r.legacy_id: (r.match, r.feed_date, list(r.lines))
        for r in s.execute(
            text(
                "SELECT f.legacy_id, m.legacy_id AS match, f.feed_date, f.lines FROM feeds f "
                "LEFT JOIN matches m ON m.id = f.match_id"
            )
        )
    }
    # The BISS key line is dropped (FR-005); only tuning stays.
    assert feeds["feed-1"] == ("m-1", feeds["feed-1"][1], ["Eutelsat 3.1°E - 10969 H 7500"])
    assert str(feeds["feed-1"][1]) == "2026-10-28"
    assert feeds["feed-2"][0] == "m-1"  # listed against the merged m-1b
    assert feeds["feed-3"][0] is None  # no match row fits
    assert [w["ref"] for w in _warnings(report, "feed_line_dropped")] == ["feed-1"]
    assert "Biss" not in json.dumps(report.warnings, ensure_ascii=False)


# --- Rule 12: satellites ---------------------------------------------------------


def test_rule_12_satellites(db):
    s, _ = db
    rows = {
        r.legacy_id: (
            r.name_en,
            r.slug,
            r.kind,
            None if r.orbital_position is None else float(r.orbital_position),
            r.priority,
        )
        for r in s.execute(text("SELECT legacy_id, name_en, slug, kind, orbital_position, priority FROM satellites"))
    }
    assert rows["sat-eutel-africa"] == ("Eutel 16.0E Africa", "eutel-16-0e-africa", "satellite", 16.0, 3)
    assert rows["sat-eutel"] == ("Eutel 16.0E", "eutel-16-0e", "satellite", 16.0, 2)
    assert rows["sat-nilesat"] == ("Nilesat 7.0W", "nilesat-7-0w", "satellite", -7.0, 0)
    assert rows["sat-dvbt2"] == ("DVB T2", "dvb-t2", "terrestrial", None, 5)
    assert rows["sat-turksat"] == ("Türksat 42.0E", "turksat-42-0e", "satellite", 42.0, 7)


# --- Rules 13–15: teams, LiveSoccerTV, normalized names -----------------------------


def test_rule_13_team_external_ids_and_duplicate_ys_id(db):
    s, report = db
    ext = dict(
        s.execute(
            text(
                "SELECT e.external_id, t.legacy_id FROM team_external_ids e "
                "JOIN teams t ON t.id = e.team_id WHERE e.source = 'ysscores'"
            )
        ).all()
    )
    assert ext == {"990001": "team-ahly-eg", "990002": "team-zamalek"}
    assert [w["ref"] for w in _warnings(report, "team_external_id_duplicate")] == ["team-ahly-sa"]
    assert _scalar(s, "SELECT count(*) FROM teams WHERE country IS NOT NULL OR sport <> 'football'") == 0
    comps = set(
        s.execute(
            text(
                "SELECT t.legacy_id || '>' || c.legacy_id FROM team_competitions tc "
                "JOIN teams t ON t.id = tc.team_id JOIN competitions c ON c.id = tc.competition_id"
            )
        ).scalars()
    )
    assert comps == {"team-ahly-eg>comp-1", "team-zamalek>comp-1", "team-city>comp-2", "team-villa>comp-2"}


def test_rule_14_livesoccertv_teams(db):
    s, _ = db
    rows = {
        r.ar_name: (r.slug, r.country, r.team)
        for r in s.execute(
            text(
                "SELECT l.ar_name, l.slug, l.country, t.legacy_id AS team FROM livesoccertv_teams l "
                "LEFT JOIN teams t ON t.id = l.team_id"
            )
        )
    }
    assert rows == {
        "الأهلي": ("fixture-ahly", "egypt", None),  # two teams share the name
        "الزمالك": ("fixture-zamalek", "egypt", "team-zamalek"),
        "زمالك": ("fixture-zamalek", "egypt", None),  # second spelling of the same page
        "منتخب تجريبي": ("fixture-national", None, None),  # no country
    }


def test_rule_15_normalized_names(db):
    s, _ = db
    assert set(s.execute(text("SELECT name FROM hidden_channel_names")).scalars()) == {"bein sports en 1"}
    for table in ("teams", "competitions", "channels", "commentators"):
        # Constant table names; the generated column must agree with the Python normalizer.
        rows = s.execute(text(f"SELECT name, name_norm FROM {table}")).all()  # noqa: S608
        assert rows and all(norm == ar_normalize(name) for name, norm in rows), table


# --- Rule 17: settings that aren't stored -------------------------------------------


def test_rule_17_settings_are_not_stored(db):
    s, report = db
    assert _scalar(s, "SELECT count(*) FROM import_runs") == 0
    assert _scalar(s, "SELECT to_regclass('settings') IS NULL AND to_regclass('app_settings') IS NULL") is True
    assert not {"app", "autoImport", "extraPlatforms", "settings"} & set(report.collections)
