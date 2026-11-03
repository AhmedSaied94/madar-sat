import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madar_sat/core/db/app_database.dart';
import 'package:madar_sat/core/db/database_provider.dart';
import 'package:madar_sat/core/l10n/error_copy.dart';
import 'package:madar_sat/core/network/dio_provider.dart';
import 'package:madar_sat/core/network/generated/export.dart';
import 'package:madar_sat/features/onboarding/presentation/steps/teams_step.dart';
import 'package:madar_sat/l10n/app_localizations.dart';

import '../../fixtures/fake_http_adapter.dart';
import '../../fixtures/test_app.dart';

/// S1.2 when the team search fails (M-T045-3, bug-bash O7): the error copy for the API's
/// `error.code` and «إعادة المحاولة», which asks the server again, instead of a skeleton
/// that never ends.
void main() {
  late AppDatabase database;
  late FakeHttpAdapter http;

  setUp(() {
    database = AppDatabase(
      NativeDatabase.memory(),
      now: () => DateTime.utc(2026, 11, 1, 9),
    );
    http = FakeHttpAdapter();
  });

  tearDown(() => database.close());

  Future<void> pumpStep(WidgetTester tester) async {
    final dio = Dio(BaseOptions(baseUrl: 'https://api.test'))..httpClientAdapter = http;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(database),
          dioProvider.overrideWithValue(dio),
        ],
        child: testApp(const TeamsStep()),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> search(WidgetTester tester, String query) async {
    await tester.enterText(find.byType(TextField), query);
    await tester.pumpAndSettle();
  }

  TeamSearchItem team(int id, String name) => TeamSearchItem(
        country: 'EG',
        id: id,
        logo: null,
        name: name,
        primaryCompetition: PrimaryCompetitionRef(id: 4, name: 'الدوري المصري الممتاز'),
        sport: Sport.football,
      );

  testWidgets('a failed search shows the copy for its code and a retry button', (
    tester,
  ) async {
    await pumpStep(tester);
    http.enqueueError('internal_error');

    await search(tester, 'الأهلي');

    final l = await AppLocalizations.delegate.load(const Locale('ar'));
    expect(find.text(l.loadFailedTitle), findsOneWidget);
    expect(find.text(l.errorCopy('internal_error')), findsOneWidget);
    expect(find.text(l.retry), findsOneWidget, reason: '«إعادة المحاولة»');
    expect(find.byType(TextField), findsOneWidget, reason: 'the query stays, the search works');
  });

  testWidgets('an offline search is the no-connection state, retry asks again', (
    tester,
  ) async {
    await pumpStep(tester);
    http.enqueueOffline();

    await search(tester, 'الأهلي');

    final l = await AppLocalizations.delegate.load(const Locale('ar'));
    expect(find.text(l.noConnectionTitle), findsOneWidget);
    expect(find.text(l.noConnectionBody), findsOneWidget);

    // The next attempt succeeds, and the results take the error's place.
    http.enqueueData([team(7, 'الزمالك').toJson()]);
    await tester.tap(find.text(l.retry));
    await tester.pumpAndSettle();

    expect(find.text('الزمالك'), findsOneWidget);
    expect(find.text(l.noConnectionTitle), findsNothing);
    expect(http.requests, hasLength(2), reason: 'the retry asked the server again');
  });

  testWidgets('a failure with no copy of the code still offers the retry', (tester) async {
    await pumpStep(tester);
    http.enqueueError('not_implemented');

    await search(tester, 'الأهلي');

    final l = await AppLocalizations.delegate.load(const Locale('ar'));
    expect(find.text(l.errorNotImplemented), findsOneWidget);
    expect(find.text(l.retry), findsOneWidget);
  });
}
