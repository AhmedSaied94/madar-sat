import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madar_sat/core/format/time.dart';
import 'package:madar_sat/core/theme/madar_theme.dart';
import 'package:madar_sat/design/components/empty_state.dart';
import 'package:madar_sat/design/components/skeleton.dart';
import 'package:madar_sat/features/matches/data/matches_api.dart';
import 'package:madar_sat/features/matches/presentation/matches_page.dart';
import 'package:madar_sat/features/matches/presentation/matches_providers.dart';
import 'package:madar_sat/l10n/app_localizations.dart';

import '../../fixtures/fake_api_client.dart';
import '../../fixtures/sample_models.dart';

Widget _app(MatchesApi api) => ProviderScope(
      overrides: [matchesApiProvider.overrideWithValue(api)],
      child: MaterialApp(
        locale: const Locale('ar'),
        supportedLocales: const [Locale('ar')],
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        theme: MadarTheme.dark,
        builder: (context, child) => Directionality(
          textDirection: TextDirection.rtl,
          child: child ?? const SizedBox.shrink(),
        ),
        home: const MatchesPage(),
      ),
    );

void main() {
  testWidgets('renders teams and the local kickoff in Western digits', (tester) async {
    final kickoff = DateTime(2026, 10, 28, 21, 0);
    final api = MatchesApi(
      FakeApiClient(rows: [sampleMatch(kickoff: kickoff.toUtc())]),
    );

    await tester.pumpWidget(_app(api));
    await tester.pumpAndSettle();

    expect(find.text('الأهلي'), findsOneWidget);
    expect(find.text('الزمالك'), findsOneWidget);
    expect(find.text('9:00 م'), findsOneWidget);
    expect(RegExp('[\u0660-\u0669]').hasMatch(_allText(tester)), isFalse);
  });

  testWidgets('an empty day shows the empty state', (tester) async {
    await tester.pumpWidget(_app(MatchesApi(FakeApiClient())));
    await tester.pumpAndSettle();

    expect(find.text('لا توجد مباريات في هذا اليوم'), findsOneWidget);
  });

  testWidgets('a failure maps error.code to Arabic copy, never error.message', (tester) async {
    final api = MatchesApi(
      FakeApiClient(rows: const [], errorCode: 'match_not_found'),
    );
    await tester.pumpWidget(_app(api));
    await tester.pumpAndSettle();

    expect(find.text('تعذّر تحميل البيانات'), findsOneWidget);
    expect(find.text('لم نجد ما تبحث عنه'), findsOneWidget);
    expect(find.textContaining('for logs only'), findsNothing);
  });

  testWidgets('a failure shows the error state on the first frame, not a skeleton',
      (tester) async {
    final api = MatchesApi(
      FakeApiClient(rows: const [], errorCode: 'internal_error'),
    );
    await tester.pumpWidget(_app(api));
    // One frame: no retry delay may hide the error copy behind the skeleton (FR-048).
    await tester.pump();

    expect(find.byType(EmptyState), findsOneWidget);
    expect(find.byType(Skeleton), findsNothing);
    expect(find.text('حدث خطأ غير متوقع'), findsOneWidget);
  });

  test('the request window is the device local day as UTC bounds', () async {
    final client = FakeApiClient(rows: [sampleMatch()]);
    final api = MatchesApi(client);
    final localNow = DateTime(2026, 10, 28, 15, 30);

    await api.day(now: localNow);

    final expected = MadarTime.dayWindow(localNow);
    expect(client.lastFrom, expected.from);
    expect(client.lastTo, expected.to);
    expect(client.lastFrom!.isUtc, isTrue);
    expect(client.lastTo!.isUtc, isTrue);
  });
}

String _allText(WidgetTester tester) {
  final buffer = StringBuffer();
  for (final text in tester.widgetList<Text>(find.byType(Text))) {
    buffer.write(text.data ?? '');
    buffer.write(' ');
  }
  return buffer.toString();
}
