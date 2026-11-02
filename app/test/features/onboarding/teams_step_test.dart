import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madar_sat/core/network/dio_provider.dart';
import 'package:madar_sat/core/network/generated/export.dart';
import 'package:madar_sat/features/frequencies/domain/search_normalize.dart';
import 'package:madar_sat/features/teams/data/team_search_provider.dart';
import 'package:madar_sat/features/teams/domain/team_groups.dart';

import '../../fixtures/fake_http_adapter.dart';

/// S1.2's picker (US2 scenario 3): «الاهلي» and «الأهلي» ask the same question, the results
/// group under their competition with the server's popular order kept.
void main() {
  TeamSearchItem team(int id, String name, String competition) => TeamSearchItem(
        country: 'EG',
        id: id,
        logo: null,
        name: name,
        primaryCompetition: PrimaryCompetitionRef(id: competition.hashCode, name: competition),
        sport: Sport.football,
      );

  test('the query is folded the way the server folds it', () {
    expect(normalizeSearch('الأهلي'), normalizeSearch('الاهلي'));
    expect(normalizeSearch('الزمالك '), 'الزمالك');
  });

  test('teams group under their competition, in the order the server sent', () {
    final groups = groupTeams([
      team(1, 'الزمالك', 'الدوري المصري الممتاز'),
      team(2, 'الأهلي', 'الدوري المصري الممتاز'),
      team(3, 'ليفربول', 'الدوري الإنجليزي الممتاز'),
    ]);

    expect(groups.map((group) => group.competition), [
      'الدوري المصري الممتاز',
      'الدوري الإنجليزي الممتاز',
    ]);
    expect(groups.first.teams.map((team) => team.name), ['الزمالك', 'الأهلي']);
  });

  test('both spellings send the same q, and one letter sends nothing', () async {
    final adapter = FakeHttpAdapter();
    final dio = Dio(BaseOptions(baseUrl: 'https://api.madarsat.test'))
      ..httpClientAdapter = adapter;
    final container = ProviderContainer(overrides: [dioProvider.overrideWithValue(dio)]);
    addTearDown(container.dispose);

    adapter.enqueueData(const <Object?>[]);
    await container.read(teamSearchProvider('الأهلي').future);
    adapter.enqueueData(const <Object?>[]);
    await container.read(teamSearchProvider('الاهلي').future);

    expect(adapter.requests, hasLength(2));
    expect(
      adapter.requests[0].uri.queryParameters['q'],
      adapter.requests[1].uri.queryParameters['q'],
    );
    expect(adapter.requests[0].uri.queryParameters['q'], 'الاهلي');

    // Under two letters the picker asks nothing: the queue stays empty and no request goes
    // out (a request would fail loudly).
    expect(await container.read(teamSearchProvider('ا').future), isEmpty);
    expect(adapter.requests, hasLength(2));
  });

  test('a failed search fails loudly instead of drawing an empty list', () async {
    final adapter = FakeHttpAdapter();
    final dio = Dio(BaseOptions(baseUrl: 'https://api.madarsat.test'))
      ..httpClientAdapter = adapter;
    final container = ProviderContainer(overrides: [dioProvider.overrideWithValue(dio)]);
    addTearDown(container.dispose);

    adapter.enqueueError('internal_error');

    await expectLater(
      container.read(teamSearchProvider('الأهلي').future),
      throwsA(isA<Exception>()),
    );
  });
}
