from __future__ import annotations

import re

import pytest

from app.api.etag import canonical_query, compute_etag, if_none_match

ETAG_RE = re.compile(r'^W/"[0-9a-f]{16}"$')


def test_format_is_weak_16_hex():
    assert ETAG_RE.match(compute_etag("matches", {}, {}))
    assert ETAG_RE.match(compute_etag("matches", {"a": "1"}, {"x": 2}))


def test_changes_with_route_id():
    a = compute_etag("matches", {}, {"x": 1})
    b = compute_etag("live", {}, {"x": 1})
    assert a != b


def test_changes_with_dataset_version():
    a = compute_etag("matches", {}, {"matches": 1, "channels": 2})
    b = compute_etag("matches", {}, {"matches": 1, "channels": 3})
    assert a != b


def test_query_order_does_not_matter():
    a = compute_etag("matches", {"from": "1", "to": "2"}, {"x": 1})
    b = compute_etag("matches", {"to": "2", "from": "1"}, {"x": 1})
    assert a == b


def test_query_value_changes_etag():
    a = compute_etag("matches", {"q": "a"}, {"x": 1})
    b = compute_etag("matches", {"q": "b"}, {"x": 1})
    assert a != b


def test_integer_list_order_does_not_matter():
    a = compute_etag("matches", {"satellite_ids": "3,1,2"}, {"x": 1})
    b = compute_etag("matches", {"satellite_ids": "1,2,3"}, {"x": 1})
    assert a == b


def test_media_base_url_changes_etag(monkeypatch):
    from app.api import etag as etag_mod

    settings = etag_mod.get_settings()
    monkeypatch.setattr(settings, "media_base_url", "https://a.example")
    a = compute_etag("matches", {}, {"x": 1})
    monkeypatch.setattr(settings, "media_base_url", "https://b.example")
    b = compute_etag("matches", {}, {"x": 1})
    assert a != b


def test_contract_version_changes_etag(monkeypatch):
    from app.api import etag as etag_mod

    settings = etag_mod.get_settings()
    monkeypatch.setattr(settings, "contract_version", "1.0.0")
    a = compute_etag("matches", {}, {"x": 1})
    monkeypatch.setattr(settings, "contract_version", "2.0.0")
    b = compute_etag("matches", {}, {"x": 1})
    assert a != b


def test_time_bucket_is_stable_within_and_changes_across():
    a = compute_etag("matches", {}, {"x": 1}, bucket_s=60, now=1000.0)
    b = compute_etag("matches", {}, {"x": 1}, bucket_s=60, now=1001.0)
    assert a == b  # same bucket
    c = compute_etag("matches", {}, {"x": 1}, bucket_s=60, now=1060.0)
    assert a != c  # next bucket


def test_15s_bucket_is_stable_within_and_changes_across():
    a = compute_etag("live", {}, {"x": 1}, bucket_s=15, now=1005.0)
    b = compute_etag("live", {}, {"x": 1}, bucket_s=15, now=1019.9)
    assert a == b  # 1005 and 1019.9 share the bucket [1005, 1020)
    c = compute_etag("live", {}, {"x": 1}, bucket_s=15, now=1020.0)
    assert a != c
    assert a != compute_etag("live", {}, {"x": 1}, bucket_s=60, now=1005.0)


@pytest.mark.parametrize(
    ("header", "matches"),
    [
        ('W/"0123456789abcdef"', True),
        ('"0123456789abcdef"', True),  # weak comparison ignores W/ (RFC 9110 §13.1.2)
        ('W/"ffffffffffffffff", W/"0123456789abcdef"', True),
        ("*", True),
        ('W/"ffffffffffffffff"', False),
        ("", False),
        (None, False),
        ("garbage", False),
    ],
)
def test_if_none_match(header, matches):
    assert if_none_match(header, 'W/"0123456789abcdef"') is matches


def test_no_bucket_is_time_independent():
    a = compute_etag("satellites", {}, {"x": 1}, now=1000.0)
    b = compute_etag("satellites", {}, {"x": 1}, now=99999.0)
    assert a == b


def test_canonical_query_sorts_keys():
    assert canonical_query({"b": "2", "a": "1"}) == [("a", "1"), ("b", "2")]


def test_two_entities_of_one_detail_route_have_different_tags():
    first = compute_etag("match_detail", {}, {"matches": 1}, path="/v1/matches/1")
    second = compute_etag("match_detail", {}, {"matches": 1}, path="/v1/matches/2")
    same = compute_etag("match_detail", {}, {"matches": 1}, path="/v1/matches/1")

    assert first != second
    assert first == same
