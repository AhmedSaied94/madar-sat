"""``repair-matches``: folding a copy into the row it copied, and filling teams already decided in A13."""

from __future__ import annotations

import json
from datetime import UTC, datetime, timedelta
from uuid import uuid4

import pytest
from sqlalchemy import delete, func, insert, select, text
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from app import cli
from app.db.models import (
    AuditLog,
    Channel,
    DatasetVersion,
    Device,
    DeviceFollow,
    LiveProblem,
    Match,
    MatchChannel,
    MatchEvent,
    MatchExternalId,
    MatchLiveState,
    MatchSourceReading,
    Satellite,
    Team,
    UnresolvedName,
)
from app.domain.arabic import ar_normalize
from app.services.match_repair import COPIES_FROM, COPIES_UNTIL, RepairRefused, fill_teams, merge_pairs

NOW = datetime(2026, 11, 5, 14, 0, tzinfo=UTC)
KICKOFF = NOW - timedelta(minutes=30)


def _row(session: Session, *, source: str = "ysscores", kickoff: datetime | None = KICKOFF, **values) -> Match:
    fields = {"home_team_name": "الجونة", "away_team_name": "الشرطة", "competition_name": "كأس مصر", **values}
    if source == "yallakora":
        fields.setdefault("created_at", COPIES_FROM + timedelta(minutes=1))
    match = Match(source=source, match_date=KICKOFF.date(), kickoff_at=kickoff, **fields)
    session.add(match)
    session.flush()
    return match


def _team(session: Session, name: str = "فريق") -> Team:
    team = Team(name=name)
    session.add(team)
    session.flush()
    return team


def _pair(session: Session, **copy_values) -> tuple[Match, Match]:
    return _row(session), _row(session, source="yallakora", **copy_values)


def _version(session: Session, name: str) -> int:
    return session.scalar(select(DatasetVersion.version).where(DatasetVersion.name == name))


def _reading(session: Session, match: Match, source: str, read_at: datetime, home_score: int = 1) -> None:
    session.add(
        MatchSourceReading(
            match_id=match.id,
            source=source,
            status="live",
            home_score=home_score,
            away_score=0,
            read_at=read_at,
            changed_at=read_at,
        )
    )
    session.flush()


def test_a_merge_carries_the_result_links_and_events_onto_the_row_that_has_channels(sync_session):
    """Row 870 had the channels and row 1258 the 4–1: fans need both on one match."""
    team = _team(sync_session)
    keep, copy = _pair(
        sync_session,
        away_team_id=team.id,
        status="finished",
        status_source="feed",
        status_label="انتهت",
        home_score=4,
        away_score=1,
        local_broadcaster_eg="ON Sport",
    )
    keep_id, copy_id = keep.id, copy.id
    sync_session.add_all(
        [
            MatchExternalId(source="goal", external_id="g1", match_id=copy_id),
            MatchExternalId(source="yallakora", external_id="y1", match_id=copy_id),
            MatchEvent(match_id=copy_id, side="home", type="goal", minute="9", source="goal", external_id="e1"),
            MatchLiveState(match_id=keep_id),
            MatchLiveState(match_id=copy_id, confirmed_home=4, confirmed_away=1),
        ]
    )
    _reading(sync_session, copy, "goal", NOW, home_score=4)
    versions = (_version(sync_session, "matches"), _version(sync_session, "live"))

    merge_pairs(sync_session, [(keep_id, copy_id)], NOW)[0]

    sync_session.expire_all()
    kept = sync_session.get(Match, keep_id)
    assert sync_session.get(Match, copy_id) is None
    assert (kept.status, kept.status_source, kept.home_score, kept.away_score) == ("finished", "feed", 4, 1)
    assert kept.status_label == "انتهت"
    assert kept.away_team_id == team.id
    assert kept.local_broadcaster_eg == "ON Sport"
    links = sync_session.scalars(select(MatchExternalId.source).where(MatchExternalId.match_id == keep_id)).all()
    assert sorted(links) == ["goal", "yallakora"]
    assert sync_session.scalar(select(MatchEvent.match_id).where(MatchEvent.external_id == "e1")) == keep_id
    assert sync_session.get(MatchLiveState, keep_id).confirmed_home == 4
    assert sync_session.get(MatchLiveState, copy_id) is None
    assert sync_session.get(MatchSourceReading, (keep_id, "goal")).home_score == 4
    assert _version(sync_session, "matches") == versions[0] + 1
    assert _version(sync_session, "live") == versions[1] + 1


def test_a_merge_leaves_an_audit_of_the_row_it_removed(sync_session):
    keep, copy = _pair(sync_session)
    keep_id, copy_id = keep.id, copy.id

    merge_pairs(sync_session, [(keep_id, copy_id)], NOW)[0]

    gone = sync_session.scalar(select(AuditLog).where(AuditLog.entity_id == copy_id, AuditLog.action == "delete"))
    assert gone.entity == "matches"
    assert gone.diff["merged_into"] == keep_id
    assert gone.diff["home_team_name"] == "الجونة"
    kept = sync_session.scalar(select(AuditLog).where(AuditLog.entity_id == keep_id, AuditLog.action == "update"))
    assert kept.diff["merged_from"] == copy_id


def test_an_editors_status_on_the_kept_row_wins(sync_session):
    keep = _row(sync_session, status="live", status_source="manual", home_score=1, away_score=1)
    copy = _row(sync_session, source="yallakora", status="finished", status_source="feed", home_score=4, away_score=1)

    merge_pairs(sync_session, [(keep.id, copy.id)], NOW)[0]

    sync_session.expire_all()
    kept = sync_session.get(Match, keep.id)
    assert (kept.status, kept.status_source, kept.home_score) == ("live", "manual", 1)


def test_a_copy_on_the_clock_changes_no_status(sync_session):
    keep = _row(sync_session, status="live", status_source="feed", home_score=2, away_score=0)
    copy = _row(sync_session, source="yallakora")

    merge_pairs(sync_session, [(keep.id, copy.id)], NOW)[0]

    sync_session.expire_all()
    kept = sync_session.get(Match, keep.id)
    assert (kept.status_source, kept.home_score) == ("feed", 2)


def test_a_team_the_kept_row_already_has_stays_and_the_difference_is_reported(sync_session):
    theirs, ours = _team(sync_session, "أ"), _team(sync_session, "ب")
    keep = _row(sync_session, home_team_id=ours.id)
    copy = _row(sync_session, source="yallakora", home_team_id=theirs.id)
    keep_id = keep.id

    result = merge_pairs(sync_session, [(keep_id, copy.id)], NOW)[0]

    sync_session.expire_all()
    assert sync_session.get(Match, keep_id).home_team_id == ours.id
    assert result.differs == {"home_team_id": [ours.id, theirs.id]}


def test_the_newest_reading_of_a_source_wins(sync_session):
    keep, copy = _pair(sync_session)
    keep_id = keep.id
    _reading(sync_session, keep, "goal", NOW - timedelta(minutes=5), home_score=1)
    _reading(sync_session, copy, "goal", NOW, home_score=2)
    _reading(sync_session, keep, "filgoal", NOW, home_score=3)
    _reading(sync_session, copy, "filgoal", NOW - timedelta(minutes=5), home_score=4)

    merge_pairs(sync_session, [(keep_id, copy.id)], NOW)[0]

    sync_session.expire_all()
    assert sync_session.get(MatchSourceReading, (keep_id, "goal")).home_score == 2
    assert sync_session.get(MatchSourceReading, (keep_id, "filgoal")).home_score == 3


def test_channels_and_follows_move_without_a_clash(sync_session):
    keep, copy = _pair(sync_session)
    keep_id, copy_id = keep.id, copy.id
    satellite = Satellite(slug="sat-repair", name_en="Sat", name_ar="قمر", kind="satellite", orbital_position=7)
    sync_session.add(satellite)
    sync_session.flush()
    shared, only_copy = (
        Channel(
            kind="satellite", name=name, access="free", show_in_match=True, locked_fields=[], satellite_id=satellite.id
        )
        for name in ("أولى", "ثانية")
    )
    device, other = (Device(install_id=uuid4(), token_hash=char * 64, platform="android") for char in ("a", "b"))
    sync_session.add_all([shared, only_copy, device, other])
    sync_session.flush()
    sync_session.add_all(
        [
            MatchChannel(match_id=keep_id, channel_id=shared.id, source="ysscores"),
            MatchChannel(match_id=copy_id, channel_id=shared.id, source="yallakora"),
            MatchChannel(match_id=copy_id, channel_id=only_copy.id, source="yallakora"),
        ]
    )
    sync_session.execute(
        insert(DeviceFollow),
        [
            {"device_id": device.id, "match_id": keep_id},
            {"device_id": device.id, "match_id": copy_id},
            {"device_id": other.id, "match_id": copy_id},
        ],
    )
    sync_session.flush()

    merge_pairs(sync_session, [(keep_id, copy_id)], NOW)[0]

    sync_session.expire_all()
    channels = sync_session.scalars(select(MatchChannel.channel_id).where(MatchChannel.match_id == keep_id)).all()
    assert sorted(channels) == sorted([shared.id, only_copy.id])
    follows = sync_session.scalars(select(DeviceFollow.device_id).where(DeviceFollow.match_id == keep_id)).all()
    assert sorted(follows) == sorted([device.id, other.id])


def test_an_open_problem_about_the_removed_row_closes(sync_session):
    keep, copy = _pair(sync_session)
    key = f"stale:{copy.id}"
    sync_session.add(LiveProblem(key=key, opened_at=NOW - timedelta(minutes=5)))
    sync_session.flush()

    merge_pairs(sync_session, [(keep.id, copy.id)], NOW)[0]

    sync_session.expire_all()
    assert sync_session.get(LiveProblem, key).closed_at == NOW


@pytest.mark.parametrize(
    "copy_values",
    [
        pytest.param({"source": "ysscores"}, id="a row no YallaKora run made"),
        pytest.param({"source": "yallakora", "kickoff": KICKOFF + timedelta(hours=4)}, id="too far apart to be one"),
        pytest.param({"source": "yallakora", "kickoff": None, "time_tbd": True}, id="no kickoff to compare"),
    ],
)
def test_a_pair_that_cannot_be_one_fixture_is_refused(sync_session, copy_values):
    keep = _row(sync_session)
    copy = _row(sync_session, **copy_values)

    with pytest.raises(RepairRefused):
        merge_pairs(sync_session, [(keep.id, copy.id)], NOW)[0]

    assert sync_session.get(Match, copy.id) is not None


@pytest.mark.parametrize(
    "created_at",
    [COPIES_FROM - timedelta(seconds=1), COPIES_UNTIL, COPIES_UNTIL + timedelta(days=30)],
    ids=["before the incident", "right after it", "long after it"],
)
def test_a_row_the_exception_does_not_cover_is_refused(sync_session, created_at):
    """The owner approved removing those copies, not a way to delete matches."""
    keep = _row(sync_session)
    copy = _row(sync_session, source="yallakora", created_at=created_at)

    with pytest.raises(RepairRefused, match="exception"):
        merge_pairs(sync_session, [(keep.id, copy.id)], NOW)


def test_matches_still_cant_be_deleted_after_a_merge(sync_session):
    keep, copy = _pair(sync_session)
    merge_pairs(sync_session, [(keep.id, copy.id)], NOW)

    enabled = sync_session.scalar(text("SELECT tgenabled FROM pg_trigger WHERE tgname = 'matches_forbid_delete'"))
    assert enabled == "O"
    with pytest.raises(IntegrityError, match="never deleted"), sync_session.begin_nested():
        sync_session.execute(delete(Match).where(Match.id == keep.id))


def test_a_merge_gives_up_on_the_lock_rather_than_queue_for_long(sync_session):
    merge_pairs(sync_session, [], NOW)

    assert sync_session.scalar(text("SHOW lock_timeout")) == "10s"


def test_a_missing_or_repeated_row_is_refused(sync_session):
    keep = _row(sync_session)

    with pytest.raises(RepairRefused):
        merge_pairs(sync_session, [(keep.id, keep.id)], NOW)
    with pytest.raises(RepairRefused):
        merge_pairs(sync_session, [(keep.id, keep.id + 999)], NOW)


# ------------------------------------------------------------------------------------------- fill-teams


def _decided(session: Session, name: str, team: Team | None, *, competition="كأس مصر", state="mapped", source="legacy"):
    row = UnresolvedName(
        source=source,
        kind="team",
        name=name,
        name_norm=ar_normalize(name),
        competition_norm=ar_normalize(competition),
        context={},
        seen_count=1,
        first_seen_at=NOW,
        last_seen_at=NOW,
        state=state,
        target_id=team.id if team else None,
    )
    session.add(row)
    session.flush()
    return row


def test_fill_teams_applies_names_already_decided(sync_session):
    team = _team(sync_session)
    match = _row(sync_session, kickoff=NOW + timedelta(hours=1))
    _decided(sync_session, "الشرطة", team)
    before = _version(sync_session, "matches")

    result = fill_teams(sync_session, NOW)

    sync_session.expire_all()
    assert sync_session.get(Match, match.id).away_team_id == team.id
    assert result.filled == [(match.id, "away_team_id", team.id)]
    assert _version(sync_session, "matches") == before + 1
    audit = sync_session.scalar(select(AuditLog).where(AuditLog.entity == "matches", AuditLog.entity_id == match.id))
    assert audit.diff == {"away_team_id": [None, team.id]}


def test_fill_teams_skips_a_name_decided_two_ways_and_says_so(sync_session):
    first, second = _team(sync_session, "أ"), _team(sync_session, "ب")
    match = _row(sync_session, kickoff=NOW + timedelta(hours=1))
    _decided(sync_session, "الشرطة", first, source="legacy")
    _decided(sync_session, "الشرطة", second, source="yallakora")

    result = fill_teams(sync_session, NOW)

    sync_session.expire_all()
    assert sync_session.get(Match, match.id).away_team_id is None
    assert result.filled == []
    assert result.ambiguous == [("الشرطه", "كاس مصر")]


def test_fill_teams_ignores_open_and_ignored_names(sync_session):
    team = _team(sync_session)
    match = _row(sync_session, kickoff=NOW + timedelta(hours=1))
    _decided(sync_session, "الشرطة", team, state="ignored")
    before = _version(sync_session, "matches")

    assert fill_teams(sync_session, NOW).filled == []
    assert sync_session.get(Match, match.id).away_team_id is None
    assert _version(sync_session, "matches") == before


# ------------------------------------------------------------------------------------------------- the CLI


@pytest.fixture
def run_cli(sync_session, monkeypatch, capsys):
    monkeypatch.setattr(
        cli,
        "SyncSession",
        lambda: Session(bind=sync_session.connection(), join_transaction_mode="create_savepoint"),
    )

    def run(*args: str) -> tuple[int, str]:
        code = cli.main(["repair-matches", *args])
        return code, capsys.readouterr().out

    return run


def _pairs_file(tmp_path, *pairs: tuple[int, int]):
    path = tmp_path / "pairs.json"
    path.write_text(json.dumps([{"keep": keep, "drop": drop} for keep, drop in pairs]))
    return str(path)


def _count(session: Session) -> int:
    return session.scalar(select(func.count()).select_from(Match))


def test_a_merge_with_no_apply_changes_nothing_and_says_what_it_would_do(sync_session, run_cli, tmp_path):
    keep, copy = _pair(sync_session)
    copy_id = copy.id
    before = _count(sync_session)

    code, out = run_cli("merge", _pairs_file(tmp_path, (keep.id, copy_id)))

    assert code == 0
    assert "DRY RUN" in out
    assert str(copy_id) in out
    sync_session.expire_all()
    assert _count(sync_session) == before
    assert sync_session.get(Match, copy_id) is not None


def test_a_merge_with_apply_removes_the_copy(sync_session, run_cli, tmp_path):
    keep, copy = _pair(sync_session)
    copy_id = copy.id
    before = _count(sync_session)

    code, out = run_cli("merge", _pairs_file(tmp_path, (keep.id, copy_id)), "--apply")

    assert code == 0
    assert "DRY RUN" not in out
    sync_session.expire_all()
    assert _count(sync_session) == before - 1


def test_one_refused_pair_stops_the_whole_merge(sync_session, run_cli, tmp_path):
    keep, copy = _pair(sync_session)
    other = _row(sync_session)  # not a YallaKora row
    copy_id = copy.id
    before = _count(sync_session)

    code, out = run_cli("merge", _pairs_file(tmp_path, (keep.id, copy_id), (keep.id, other.id)), "--apply")

    assert code == 1
    assert "REFUSED" in out
    sync_session.expire_all()
    assert _count(sync_session) == before
    assert sync_session.get(Match, copy_id) is not None


def _trigger(session: Session) -> str:
    return session.scalar(text("SELECT tgenabled FROM pg_trigger WHERE tgname = 'matches_forbid_delete'"))


def test_the_trigger_is_on_after_a_dry_run_an_apply_and_a_refusal(sync_session, run_cli, tmp_path):
    keep, copy = _pair(sync_session)
    other = _row(sync_session)

    run_cli("merge", _pairs_file(tmp_path, (keep.id, copy.id)))
    assert _trigger(sync_session) == "O"
    run_cli("merge", _pairs_file(tmp_path, (keep.id, other.id)), "--apply")
    assert _trigger(sync_session) == "O"
    run_cli("merge", _pairs_file(tmp_path, (keep.id, copy.id)), "--apply")
    assert _trigger(sync_session) == "O"


def test_fill_teams_with_no_apply_changes_nothing(sync_session, run_cli):
    team = _team(sync_session)
    match = _row(sync_session, kickoff=datetime.now(UTC) + timedelta(hours=1))
    _decided(sync_session, "الشرطة", team)

    code, out = run_cli("fill-teams")

    assert code == 0
    assert "DRY RUN" in out
    assert str(match.id) in out
    sync_session.expire_all()
    assert sync_session.get(Match, match.id).away_team_id is None
