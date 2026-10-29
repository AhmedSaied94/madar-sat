import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madar_sat/core/format/time.dart';
import 'package:madar_sat/core/network/generated/models/status.dart';
import 'package:madar_sat/core/theme/madar_theme.dart';
import 'package:madar_sat/design/components/status_block.dart';
import 'package:madar_sat/l10n/app_localizations.dart';

void main() {
  group('kickoff in the device local time', () {
    test('12 h with ص and م markers', () {
      final evening = DateTime(2026, 10, 28, 21, 0);
      final morning = DateTime(2026, 10, 28, 9, 5);
      expect(
        MadarTime.kickoff(evening.toUtc(), am: 'ص', pm: 'م'),
        '9:00 م',
      );
      expect(
        MadarTime.kickoff(morning.toUtc(), am: 'ص', pm: 'م'),
        '9:05 ص',
      );
    });

    test('24 h has no marker', () {
      final evening = DateTime(2026, 10, 28, 21, 0);
      expect(MadarTime.kickoff(evening.toUtc(), use24h: true, am: 'ص', pm: 'م'), '21:00');
      expect(MadarTime.kickoff(null, am: 'ص', pm: 'م'), isNull);
    });

    test('noon and midnight are 12, not 0', () {
      expect(
        MadarTime.kickoff(DateTime(2026, 10, 28, 12).toUtc(), am: 'ص', pm: 'م'),
        '12:00 م',
      );
      expect(
        MadarTime.kickoff(DateTime(2026, 10, 28, 0).toUtc(), am: 'ص', pm: 'م'),
        '12:00 ص',
      );
    });
  });

  group('local-day window', () {
    test('is the local day converted to UTC', () {
      final now = DateTime(2026, 10, 28, 15, 30);
      final window = MadarTime.dayWindow(now);
      final localStart = DateTime(2026, 10, 28);
      final localEnd = DateTime(2026, 10, 29);
      expect(window.from, localStart.toUtc());
      expect(window.to, localEnd.toUtc());
      expect(window.from.isUtc, isTrue);
      expect(window.to.isUtc, isTrue);
    });

    test('a spring-forward day is 23 hours in Cairo', () {
      final window = MadarTime.dayWindow(
        DateTime(2026, 4, 24, 12),
        offsetAt: _cairo2026,
      );
      expect(window.length, const Duration(hours: 23));
    });

    test('a fall-back day is 25 hours in Cairo', () {
      final window = MadarTime.dayWindow(
        DateTime(2026, 10, 29, 12),
        offsetAt: _cairo2026,
      );
      expect(window.length, const Duration(hours: 25));
    });

    test('an ordinary day is 24 hours', () {
      final window = MadarTime.dayWindow(
        DateTime(2026, 7, 1, 12),
        offsetAt: _cairo2026,
      );
      expect(window.length, const Duration(hours: 24));
    });
  });

  group('imminent', () {
    final now = DateTime.utc(2026, 10, 28, 18);
    test('exactly 60 minutes away counts', () {
      expect(MadarTime.isImminent(now.add(const Duration(minutes: 60)), now: now), isTrue);
    });
    test('61 minutes away does not', () {
      expect(MadarTime.isImminent(now.add(const Duration(minutes: 61)), now: now), isFalse);
    });
    test('a kickoff that has passed does not', () {
      expect(MadarTime.isImminent(now.subtract(const Duration(minutes: 1)), now: now), isFalse);
    });
  });

  testWidgets('an unknown kickoff renders لم يُحدد', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('ar'),
        supportedLocales: const [Locale('ar')],
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        theme: MadarTheme.dark,
        home: const Scaffold(
          body: StatusBlock(status: Status.scheduled, timeTbd: true),
        ),
      ),
    );
    expect(find.text('لم يُحدد'), findsOneWidget);
  });
}

Duration _cairo2026(DateTime local) {
  if (local.isBefore(DateTime(2026, 4, 24))) return const Duration(hours: 2);
  if (local.isBefore(DateTime(2026, 10, 30))) return const Duration(hours: 3);
  return const Duration(hours: 2);
}
