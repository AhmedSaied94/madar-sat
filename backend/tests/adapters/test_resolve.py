"""Entity resolution v0 and the competitionSimilarity port (T059, R17, FR-023)."""

from __future__ import annotations

import pytest
from sqlalchemy import func, select, text
from sqlalchemy.orm import Session

from app.adapters.resolve import (
    STOP_WORDS,
    competition_similarity,
    resolve_channel,
    resolve_competition,
    resolve_team,
    strip_arabic_affixes,
    tokenize,
)
from app.db.models import Competition, CompetitionExternalId, Team, TeamCompetition
from app.domain.arabic import ar_normalize
from tests.adapters.helpers import new_channel


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


def _team_alias(session: Session, source: str, alias: str, team_id: int, competition: str | None = None) -> None:
    session.execute(
        text(
            "INSERT INTO team_aliases (source, alias_norm, competition_norm, team_id) "
            "VALUES (:source, :alias, :competition, :team_id)"
        ),
        {
            "source": source,
            "alias": ar_normalize(alias),
            "competition": ar_normalize(competition) if competition else "",
            "team_id": team_id,
        },
    )


def _team(session: Session, legacy_id: str) -> Team:
    return session.execute(select(Team).where(Team.legacy_id == legacy_id)).scalar_one()


class TestTeamAliases:
    """D5 R8: external id, then the scoped alias, then any-competition alias, then the name rules."""

    def test_an_alias_resolves_a_name_with_no_team(self, sync_session: Session, loaded_snapshot) -> None:
        zamalek = _team(sync_session, "team-zamalek")
        _team_alias(sync_session, "yallakora", "نادي الفارس الأبيض", zamalek.id)

        result = resolve_team(sync_session, external_id=None, name=" نادى الفارس الأبيض ", source="yallakora")

        assert (result.entity_id, result.reason) == (zamalek.id, "alias")

    def test_the_external_id_comes_before_an_alias(self, sync_session: Session, loaded_snapshot) -> None:
        city = _team(sync_session, "team-city")
        _team_alias(sync_session, "ysscores", "اسم", city.id)

        result = resolve_team(sync_session, external_id="990002", name="اسم")

        assert (result.entity_id, result.reason) == (_team(sync_session, "team-zamalek").id, "external_id")

    def test_the_scoped_alias_comes_before_the_unscoped_one(self, sync_session: Session, loaded_snapshot) -> None:
        egypt = _team(sync_session, "team-ahly-eg")
        saudi = _team(sync_session, "team-ahly-sa")
        _team_alias(sync_session, "yallakora", "الأهلي", egypt.id)
        _team_alias(sync_session, "yallakora", "الأهلي", saudi.id, competition="الدوري السعودي")

        scoped = resolve_team(
            sync_session, external_id=None, name="الأهلي", competition_name="الدوري السعودي", source="yallakora"
        )
        other = resolve_team(
            sync_session, external_id=None, name="الأهلي", competition_name="كأس مصر", source="yallakora"
        )

        assert (scoped.entity_id, scoped.reason) == (saudi.id, "alias")
        assert (other.entity_id, other.reason) == (egypt.id, "alias")

    def test_an_alias_comes_before_the_name_rules(self, sync_session: Session, loaded_snapshot) -> None:
        city = _team(sync_session, "team-city")
        _team_alias(sync_session, "yallakora", "الزمالك", city.id)

        result = resolve_team(sync_session, external_id=None, name="الزمالك", source="yallakora")

        assert (result.entity_id, result.reason) == (city.id, "alias")

    def test_an_alias_belongs_to_its_source(self, sync_session: Session, loaded_snapshot) -> None:
        _team_alias(sync_session, "yallakora", "اسم مستعار", _team(sync_session, "team-city").id)

        result = resolve_team(sync_session, external_id=None, name="اسم مستعار", source="ysscores")

        assert (result.entity_id, result.reason) == (None, "unresolved")

    def test_an_alias_scoped_to_another_competition_does_not_apply(
        self, sync_session: Session, loaded_snapshot
    ) -> None:
        _team_alias(sync_session, "yallakora", "اسم مستعار", _team(sync_session, "team-city").id, competition="كأس مصر")

        result = resolve_team(
            sync_session, external_id=None, name="اسم مستعار", competition_name="الدوري السعودي", source="yallakora"
        )

        assert result.entity_id is None


class TestCompetitionAlias:
    def _alias(self, session: Session, source: str, alias: str, competition_id: int) -> None:
        session.execute(
            text("INSERT INTO competition_aliases (source, alias_norm, competition_id) VALUES (:s, :a, :c)"),
            {"s": source, "a": ar_normalize(alias), "c": competition_id},
        )

    def test_an_alias_comes_after_the_id_and_before_the_name(self, sync_session: Session, loaded_snapshot) -> None:
        first = sync_session.execute(select(Competition).where(Competition.legacy_id == "comp-1")).scalar_one()
        second = sync_session.execute(select(Competition).where(Competition.legacy_id == "comp-2")).scalar_one()
        self._alias(sync_session, "yallakora", first.name, second.id)

        result = resolve_competition(sync_session, external_id=None, name=first.name, source="yallakora")

        assert (result.entity_id, result.reason) == (second.id, "alias")
        untouched = resolve_competition(sync_session, external_id=None, name=first.name, source="ysscores")
        assert (untouched.entity_id, untouched.reason) == (first.id, "name")


class TestChannel:
    def _alias(self, session: Session, source: str, alias: str, channel_id: int) -> None:
        session.execute(
            text("INSERT INTO channel_aliases (source, alias_norm, channel_id) VALUES (:s, :a, :c)"),
            {"s": source, "a": ar_normalize(alias), "c": channel_id},
        )

    def test_an_alias_comes_before_the_name(self, sync_session: Session, loaded_snapshot) -> None:
        named = new_channel(sync_session, "قناة باسمها")
        target = new_channel(sync_session, "القناة الهدف")
        self._alias(sync_session, "livesoccertv", "قناة باسمها", target.id)

        result = resolve_channel(sync_session, name="قناة باسمها", source="livesoccertv")

        assert (result.entity_id, result.reason) == (target.id, "alias")
        assert named.id != target.id

    def test_exactly_one_same_name_resolves(self, sync_session: Session, loaded_snapshot) -> None:
        channel = new_channel(sync_session, "قناة وحيدة")

        result = resolve_channel(sync_session, name=" قناة وحيدة ", source="yallakora")

        assert (result.entity_id, result.reason) == (channel.id, "name")

    def test_two_with_the_same_name_do_not_resolve(self, sync_session: Session, loaded_snapshot) -> None:
        new_channel(sync_session, "قناة مكررة", country="Egypt")
        new_channel(sync_session, "قناة مكررة", country="Qatar")

        result = resolve_channel(sync_session, name="قناة مكررة", source="yallakora")

        assert (result.entity_id, result.reason) == (None, "unresolved")

    def test_a_deleted_channel_or_a_placeholder_does_not_resolve(self, sync_session: Session, loaded_snapshot) -> None:
        new_channel(sync_session, "قناة محذوفة", deleted=True)
        hidden = new_channel(sync_session, "قناة مؤقتة")
        hidden.placeholder_source = "livesoccertv"
        sync_session.flush()

        for name in ("قناة محذوفة", "قناة مؤقتة"):
            assert resolve_channel(sync_session, name=name, source="yallakora").entity_id is None

    def test_nothing_with_that_name_keeps_the_text(self, sync_session: Session, loaded_snapshot) -> None:
        result = resolve_channel(sync_session, name="لا توجد", source="yallakora")
        assert (result.entity_id, result.name, result.reason) == (None, "لا توجد", "unresolved")
