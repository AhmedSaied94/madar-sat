from __future__ import annotations

from app.domain.frequency import OUT_OF_DOMAIN, UNPARSEABLE, Frequency, parse_frequency, unique_frequencies


def test_parses_normal_frequency():
    f, reason = parse_frequency("12054 H 27500")
    assert reason is None
    assert f == Frequency(12054, "H", 27500)


def test_parses_cyrillic_en_as_h():
    f, reason = parse_frequency("12604 Н 30000")
    assert reason is None
    assert f == Frequency(12604, "H", 30000)


def test_four_digit_mhz():
    f, reason = parse_frequency("11843 V 27500")
    assert reason is None
    assert f == Frequency(11843, "V", 27500)


def test_l_and_r_polarization():
    assert parse_frequency("11843 L 27500")[0] == Frequency(11843, "L", 27500)
    assert parse_frequency("11843 R 27500")[0] == Frequency(11843, "R", 27500)


def test_missing_symbol_rate_is_unparseable():
    f, reason = parse_frequency("12054 H")
    assert f is None
    assert reason == UNPARSEABLE


def test_uhf_note_is_unparseable():
    f, reason = parse_frequency("UHF 32")
    assert f is None
    assert reason == UNPARSEABLE


def test_junk_is_unparseable():
    f, reason = parse_frequency("كازاخستان")
    assert f is None
    assert reason == UNPARSEABLE


def test_missing_polarization_is_unparseable():
    f, reason = parse_frequency("12166 29700")
    assert f is None
    assert reason == UNPARSEABLE


def test_mhz_out_of_domain_is_rejected():
    f, reason = parse_frequency("1999 H 27500")
    assert f is None
    assert reason == OUT_OF_DOMAIN

    f, reason = parse_frequency("13001 H 27500")
    assert f is None
    assert reason == OUT_OF_DOMAIN


def test_symbol_rate_out_of_domain_is_rejected():
    f, reason = parse_frequency("12054 H 60001")
    assert f is None
    assert reason == OUT_OF_DOMAIN


def test_three_digit_symbol_rate_is_unparseable():
    # The regex requires 4–5 digits, so a 3-digit rate never reaches the domain check.
    f, reason = parse_frequency("12054 H 499")
    assert f is None
    assert reason == UNPARSEABLE


def test_empty_is_unparseable():
    f, reason = parse_frequency("")
    assert f is None
    assert reason == UNPARSEABLE


def test_domain_bounds_are_inclusive():
    # The symbol-rate floor (500) is below the regex's 4-digit minimum, so 1000 is the
    # smallest rate that parses; see test_three_digit_symbol_rate_is_unparseable.
    assert parse_frequency("2000 H 1000") == (Frequency(2000, "H", 1000), None)
    assert parse_frequency("13000 V 60000") == (Frequency(13000, "V", 60000), None)


def test_unique_frequencies_drops_repeats_in_first_seen_order():
    a, b = Frequency(11843, "H", 27500), Frequency(12054, "V", 27500)
    # Cyrillic Н parses to the same tuning as H, so it counts as a repeat too.
    parsed = [parse_frequency(v)[0] for v in ("11843 H 27500", "12054 V 27500", "11843 Н 27500")]
    assert unique_frequencies(f for f in parsed if f is not None) == [a, b]
