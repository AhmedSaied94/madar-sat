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
