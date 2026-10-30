"""Entity resolution v0 and the competitionSimilarity port (T059, R17, FR-023)."""

from __future__ import annotations

import pytest
from sqlalchemy import func, select
from sqlalchemy.orm import Session

from app.adapters.resolve import (
    STOP_WORDS,
    competition_similarity,
    resolve_competition,
    resolve_team,
    strip_arabic_affixes,
    tokenize,
)
from app.db.models import Competition, CompetitionExternalId, Team, TeamCompetition


class TestThePort:
    """Expected values taken from `../old_app/src/utils/arabicMatch.js` (node, 2026-10-30)."""

    @pytest.mark.parametrize(
        ("text", "expected"),
        [
            ("الدوري المصري الممتاز", ["مصر"]),
            ("الدوري السعودي للمحترفين", ["سعود", "للمحترف"]),
            ("كأس مصر", ["مصر"]),
            ("دوري أبطال أوروبا", ["ابطال", "اوروبا"]),
            ("Premier League", []),
        ],
    )
    def test_tokenize(self, text: str, expected: list[str]) -> None:
        assert tokenize(text) == expected

    @pytest.mark.parametrize(
        ("text", "expected"),
        [("المصرية", "مصرية"), ("الاهلي", "اهل"), ("اتحاد", "اتحاد")],
    )
    def test_strip_arabic_affixes(self, text: str, expected: str) -> None:
        assert strip_arabic_affixes(text) == expected

    def test_the_stop_words_are_the_js_ones(self) -> None:
        assert {"ال", "الدوري", "الممتاز", "كاس", "league", "cup", "premier", "of", "the"} <= STOP_WORDS

    @pytest.mark.parametrize(
        ("league", "candidate", "expected"),
        [
            ("الدوري المصري الممتاز", "الدوري المصري", 1.0),
            ("الدوري المصري الممتاز", "الدوري المصري الممتاز", 1.0),
            ("الدوري المصري الممتاز", "الدوري السعودي للمحترفين", 0.0),
            ("الدوري المصري الممتاز", "كأس مصر", 1.0),  # «مصر» is a prefix of «مصري» in the JS rule
            ("الدوري الإنجليزي الممتاز", "Premier League", 0.0),
            ("دوري أبطال أوروبا", "دوري الأبطال", 1.0),
            ("", "الدوري المصري", 0.0),
            ("الدوري المصري", "", 0.0),
        ],
    )
    def test_competition_similarity(self, league: str, candidate: str, expected: float) -> None:
        assert competition_similarity(league, candidate) == pytest.approx(expected)


class TestCompetition:
    def test_an_external_id_hit_wins(self, sync_session: Session, loaded_snapshot) -> None:
        comp = sync_session.execute(select(Competition).where(Competition.legacy_id == "comp-2")).scalar_one()
        sync_session.add(CompetitionExternalId(source="ysscores", external_id="c-902", competition_id=comp.id))
        sync_session.flush()
        result = resolve_competition(sync_session, external_id="c-902", name="اسم مختلف تماماً", sport="football")
        assert result.entity_id == comp.id
        assert result.reason == "external_id"

    def test_an_exact_normalized_name_matches(self, sync_session: Session, loaded_snapshot) -> None:
        comp = sync_session.execute(select(Competition).where(Competition.legacy_id == "comp-1")).scalar_one()
        for name in ("الدوري المصري الممتاز", "الدورى المصرى الممتاز", "  الدوري   المصري الممتاز "):
            assert resolve_competition(sync_session, external_id=None, name=name).entity_id == comp.id

    def test_anything_else_keeps_the_name_and_gets_no_id(self, sync_session: Session, loaded_snapshot) -> None:
        result = resolve_competition(sync_session, external_id="c-1", name="دوري لا يوجد")
        assert result.entity_id is None
        assert result.reason == "unresolved"


class TestTeam:
    def test_an_external_id_hit_wins(self, sync_session: Session, loaded_snapshot) -> None:
        zamalek = sync_session.execute(select(Team).where(Team.legacy_id == "team-zamalek")).scalar_one()
        result = resolve_team(sync_session, external_id="990002", name="أي اسم", sport="football")
        assert result.entity_id == zamalek.id
        assert result.reason == "external_id"

    def test_exactly_one_same_normalized_name_and_sport(self, sync_session: Session, loaded_snapshot) -> None:
        zamalek = sync_session.execute(select(Team).where(Team.legacy_id == "team-zamalek")).scalar_one()
        result = resolve_team(sync_session, external_id=None, name=" الزمالك ", sport="football")
        assert result.entity_id == zamalek.id
        assert result.reason == "name"

    def test_among_several_the_competition_decides(self, sync_session: Session, loaded_snapshot) -> None:
        eg = sync_session.execute(select(Team).where(Team.legacy_id == "team-ahly-eg")).scalar_one()
        sa = sync_session.execute(select(Team).where(Team.legacy_id == "team-ahly-sa")).scalar_one()
        saudi = Competition(sport="football", name="الدوري السعودي للمحترفين")
        sync_session.add(saudi)
        sync_session.flush()
        sync_session.add(TeamCompetition(team_id=sa.id, competition_id=saudi.id))
        sync_session.flush()

        assert (
            resolve_team(
                sync_session,
                external_id=None,
                name="الأهلي",
                sport="football",
                competition_name="الدوري المصري الممتاز",
            ).entity_id
            == eg.id
        )
        assert (
            resolve_team(
                sync_session,
                external_id=None,
                name="الأهلي",
                sport="football",
                competition_name="الدوري السعودي للمحترفين",
            ).entity_id
            == sa.id
        )

    def test_below_the_threshold_or_tied_stays_unresolved(self, sync_session: Session, loaded_snapshot) -> None:
        result = resolve_team(
            sync_session, external_id=None, name="الأهلي", sport="football", competition_name="دوري أبطال أوروبا"
        )
        assert result.entity_id is None
        assert result.reason == "unresolved"

    def test_a_tie_stays_unresolved(self, sync_session: Session, loaded_snapshot) -> None:
        # Both Ahly rows get the same competition, so the score ties and nothing may be guessed.
        egyptian = sync_session.execute(select(Competition).where(Competition.legacy_id == "comp-1")).scalar_one()
        sa = sync_session.execute(select(Team).where(Team.legacy_id == "team-ahly-sa")).scalar_one()
        sync_session.add(TeamCompetition(team_id=sa.id, competition_id=egyptian.id))
        sync_session.flush()
        result = resolve_team(
            sync_session, external_id=None, name="الأهلي", sport="football", competition_name="الدوري المصري الممتاز"
        )
        assert result.entity_id is None
        assert result.reason == "tie"

    def test_a_team_is_never_created(self, sync_session: Session, loaded_snapshot) -> None:
        before = sync_session.execute(select(func.count()).select_from(Team)).scalar_one()
        resolve_team(sync_session, external_id=None, name="فريق غير موجود", sport="football")
        sync_session.flush()
        assert sync_session.execute(select(func.count()).select_from(Team)).scalar_one() == before

    def test_unresolved_keeps_the_text_name_and_no_id(self, sync_session: Session, loaded_snapshot) -> None:
        result = resolve_team(sync_session, external_id="990999", name="فريق غير موجود", sport="football")
        assert result.entity_id is None
        assert result.name == "فريق غير موجود"
        assert result.reason == "unresolved"
