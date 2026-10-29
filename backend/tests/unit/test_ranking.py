from __future__ import annotations

import pytest

from app.domain.ranking import (
    DEFAULT_SATELLITE_SLUGS,
    HeadlineCandidate,
    headline,
    is_preferred_carriage,
    preferred_carriage_key,
)
from app.services.matches import build_broadcast


def c(channel_id, name="ch", access="free", satellite_id=None, satellite_slug=None, sort_order=None, **kw):
    return HeadlineCandidate(
        channel_id=channel_id,
        name=name,
        access=access,
        satellite_id=satellite_id,
        satellite_slug=satellite_slug,
        sort_order=sort_order,
        **kw,
    )


def test_at_most_two_entries():
    result = headline([c(1), c(2), c(3), c(4)])
    assert len(result) == 2


def test_empty():
    assert headline([]) == []


def test_my_satellites_first():
    result = headline(
        [c(1, satellite_id=10), c(2, satellite_id=20, satellite_slug="nilesat-7-0w")],
        my_satellite_ids=(20,),
    )
    assert [x.channel_id for x in result] == [2, 1]


def test_filter_satellites_first():
    result = headline(
        [c(1, satellite_id=10), c(2, satellite_id=20)],
        filter_satellite_ids=(20,),
    )
    assert [x.channel_id for x in result] == [2, 1]


def test_default_satellites_first_when_no_user():
    result = headline([c(1, satellite_id=10), c(2, satellite_id=20, satellite_slug="nilesat-7-0w")])
    assert [x.channel_id for x in result] == [2, 1]


def test_show_in_match_counts_as_preferred():
    result = headline([c(1, satellite_id=10), c(2, satellite_id=20, show_in_match=True)])
    assert [x.channel_id for x in result] == [2, 1]


def test_free_before_encrypted():
    result = headline(
        [c(1, access="encrypted", satellite_slug="nilesat-7-0w"), c(2, access="free", satellite_slug="nilesat-7-0w")]
    )
    assert [x.channel_id for x in result] == [2, 1]


def test_sort_order_before_id():
    result = headline(
        [c(1, satellite_slug="nilesat-7-0w", sort_order=5), c(2, satellite_slug="nilesat-7-0w", sort_order=1)]
    )
    assert [x.channel_id for x in result] == [2, 1]


def test_null_sort_order_is_last():
    result = headline(
        [c(1, satellite_slug="nilesat-7-0w", sort_order=None), c(2, satellite_slug="nilesat-7-0w", sort_order=9)]
    )
    assert [x.channel_id for x in result] == [2, 1]


def test_hidden_and_deleted_never_appear():
    result = headline(
        [
            c(1, satellite_slug="nilesat-7-0w", is_hidden=True),
            c(2, satellite_slug="nilesat-7-0w", deleted=True),
            c(3, satellite_slug="nilesat-7-0w"),
        ]
    )
    assert [x.channel_id for x in result] == [3]


def test_id_breaks_the_last_tie():
    result = headline([c(9, sort_order=1), c(4, sort_order=1), c(7, sort_order=1)])
    assert [x.channel_id for x in result] == [4, 7]


def test_null_sort_order_ranks_after_any_sort_order():
    result = headline([c(1, sort_order=None), c(2, sort_order=500)])
    assert [x.channel_id for x in result] == [2, 1]


def _channel_row(channel_id, kind, satellite_id=None, slug=None, access="free"):
    is_sat = satellite_id is not None
    return {
        "id": channel_id,
        "name": f"ch{channel_id}",
        "kind": kind,
        "access": access,
        "satellite_id": satellite_id,
        "slug": slug,
        "name_ar": "نايل سات" if is_sat else None,
        "name_en": "Nilesat" if is_sat else None,
        "orbital_position": -7.0 if is_sat else None,
        "sort_order": None,
        "show_in_match": False,
        "frequency_mhz": 11843 if is_sat else None,
        "polarization": "H" if is_sat else None,
        "symbol_rate": 27500 if is_sat else None,
    }


def test_platform_headline_entries_have_null_satellite_and_frequency():
    broadcast = build_broadcast(
        [_channel_row(1, "platform"), _channel_row(2, "satellite", satellite_id=5, slug="nilesat-7-0w")], (), ()
    )
    entries = {e.channel_id: e for e in broadcast.headline}
    assert entries[1].satellite is None and entries[1].frequency is None
    assert entries[2].satellite is not None and entries[2].frequency is not None


def test_filter_satellites_rank_first_without_my_satellites():
    result = headline([c(1, satellite_slug="nilesat-7-0w"), c(2, satellite_id=30)], filter_satellite_ids=(30,))
    assert [x.channel_id for x in result] == [2, 1]


@pytest.mark.parametrize(
    ("kind", "slug", "show_in_match", "preferred"),
    [
        ("satellite", "nilesat-7-0w", False, True),
        ("satellite", "badr-26-0e", False, True),
        ("terrestrial", None, True, True),
        ("satellite", "hotbird-13-0e", False, False),
        ("satellite", "hotbird-13-0e", True, True),
        ("platform", "nilesat-7-0w", True, False),  # platforms never appear in broadcasts
    ],
)
def test_preferred_carriage(kind, slug, show_in_match, preferred):
    assert is_preferred_carriage(kind, slug, show_in_match) is preferred


def test_preferred_carriage_order_is_free_then_sort_order_then_id():
    rows = [("encrypted", 1, 1), ("free", None, 2), ("free", 5, 9), ("free", 5, 3)]
    assert sorted(rows, key=lambda r: preferred_carriage_key(*r)) == [
        ("free", 5, 3),
        ("free", 5, 9),
        ("free", None, 2),
        ("encrypted", 1, 1),
    ]


def test_default_slugs_constant():
    assert DEFAULT_SATELLITE_SLUGS == ("nilesat-7-0w", "badr-26-0e")
