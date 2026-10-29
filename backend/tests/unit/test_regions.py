from __future__ import annotations

import pytest

from app.domain.regions import (
    AFRICA,
    AMERICAS,
    ASIA,
    EUROPE,
    MIDDLE_EAST,
    OCEANIA,
    OTHER,
    REGION_ORDER,
    region_for,
)


def test_brazil_typo_is_americas():
    assert region_for("البرايزل") == AMERICAS


def test_indonesia_typo_is_asia():
    assert region_for("إندونسيا") == ASIA


def test_hong_kong_typo_is_asia():
    assert region_for("هونع كونغ") == ASIA


def test_english_united_states_is_americas():
    assert region_for("United States") == AMERICAS


def test_english_australia_is_oceania():
    assert region_for("Australia") == OCEANIA


def test_region_words_map_to_themselves():
    assert region_for("الشرق الأوسط") == MIDDLE_EAST
    assert region_for("أوروبا") == EUROPE
    assert region_for("أمريكا الجنوبية") == AMERICAS


def test_global_is_other():
    assert region_for("عالمي") == OTHER


def test_empty_is_other():
    assert region_for("") == OTHER
    assert region_for(None) == OTHER


def test_unknown_is_other():
    assert region_for("بلد غير معروف") == OTHER


@pytest.mark.parametrize(
    ("country", "region"),
    [
        ("النسما", EUROPE),  # snapshot typo for النمسا (Austria)
        ("مالديفز", ASIA),  # snapshot spelling without «ال» (Maldives)
        ("المالديفز", ASIA),
    ],
)
def test_snapshot_spellings_are_mapped(country, region):
    assert region_for(country) == region


def test_region_order():
    assert REGION_ORDER == (
        MIDDLE_EAST,
        EUROPE,
        ASIA,
        AMERICAS,
        AFRICA,
        OCEANIA,
        OTHER,
    )
