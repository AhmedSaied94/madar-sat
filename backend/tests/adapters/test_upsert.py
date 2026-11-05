"""The upsert pipeline: identity, locks, the duplicate probe, links, audit and bumps (T060, R18)."""

from __future__ import annotations

from datetime import UTC, date, datetime, timedelta
from typing import Any

from sqlalchemy import func, select, text
from sqlalchemy.orm import Session

from app.adapters.base import FixtureLink, NormalizedFixture
from app.adapters.upsert import LogoJob, UpsertPipeline
from app.db.models import (
    AuditLog,
    Channel,
    Competition,
    DatasetVersion,
    Match,
    MatchChannel,
    MatchExternalId,
    Team,
)

DAY = date(2026, 11, 5)
KICKOFF = datetime(2026, 11, 5, 18, 0, tzinfo=UTC)
HOUSE = ["imgs.ysscores.com", "pub-01ffc6064b9b435aa726a53a561a6f53.r2.dev"]


def fixture(**overrides: Any) -> NormalizedFixture:
    fields: dict[str, Any] = {
        "match_date": DAY,
        "kickoff_at": KICKOFF,
        "time_tbd": False,
        "home": "الزمالك",
        "away": "مان سيتي",
        "competition": "الدوري المصري الممتاز",
        "stage": "الجولة 10",
        "external_id": "ys-1001",
        "url": "https://www.ysscores.com/ar/match/ys-1001/x",
    }
    fields.update(overrides)
    return NormalizedFixture(**fields)


def pipeline(sync_session: Session, source: str = "ysscores") -> UpsertPipeline:
    return UpsertPipeline(sync_session, source=source, media_hosts=HOUSE)


def team_id(sync_session: Session, legacy_id: str) -> int:
    return sync_session.execute(select(Team.id).where(Team.legacy_id == legacy_id)).scalar_one()


def channel_id(sync_session: Session, legacy_id: str) -> int:
    return sync_session.execute(select(Channel.id).where(Channel.legacy_id == legacy_id)).scalar_one()


def versions(sync_session: Session) -> dict[str, int]:
    return dict(sync_session.execute(select(DatasetVersion.name, DatasetVersion.version)).all())


def test_a_first_run_creates_and_a_second_run_changes_nothing(sync_session: Session, loaded_snapshot) -> None:
    run = pipeline(sync_session)
    first = run.run([fixture()])
    assert (first.created, first.updated, first.items_upserted) == (1, 0, 1)

    row = sync_session.execute(
        select(Match)
        .join(MatchExternalId, MatchExternalId.match_id == Match.id)
        .where(MatchExternalId.source == "ysscores", MatchExternalId.external_id == "ys-1001")
    ).scalar_one()
    assert row.kickoff_at == KICKOFF
    assert row.kickoff_at.tzinfo is not None
    assert row.competition_id is not None
    assert row.home_team_id == team_id(sync_session, "team-zamalek")
    assert row.away_team_id == team_id(sync_session, "team-city")

    second = pipeline(sync_session).run([fixture()])
    assert (second.created, second.updated, second.items_upserted) == (0, 0, 0)


def test_a_locked_kickoff_survives_even_when_the_lock_commits_after_the_run_started(
    sync_session: Session, loaded_snapshot
) -> None:
    pipeline(sync_session).run([fixture()])
    match = sync_session.execute(
        select(Match)
        .join(MatchExternalId, MatchExternalId.match_id == Match.id)
        .where(MatchExternalId.external_id == "ys-1001")
    ).scalar_one()
    # The run starts here: its session already holds the row.
    stale_copy = match.id

    # An editor saves the kickoff and the lock, and commits while the run is in flight.
    locked_kickoff = datetime(2026, 11, 5, 21, 30, tzinfo=UTC)
    other = Session(bind=sync_session.connection(), join_transaction_mode="create_savepoint")
    try:
        other.execute(update_match(stale_copy).values(kickoff_at=locked_kickoff, locked_fields=["kickoff_at"]))
        other.commit()
    finally:
        other.close()

    outcome = pipeline(sync_session).run([fixture(kickoff_at=datetime(2026, 11, 5, 19, 0, tzinfo=UTC))])
    assert outcome.updated == 0
    sync_session.expire_all()
    kept = sync_session.execute(select(Match).where(Match.id == stale_copy)).scalar_one()
    assert kept.kickoff_at == locked_kickoff
    assert kept.locked_fields == ["kickoff_at"]


def _stored(sync_session: Session, external_id: str) -> Match:
    return sync_session.execute(
        select(Match)
        .join(MatchExternalId, MatchExternalId.match_id == Match.id)
        .where(MatchExternalId.external_id == external_id)
    ).scalar_one()


def test_a_postponed_item_clears_the_kickoff_and_sets_time_tbd(sync_session: Session, loaded_snapshot) -> None:
    """B2-R1-10: the fixture stays, and its old time stops being shown as a schedule."""
    pipeline(sync_session).run([fixture()])
    before = _stored(sync_session, "ys-1001")
    assert (before.kickoff_at, before.time_tbd) == (KICKOFF, False)

    outcome = pipeline(sync_session).run([fixture(kickoff_at=None, time_tbd=True, postponed=True)])

    sync_session.expire_all()
    after = _stored(sync_session, "ys-1001")
    assert (after.kickoff_at, after.time_tbd) == (None, True)
    assert outcome.postponed == [{"ref": "ys-1001"}]


def test_a_locked_kickoff_with_a_tbd_item_keeps_the_pair_valid(sync_session: Session, loaded_snapshot) -> None:
    """B2-R1-11: writing ``time_tbd`` under a locked kickoff would trip ``ck_matches_time_tbd``."""
    pipeline(sync_session).run([fixture()])
    match = _stored(sync_session, "ys-1001")
    other = Session(bind=sync_session.connection(), join_transaction_mode="create_savepoint")
    try:
        other.execute(update_match(match.id).values(kickoff_at=KICKOFF, locked_fields=["kickoff_at"]))
        other.commit()
    finally:
        other.close()

    outcome = pipeline(sync_session).run([fixture(kickoff_at=None, time_tbd=True, postponed=True)])

    sync_session.expire_all()
    kept = _stored(sync_session, "ys-1001")
    assert (kept.kickoff_at, kept.time_tbd) == (KICKOFF, False)  # the editor's kickoff wins, and stays consistent
    assert outcome.skipped == []  # the item's other fields still updated


def update_match(match_id: int):
    from sqlalchemy import update

    return update(Match).where(Match.id == match_id)


def test_the_duplicate_probe_joins_a_fixture_within_45_minutes(sync_session: Session, loaded_snapshot) -> None:
    pipeline(sync_session, "ysscores").run([fixture()])
    before = sync_session.execute(select(func.count()).select_from(Match)).scalar_one()

    # The same teams 30 minutes later, from the bridge: the same row gains a legacy id.
    bridge = pipeline(sync_session, "legacy")
    outcome = bridge.run([fixture(**source_legacy())])
    assert (outcome.created, outcome.updated) == (0, 1)
    assert sync_session.execute(select(func.count()).select_from(Match)).scalar_one() == before
    joined = sync_session.execute(select(Match).where(Match.legacy_id == "sat-1")).scalar_one()
    assert (
        joined.id
        == sync_session.execute(
            select(MatchExternalId.match_id).where(MatchExternalId.external_id == "ys-1001")
        ).scalar_one()
    )


def source_legacy(**overrides: Any) -> dict[str, Any]:
    fields: dict[str, Any] = {
        "external_id": None,
        "legacy_id": "sat-1",
        "ys_match_id": "ys-1001",
        "kickoff_at": KICKOFF + timedelta(minutes=30),
        "url": None,
    }
    fields.update(overrides)
    return fields


def test_46_minutes_apart_is_a_new_row(sync_session: Session, loaded_snapshot) -> None:
    pipeline(sync_session).run([fixture(external_id="ys-2001")])
    before = sync_session.execute(select(func.count()).select_from(Match)).scalar_one()
    outcome = pipeline(sync_session, "legacy").run(
        [
            fixture(
                external_id=None,
                legacy_id="sat-2",
                ys_match_id=None,
                kickoff_at=KICKOFF + timedelta(minutes=46),
            )
        ]
    )
    assert outcome.created == 1
    assert sync_session.execute(select(func.count()).select_from(Match)).scalar_one() == before + 1


def test_without_team_ids_the_same_names_on_the_same_day_are_the_same_fixture(
    sync_session: Session, loaded_snapshot
) -> None:
    unknown = fixture(external_id="ys-3001", home="فريق أول", away="فريق ثان", kickoff_at=None, time_tbd=True)
    pipeline(sync_session).run([unknown])
    before = sync_session.execute(select(func.count()).select_from(Match)).scalar_one()
    outcome = pipeline(sync_session, "legacy").run(
        [
            fixture(
                external_id=None,
                legacy_id="sat-3",
                ys_match_id=None,
                home="فريق أول",
                away=" فريق ثان ",
                kickoff_at=None,
                time_tbd=True,
            )
        ]
    )
    assert outcome.created == 0
    assert sync_session.execute(select(func.count()).select_from(Match)).scalar_one() == before


def test_links_follow_the_importer_rules(sync_session: Session, loaded_snapshot) -> None:
    cyr = channel_id(sync_session, "ch-cyr")
    hidden = channel_id(sync_session, "ch-hidden")
    nilesat = channel_id(sync_session, "ch-nilesat-free")
    manual = channel_id(sync_session, "ch-terr")
    links = (
        FixtureLink(channel_ref="ch-cyr", commentator="معلق اول"),
        FixtureLink(channel_ref="ch-hidden", hidden=True),
        FixtureLink(channel_ref="orphan-channel-1"),
    )
    outcome = pipeline(sync_session, "legacy").run([fixture(**source_legacy(links=links))])
    assert outcome.created == 1
    match_id = sync_session.execute(select(Match.id).where(Match.legacy_id == "sat-1")).scalar_one()

    rows = {
        row.channel_id: row
        for row in sync_session.execute(select(MatchChannel).where(MatchChannel.match_id == match_id)).scalars()
    }
    assert set(rows) == {cyr, hidden}  # the orphan id is skipped, not stored
    assert rows[cyr].source == rows[cyr].imported_by == "legacy"
    assert rows[cyr].commentator_id is not None
    assert rows[hidden].is_hidden is True

    # An editor's own link, hidden by them, on the same match.
    sync_session.add(MatchChannel(match_id=match_id, channel_id=manual, source="manual", is_hidden=True))
    sync_session.flush()

    # The source now lists the other channel instead; its own hidden one is gone.
    outcome = pipeline(sync_session, "legacy").run(
        [fixture(**source_legacy(links=(FixtureLink(channel_ref="ch-nilesat-free"),)))],
    )
    assert outcome.updated == 1
    rows = {
        row.channel_id: row
        for row in sync_session.execute(select(MatchChannel).where(MatchChannel.match_id == match_id)).scalars()
    }
    assert set(rows) == {nilesat, manual}
    assert rows[manual].source == "manual"
    assert rows[manual].is_hidden is True  # untouched, and not re-added as the importer's


def test_a_source_link_that_matches_an_editors_hidden_link_leaves_it_alone(
    sync_session: Session, loaded_snapshot
) -> None:
    """The re-add path: the source lists the channel, but the editor's hidden link stays theirs."""
    cyr = channel_id(sync_session, "ch-cyr")
    pipeline(sync_session, "legacy").run([fixture(**source_legacy(links=(FixtureLink(channel_ref="ch-cyr"),)))])
    match_id = sync_session.execute(select(Match.id).where(Match.legacy_id == "sat-1")).scalar_one()
    sync_session.execute(
        MatchChannel.__table__.delete().where(
            MatchChannel.match_id == match_id, MatchChannel.channel_id == cyr, MatchChannel.source == "legacy"
        )
    )
    sync_session.flush()
    sync_session.add(MatchChannel(match_id=match_id, channel_id=cyr, source="manual", is_hidden=True))
    sync_session.flush()

    outcome = pipeline(sync_session, "legacy").run(
        [fixture(**source_legacy(links=(FixtureLink(channel_ref="ch-cyr"),)))],
    )

    rows = sync_session.execute(select(MatchChannel).where(MatchChannel.match_id == match_id)).scalars().all()
    assert [(row.channel_id, row.source, row.is_hidden) for row in rows] == [(cyr, "manual", True)]
    assert outcome.created + outcome.updated == 0
    # The guard skips the insert quietly: without it the row falls into a failed savepoint and the
    # item lands in `skipped` (B2-R2-18).
    assert outcome.skipped == []


def test_a_normalize_error_skips_one_item_inside_its_savepoint(sync_session: Session, loaded_snapshot) -> None:
    """B2-R1-12: normalising runs in the item's savepoint, so one bad value is one skipped item."""
    from app.adapters.base import ParsedFixture

    items = [
        ParsedFixture(external_id="ys-ok", match_date=DAY, home="الزمالك", away="مان سيتي", wall_time="10:00 م"),
        ParsedFixture(external_id="ys-bad", match_date=DAY, home="الأهلي", away="الزمالك", wall_time="12:99 م"),
    ]

    def normalize(item):
        if item.external_id == "ys-bad":
            raise ValueError("12:99 م")
        return fixture(external_id=item.external_id)

    outcome = pipeline(sync_session).run(items, normalize=normalize)

    assert outcome.created == 1
    assert outcome.skipped == [{"ref": "ys-bad", "reason": "error"}]


def test_a_bad_item_marks_the_run_partial_and_the_rest_lands(sync_session: Session, loaded_snapshot) -> None:
    outcome = pipeline(sync_session).run(
        [
            fixture(external_id="ys-4001"),
            fixture(external_id="ys-4002", home=None),
            fixture(external_id="ys-4003", away=""),
        ]
    )
    assert outcome.items_found == 3
    assert outcome.created == 1
    assert [s["reason"] for s in outcome.skipped] == ["missing_teams", "missing_teams"]


def test_a_changed_match_is_audited_with_the_source(sync_session: Session, loaded_snapshot) -> None:
    pipeline(sync_session).run([fixture()])
    outcome = pipeline(sync_session).run([fixture(stage="الجولة 11")])
    assert outcome.updated == 1
    audit = (
        sync_session.execute(select(AuditLog).where(AuditLog.entity == "matches", AuditLog.action == "update"))
        .scalars()
        .all()
    )
    assert audit
    entry = audit[-1]
    assert entry.admin_user_id is None
    assert entry.source == "ysscores"
    assert entry.diff["competition_stage"] == ["الجولة 10", "الجولة 11"]


def test_versions_bump_once_per_run_and_not_at_all_when_nothing_changed(sync_session: Session, loaded_snapshot) -> None:
    before = versions(sync_session)
    pipeline(sync_session).run([fixture(external_id="ys-5001"), fixture(external_id="ys-5002", home="الأهلي")])
    after = versions(sync_session)
    assert after["matches"] == before["matches"] + 1
    assert after["live"] == before["live"]  # no kickoff changed after the insert

    pipeline(sync_session).run([fixture(external_id="ys-5001"), fixture(external_id="ys-5002", home="الأهلي")])
    assert versions(sync_session)["matches"] == after["matches"]

    pipeline(sync_session).run([fixture(external_id="ys-5001", kickoff_at=KICKOFF + timedelta(hours=1))])
    assert versions(sync_session)["live"] == before["live"] + 1


def test_a_new_team_logo_is_queued_but_never_stored(sync_session: Session, loaded_snapshot) -> None:
    city = team_id(sync_session, "team-city")
    outcome = pipeline(sync_session).run([fixture(away_logo="https://imgs.ysscores.com/teams/64/city.png")])
    expected = LogoJob(
        entity="teams", entity_id=city, url="https://imgs.ysscores.com/teams/64/city.png", source="ysscores"
    )
    assert expected in outcome.logo_jobs
    row = sync_session.execute(
        select(Match)
        .join(MatchExternalId, MatchExternalId.match_id == Match.id)
        .where(MatchExternalId.external_id == "ys-1001")
    ).scalar_one()
    assert row.home_logo_asset_id is None and row.away_logo_asset_id is None
    assert sync_session.execute(select(Team.logo_asset_id).where(Team.id == city)).scalar_one() is None


def test_a_logo_that_already_exists_is_not_queued_again(sync_session: Session, loaded_snapshot) -> None:
    from app.db.models import MediaAsset

    asset = MediaAsset(
        sha256="f" * 64, kind="logo", path="logo/ff/x.webp", mime="image/webp", bytes=10, width=64, height=64
    )
    sync_session.add(asset)
    sync_session.flush()
    ahly = team_id(sync_session, "team-ahly-eg")
    sync_session.execute(__import__("sqlalchemy").update(Team).where(Team.id == ahly).values(logo_asset_id=asset.id))
    outcome = pipeline(sync_session).run([fixture(home="الأهلي", home_logo="https://imgs.ysscores.com/teams/1/a.png")])
    assert all(job.entity_id != ahly for job in outcome.logo_jobs)


def test_an_unresolved_name_is_listed_for_run_json(sync_session: Session, loaded_snapshot) -> None:
    outcome = pipeline(sync_session).run([fixture(home="فريق لا يوجد", away="فريق آخر لا يوجد")])
    names = {entry["name"] for entry in outcome.unresolved}
    assert names == {"فريق لا يوجد", "فريق آخر لا يوجد"}
    assert outcome.unresolved[0]["competition"] == "الدوري المصري الممتاز"


def test_the_pipeline_never_creates_a_team_or_a_competition(sync_session: Session, loaded_snapshot) -> None:
    teams = sync_session.execute(select(func.count()).select_from(Team)).scalar_one()
    competitions = sync_session.execute(select(func.count()).select_from(Competition)).scalar_one()
    pipeline(sync_session).run([fixture(home="فريق لا يوجد", competition="دوري لا يوجد")])
    assert sync_session.execute(select(func.count()).select_from(Team)).scalar_one() == teams
    assert sync_session.execute(select(func.count()).select_from(Competition)).scalar_one() == competitions


def test_the_match_record_keeps_the_cairo_day_and_no_status(sync_session: Session, loaded_snapshot) -> None:
    pipeline(sync_session).run([fixture()])
    row = sync_session.execute(
        select(Match)
        .join(MatchExternalId, MatchExternalId.match_id == Match.id)
        .where(MatchExternalId.external_id == "ys-1001")
    ).scalar_one()
    assert row.match_date == DAY
    assert row.source == "ysscores"
    assert row.status == "scheduled"  # importers write no status (constitution II)
    assert row.is_live is False


def test_a_raw_sql_reader_sees_the_same_row(sync_session: Session, loaded_snapshot) -> None:
    pipeline(sync_session).run([fixture()])
    stored = sync_session.execute(
        text("select count(*) from match_external_ids where external_id = 'ys-1001'")
    ).scalar_one()
    assert stored == 1


def test_a_ysscores_run_keeps_the_links_the_snapshot_gave_it(sync_session: Session, loaded_snapshot) -> None:
    """B2-R1-2, FR-022: ysscores supplies no links, so its run must not delete any.

    The snapshot stored the old app's imported links with ``source='ysscores'``. Treating "no links
    in the item" as "no links on the match" wiped every channel of every match on the first run.
    """
    match_id, external_id, home, away, kickoff, match_date = sync_session.execute(
        select(
            Match.id,
            MatchExternalId.external_id,
            Match.home_team_name,
            Match.away_team_name,
            Match.kickoff_at,
            Match.match_date,
        )
        .join(MatchExternalId, MatchExternalId.match_id == Match.id)
        .join(MatchChannel, MatchChannel.match_id == Match.id)
        .where(MatchExternalId.source == "ysscores", MatchChannel.source == "ysscores")
        .order_by(Match.id)
        .limit(1)
    ).one()
    before = set(
        sync_session.execute(select(MatchChannel.channel_id).where(MatchChannel.match_id == match_id)).scalars()
    )
    assert before

    pipeline(sync_session).run(
        [
            fixture(
                external_id=external_id,
                home=home,
                away=away,
                kickoff_at=kickoff,
                match_date=match_date,
                competition=None,
            )
        ]
    )

    after = set(
        sync_session.execute(select(MatchChannel.channel_id).where(MatchChannel.match_id == match_id)).scalars()
    )
    assert after == before


def test_the_run_takes_the_row_lock_before_it_reads(sync_session: Session, loaded_snapshot) -> None:
    """B2-R1-16: the run locks the row first, so a concurrent editor's save is waited for, never lost.

    Another connection holds the row (as an editor's PATCH does). With the `FOR UPDATE` the run
    blocks and its item is rolled back into `skipped`; without it, the run would read a stale copy
    and the item would simply look unchanged. That difference is what this test asserts.
    """
    import os

    import psycopg
    from sqlalchemy import text

    match = sync_session.execute(
        select(Match, MatchExternalId.external_id)
        .join(MatchExternalId, MatchExternalId.match_id == Match.id)
        .where(MatchExternalId.source == "ysscores", Match.kickoff_at.is_not(None))
        .order_by(Match.id)
        .limit(1)
    ).one()
    row, external_id = match[0], match[1]

    url = os.environ["DATABASE_URL_SYNC"].replace("postgresql+psycopg://", "postgresql://")
    other = psycopg.connect(url)
    try:
        other.execute("SELECT id FROM matches WHERE id = %s FOR UPDATE", (row.id,))
        sync_session.execute(text("SET LOCAL lock_timeout = '300ms'"))

        outcome = pipeline(sync_session).run(
            [
                fixture(
                    external_id=external_id,
                    home=row.home_team_name,
                    away=row.away_team_name,
                    kickoff_at=row.kickoff_at,
                    match_date=row.match_date,
                    competition=row.competition_name,
                    stage=row.competition_stage,
                )
            ]
        )
    finally:
        other.rollback()
        other.close()

    assert outcome.skipped == [{"ref": external_id, "reason": "error"}]


# --- D5: the unresolved queue and the Egyptian broadcaster (T051) -------------------------------


def _queued(sync_session: Session) -> list[Any]:
    return list(
        sync_session.execute(
            text("SELECT source, kind, name, competition_norm, context, seen_count FROM unresolved_names ORDER BY id")
        ).mappings()
    )


def _yk(**overrides: Any) -> NormalizedFixture:
    fields: dict[str, Any] = {
        "home": "فريق لا يوجد",
        "away": "مان سيتي",
        "competition": "الدوري المصري الممتاز",
        "external_id": "114019",
        "url": "https://www.yallakora.com/egypt-cup/3066/match/114019/x",
    }
    fields.update(overrides)
    return fixture(**fields)


def _broadcaster(sync_session: Session, match_id: int) -> str | None:
    return sync_session.execute(
        text("SELECT local_broadcaster_eg FROM matches WHERE id = :id"), {"id": match_id}
    ).scalar_one()


def _yk_match(sync_session: Session, external_id: str = "114019") -> Match:
    return sync_session.execute(
        select(Match)
        .join(MatchExternalId, MatchExternalId.match_id == Match.id)
        .where(MatchExternalId.source == "yallakora", MatchExternalId.external_id == external_id)
    ).scalar_one()


def test_an_unknown_team_is_queued_and_the_match_keeps_the_text_name(sync_session: Session, loaded_snapshot) -> None:
    teams = sync_session.execute(select(func.count()).select_from(Team)).scalar_one()
    before = versions(sync_session)

    outcome = pipeline(sync_session, "yallakora").run([_yk()])

    assert outcome.created == 1
    assert sync_session.execute(select(func.count()).select_from(Team)).scalar_one() == teams
    match = _yk_match(sync_session)
    assert (match.home_team_id, match.home_team_name) == (None, "فريق لا يوجد")
    [row] = _queued(sync_session)
    assert (row["source"], row["kind"], row["name"], row["seen_count"]) == ("yallakora", "team", "فريق لا يوجد", 1)
    assert row["context"]["match_id"] == match.id
    assert row["context"]["away"] == "مان سيتي"
    assert row["context"]["competition"] == "الدوري المصري الممتاز"
    assert row["context"]["kickoff_at"] == KICKOFF.isoformat()
    assert versions(sync_session)["unresolved_names"] == before["unresolved_names"] + 1


def test_an_unknown_competition_is_queued_and_none_is_created(sync_session: Session, loaded_snapshot) -> None:
    competitions = sync_session.execute(select(func.count()).select_from(Competition)).scalar_one()

    pipeline(sync_session, "yallakora").run([_yk(home="الزمالك", competition="كأس لا توجد")])

    assert sync_session.execute(select(func.count()).select_from(Competition)).scalar_one() == competitions
    assert [(row["kind"], row["name"]) for row in _queued(sync_session)] == [("competition", "كأس لا توجد")]
    assert _yk_match(sync_session).competition_name == "كأس لا توجد"


def test_a_second_run_raises_the_count_and_adds_no_row(sync_session: Session, loaded_snapshot) -> None:
    pipeline(sync_session, "yallakora").run([_yk()])
    pipeline(sync_session, "yallakora").run([_yk()])

    assert [row["seen_count"] for row in _queued(sync_session)] == [2]


def test_every_importer_queues_what_it_cannot_match(sync_session: Session, loaded_snapshot) -> None:
    pipeline(sync_session, "ysscores").run([fixture(home="فريق لا يوجد")])

    assert [(row["source"], row["name"]) for row in _queued(sync_session)] == [("ysscores", "فريق لا يوجد")]


def test_nothing_unmatched_queues_nothing_and_moves_no_version(sync_session: Session, loaded_snapshot) -> None:
    before = versions(sync_session)["unresolved_names"]

    pipeline(sync_session).run([fixture()])

    assert _queued(sync_session) == []
    assert versions(sync_session)["unresolved_names"] == before


def test_an_alias_written_after_a_run_is_used_by_the_next_one(sync_session: Session, loaded_snapshot) -> None:
    """SC-007: an editor's mapping takes effect on the next import, for that source."""
    pipeline(sync_session, "yallakora").run([_yk(home="الزمالك الجديد")])
    assert _yk_match(sync_session).home_team_id is None
    sync_session.execute(
        text("INSERT INTO team_aliases (source, alias_norm, team_id) VALUES ('yallakora', ar_normalize(:a), :t)"),
        {"a": "الزمالك الجديد", "t": team_id(sync_session, "team-zamalek")},
    )

    pipeline(sync_session, "yallakora").run([_yk(home="الزمالك الجديد")])

    sync_session.expire_all()
    assert _yk_match(sync_session).home_team_id == team_id(sync_session, "team-zamalek")


def test_the_broadcaster_is_written_on_create_and_on_change(sync_session: Session, loaded_snapshot) -> None:
    pipeline(sync_session, "yallakora").run([_yk(local_broadcaster_eg="ON Sport")])
    match_id = _yk_match(sync_session).id
    assert _broadcaster(sync_session, match_id) == "ON Sport"

    second = pipeline(sync_session, "yallakora").run([_yk(local_broadcaster_eg="ON Sport")])
    assert second.updated == 0

    third = pipeline(sync_session, "yallakora").run([_yk(local_broadcaster_eg="ON Sport MAX")])
    assert third.updated == 1
    assert _broadcaster(sync_session, match_id) == "ON Sport MAX"
    audit = (
        sync_session.execute(
            select(AuditLog)
            .where(AuditLog.entity == "matches", AuditLog.entity_id == match_id)
            .order_by(AuditLog.id.desc())
        )
        .scalars()
        .first()
    )
    assert audit.diff["local_broadcaster_eg"] == ["ON Sport", "ON Sport MAX"]


def test_a_card_with_no_channel_does_not_clear_the_broadcaster(sync_session: Session, loaded_snapshot) -> None:
    pipeline(sync_session, "yallakora").run([_yk(local_broadcaster_eg="ON Sport")])

    outcome = pipeline(sync_session, "yallakora").run([_yk()])

    assert outcome.updated == 0
    assert _broadcaster(sync_session, _yk_match(sync_session).id) == "ON Sport"


def test_a_locked_broadcaster_is_skipped(sync_session: Session, loaded_snapshot) -> None:
    pipeline(sync_session, "yallakora").run([_yk(local_broadcaster_eg="ON Sport")])
    match = _yk_match(sync_session)
    sync_session.execute(update_match(match.id).values(locked_fields=["local_broadcaster_eg"]))

    outcome = pipeline(sync_session, "yallakora").run([_yk(local_broadcaster_eg="MBC مصر")])

    assert outcome.updated == 0
    assert _broadcaster(sync_session, match.id) == "ON Sport"


def test_yallakora_never_overwrites_a_fixture_another_source_owns(sync_session: Session, loaded_snapshot) -> None:
    """Otherwise each run would rewrite the other's spelling and stage, and stale every open editor."""
    pipeline(sync_session, "ysscores").run([fixture()])
    owned = _stored(sync_session, "ys-1001")
    stage, kickoff = owned.competition_stage, owned.kickoff_at

    outcome = pipeline(sync_session, "yallakora").run(
        [
            fixture(
                external_id="114019",
                stage="مرحلة أخرى",
                kickoff_at=KICKOFF + timedelta(minutes=30),
                local_broadcaster_eg="ON Sport",
            )
        ]
    )

    assert (outcome.created, outcome.updated) == (0, 1)
    sync_session.expire_all()
    kept = _yk_match(sync_session)
    assert kept.id == owned.id  # the probe joined them, and the row gained YallaKora's id
    assert (kept.competition_stage, kept.kickoff_at) == (stage, kickoff)
    assert _broadcaster(sync_session, kept.id) == "ON Sport"


def test_yallakora_updates_a_fixture_it_created(sync_session: Session, loaded_snapshot) -> None:
    pipeline(sync_session, "yallakora").run([_yk()])

    outcome = pipeline(sync_session, "yallakora").run([_yk(stage="دور الـ 32")])

    assert outcome.updated == 1
    sync_session.expire_all()
    assert _yk_match(sync_session).competition_stage == "دور الـ 32"


# --- FR-022a, R7: YallaKora's id reaches the live poller, so it links only on both teams (B2-R1-1) --


SHARED_NAMES = {"home": "الأهلي الشقيق", "away": "الاتحاد الشقيق"}


def _other_source_row(sync_session: Session, competition: str, kickoff: datetime = KICKOFF, **fields: Any) -> Match:
    names = {"home_team_name": SHARED_NAMES["home"], "away_team_name": SHARED_NAMES["away"]}
    match = Match(
        source="ysscores",
        match_date=DAY,
        kickoff_at=kickoff,
        time_tbd=False,
        competition_name=competition,
        **{**names, **fields},
    )
    sync_session.add(match)
    sync_session.flush()
    return match


def _yk_ids(sync_session: Session) -> list[str]:
    return list(
        sync_session.execute(select(MatchExternalId.external_id).where(MatchExternalId.source == "yallakora")).scalars()
    )


def _match_count(sync_session: Session) -> int:
    return sync_session.execute(select(func.count()).select_from(Match)).scalar_one()


def test_the_same_names_in_two_competitions_are_not_linked_and_the_card_waits(
    sync_session: Session, loaded_snapshot
) -> None:
    """«الأهلي» v «الاتحاد» in Egypt and Saudi Arabia: a wrong link would publish the other's score."""
    egypt = _other_source_row(sync_session, "الدوري المصري الممتاز")
    saudi = _other_source_row(sync_session, "دوري روشن السعودي")
    before = _match_count(sync_session)

    outcome = pipeline(sync_session, "yallakora").run(
        [_yk(**SHARED_NAMES, competition="دوري روشن السعودي", local_broadcaster_eg="ON Sport")]
    )

    assert _yk_ids(sync_session) == []
    assert _broadcaster(sync_session, egypt.id) is None
    assert _broadcaster(sync_session, saudi.id) is None
    assert _match_count(sync_session) == before  # no duplicate either: the names wait (US3)
    assert (outcome.created, outcome.updated, outcome.unchanged, outcome.skipped) == (0, 0, 0, [])
    assert outcome.waiting == [{"ref": "114019", "reason": "unresolved_names_match_a_row"}]
    queued = [row for row in _queued(sync_session) if row["kind"] == "team"]
    assert {row["name"] for row in queued} == set(SHARED_NAMES.values())
    assert {row["context"]["match_id"] for row in queued} == {None}


def test_one_row_with_the_same_names_is_still_not_linked_on_text_alone(sync_session: Session, loaded_snapshot) -> None:
    only = _other_source_row(sync_session, "الدوري المصري الممتاز")

    outcome = pipeline(sync_session, "yallakora").run([_yk(**SHARED_NAMES, local_broadcaster_eg="ON Sport")])

    assert _yk_ids(sync_session) == []
    assert _broadcaster(sync_session, only.id) is None
    assert len(outcome.waiting) == 1


def test_with_a_team_resolved_and_the_other_not_the_card_is_not_linked(sync_session: Session, loaded_snapshot) -> None:
    only = _other_source_row(
        sync_session,
        "الدوري المصري الممتاز",
        home_team_id=team_id(sync_session, "team-zamalek"),
        home_team_name="الزمالك",
        away_team_name="فريق لا يوجد",
    )

    pipeline(sync_session, "yallakora").run([_yk(home="الزمالك", away="فريق لا يوجد", local_broadcaster_eg="ON Sport")])

    assert _yk_ids(sync_session) == []
    assert _broadcaster(sync_session, only.id) is None


def test_a_card_that_waits_is_a_healthy_run_and_seen_again_next_time(sync_session: Session, loaded_snapshot) -> None:
    _other_source_row(sync_session, "الدوري المصري الممتاز")

    first = pipeline(sync_session, "yallakora").run([_yk(**SHARED_NAMES)])
    second = pipeline(sync_session, "yallakora").run([_yk(**SHARED_NAMES)])

    assert first.skipped == second.skipped == []  # `partial` is for items that failed
    assert {row["seen_count"] for row in _queued(sync_session)} == {2}


def test_two_cards_with_the_same_names_and_no_other_source_get_a_row_each(
    sync_session: Session, loaded_snapshot
) -> None:
    """Nobody else holds them, so each keeps its text names (FR-022); one id never lands on the other's row."""
    outcome = pipeline(sync_session, "yallakora").run(
        [
            _yk(**SHARED_NAMES, external_id="1", competition="الدوري المصري الممتاز"),
            _yk(**SHARED_NAMES, external_id="2", competition="دوري روشن السعودي"),
        ]
    )

    assert outcome.created == 2
    assert _yk_match(sync_session, "1").id != _yk_match(sync_session, "2").id


def test_a_mapping_lets_a_waiting_card_link_to_the_one_row_with_those_teams(
    sync_session: Session, loaded_snapshot
) -> None:
    home_id, away_id = team_id(sync_session, "team-zamalek"), team_id(sync_session, "team-city")
    row = _other_source_row(sync_session, "الدوري المصري الممتاز", home_team_id=home_id, away_team_id=away_id)
    pipeline(sync_session, "yallakora").run([_yk(**SHARED_NAMES, local_broadcaster_eg="ON Sport")])
    assert _yk_ids(sync_session) == []
    for alias, target in ((SHARED_NAMES["home"], home_id), (SHARED_NAMES["away"], away_id)):
        sync_session.execute(
            text("INSERT INTO team_aliases (source, alias_norm, team_id) VALUES ('yallakora', ar_normalize(:a), :t)"),
            {"a": alias, "t": target},
        )

    outcome = pipeline(sync_session, "yallakora").run([_yk(**SHARED_NAMES, local_broadcaster_eg="ON Sport")])

    assert outcome.waiting == []
    assert _yk_match(sync_session).id == row.id
    assert _broadcaster(sync_session, row.id) == "ON Sport"


def test_two_candidates_within_45_minutes_are_not_linked_and_no_third_row_appears(
    sync_session: Session, loaded_snapshot
) -> None:
    teams = {"home_team_id": team_id(sync_session, "team-zamalek"), "away_team_id": team_id(sync_session, "team-city")}
    first = _other_source_row(sync_session, "الدوري المصري الممتاز", **teams)
    second = _other_source_row(sync_session, "كأس مصر", kickoff=KICKOFF + timedelta(minutes=30), **teams)
    before = _match_count(sync_session)

    outcome = pipeline(sync_session, "yallakora").run([fixture(external_id="114019", local_broadcaster_eg="ON Sport")])

    assert _yk_ids(sync_session) == []
    assert (_broadcaster(sync_session, first.id), _broadcaster(sync_session, second.id)) == (None, None)
    assert _match_count(sync_session) == before
    assert outcome.waiting == [{"ref": "114019", "reason": "more_than_one_match"}]


def test_yallakora_outside_45_minutes_is_not_linked(sync_session: Session, loaded_snapshot) -> None:
    teams = {"home_team_id": team_id(sync_session, "team-zamalek"), "away_team_id": team_id(sync_session, "team-city")}
    far = _other_source_row(sync_session, "الدوري المصري الممتاز", kickoff=KICKOFF + timedelta(minutes=46), **teams)

    pipeline(sync_session, "yallakora").run([fixture(external_id="114019", local_broadcaster_eg="ON Sport")])

    assert _yk_match(sync_session).id != far.id
    assert _broadcaster(sync_session, far.id) is None


def test_reversed_teams_are_not_linked_because_that_would_swap_the_score(
    sync_session: Session, loaded_snapshot
) -> None:
    reversed_row = _other_source_row(
        sync_session,
        "الدوري المصري الممتاز",
        home_team_id=team_id(sync_session, "team-city"),
        away_team_id=team_id(sync_session, "team-zamalek"),
    )

    pipeline(sync_session, "yallakora").run([fixture(external_id="114019", local_broadcaster_eg="ON Sport")])

    assert _yk_match(sync_session).id != reversed_row.id
    assert _broadcaster(sync_session, reversed_row.id) is None


def test_the_other_importers_still_join_on_the_same_names(sync_session: Session, loaded_snapshot) -> None:
    row = _other_source_row(sync_session, "الدوري المصري الممتاز")

    outcome = pipeline(sync_session, "ysscores").run([fixture(**SHARED_NAMES, external_id="ys-9")])

    assert (outcome.created, outcome.waiting) == (0, [])
    assert _stored(sync_session, "ys-9").id == row.id
