import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:madar_sat/core/format/digits.dart';
import 'package:madar_sat/core/format/time.dart';
import 'package:madar_sat/core/theme/madar_tokens.dart';

void main() {
  setUp(() => Intl.defaultLocale = 'ar');

  test('grouped and plain integers use Western digits', () {
    expect(MadarDigits.of(1513), '1,513');
    expect(MadarDigits.plain(1513), '1513');
    expect(MadarDigits.two(4), '04');
    expect(MadarDigits.decimal(16, digits: 1), '16.0');
  });

  test('no Arabic-Indic digit reaches a formatted count or time', () {
    final values = [
      MadarDigits.of(1513),
      MadarDigits.plain(0),
      MadarTime.kickoff(
        DateTime(2026, 10, 28, 21).toUtc(),
        am: 'ص',
        pm: 'م',
      )!,
    ];
    for (final value in values) {
      expect(RegExp('[\u0660-\u0669]').hasMatch(value), isFalse, reason: value);
    }
  });

  test('times, scores and frequencies carry tabular figures', () {
    const styles = [MadarText.rowTime, MadarText.rowScore, MadarText.readout];
    for (final style in styles) {
      expect(
        style.fontFeatures,
        contains(const FontFeature.tabularFigures()),
        reason: '${style.fontFamily} ${style.fontSize}',
      );
    }
  });
}
