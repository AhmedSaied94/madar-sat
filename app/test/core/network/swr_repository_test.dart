import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madar_sat/core/db/app_database.dart';
import 'package:madar_sat/core/network/api_failure.dart';
import 'package:madar_sat/core/network/etag_interceptor.dart';
import 'package:madar_sat/core/network/generated/models/match_summary.dart';
import 'package:madar_sat/core/network/swr_repository.dart';

import '../../fixtures/fake_http_adapter.dart';
import '../../fixtures/sample_models.dart';

/// The stale-while-revalidate repository (research R25, FR-046): emit the drift copy, then
/// revalidate with `If-None-Match`. A `200` replaces, a `304` only touches `fetched_at` and
/// re-emits the same copy as just confirmed.
void main() {
  // The device's local day is Oct 28 in a fixed +03 zone, so the test never reads the host.
  final day = DateTime(2026, 10, 28);
  const dayKey = '2026-10-28';
  var clock = DateTime(2026, 10, 28, 12);

  late AppDatabase database;
  late FakeHttpAdapter http;
  late SwrRepository repository;

  final first = sampleMatch(id: 1, kickoff: DateTime.utc(2026, 10, 28, 17));
  final second = sampleMatch(id: 2, kickoff: DateTime.utc(2026, 10, 28, 19), home: 'الإسماعيلي');
  final nextDay = sampleMatch(id: 3, kickoff: DateTime.utc(2026, 10, 29, 17));

  setUp(() {
    clock = DateTime(2026, 10, 28, 12);
    database = AppDatabase(
      NativeDatabase.memory(),
      now: () => clock,
      offsetAt: (_) => const Duration(hours: 3),
    );
    http = FakeHttpAdapter();
    repository = SwrRepository(dio: fakeDio(http), database: database);
  });
  tearDown(() => database.close());

  Future<void> seedDay(List<MatchSummary> rows, {String? etag = '"v1"', DateTime? at}) =>
      database.replaceDay(day, rows, etag: etag, fetchedAt: (at ?? clock).toUtc());

  group('matches by local day', () {
    test('emits the drift copy first, then sends If-None-Match with the stored ETag', () async {
      await seedDay([first]);
      http.enqueueNotModified(etag: '"v1"');

      final events = <SwrSnapshot<List<MatchSummary>>>[];
      var requestsAtFirstEvent = -1;
      await for (final event in repository.watchDay(day)) {
        if (events.isEmpty) requestsAtFirstEvent = http.requests.length;
        events.add(event);
      }

      expect(requestsAtFirstEvent, 0, reason: 'the cache is emitted before the network is used');
      expect(events.first.data!.map((m) => m.id), [1]);
      expect(http.requests, hasLength(1));
      expect(http.ifNoneMatch(0), '"v1"');
    });

    test('asks for the local day as UTC bounds', () async {
      http.enqueueData([], etag: '"v1"');

      await repository.watchDay(day).toList();

      final query = http.requests.single.uri.queryParameters;
      // 00:00 +03 on Oct 28 to 00:00 +03 on Oct 29.
      expect(query['from'], '2026-10-27T21:00:00.000Z');
      expect(query['to'], '2026-10-28T21:00:00.000Z');
      // The day's ETag is stored under the day alone, so the request carries nothing else
      // that could change the answer (D3's own satellites will need their own cache key).
      expect(query.keys.toSet(), {'from', 'to'});
    });

    test('with nothing cached it sends no If-None-Match and emits only the answer', () async {
      http.enqueueData([_json(first)], etag: '"v1"');

      final events = await repository.watchDay(day).toList();

      expect(http.ifNoneMatch(0), isNull);
      expect(events, hasLength(1));
      expect(events.single.data!.map((m) => m.id), [1]);
    });

    test('a 200 replaces the day rows and the ETag, and emits again', () async {
      await seedDay([first]);
      http.enqueueData([_json(second)], etag: '"v2"');

      final events = await repository.watchDay(day).toList();

      expect(events, hasLength(2));
      expect(events[0].data!.map((m) => m.id), [1]);
      expect(events[1].data!.map((m) => m.id), [2]);
      expect((await database.readAll()).map((m) => m.id), [2]);
      expect((await database.windowFor(dayKey))!.etag, '"v2"');
    });

    test('a 200 leaves the other days alone', () async {
      await seedDay([first]);
      await database.replaceDay(
        DateTime(2026, 10, 29),
        [nextDay],
        etag: '"n1"',
        fetchedAt: clock.toUtc(),
      );
      http.enqueueData([_json(second)], etag: '"v2"');

      await repository.watchDay(day).toList();

      expect((await database.readAll()).map((m) => m.id).toSet(), {2, 3});
      expect((await database.windowFor('2026-10-29'))!.etag, '"n1"');
    });

    test('a 200 with a body that does not parse changes neither the rows nor the ETag',
        () async {
      await seedDay([first]);
      http.enqueueData([
        {'id': 9, 'not': 'a match'},
      ], etag: '"v2"');

      final events = await repository.watchDay(day).toList();

      expect((await database.readAll()).map((m) => m.id), [1]);
      expect((await database.windowFor(dayKey))!.etag, '"v1"');
      expect(events.last.data!.map((m) => m.id), [1]);
      expect(events.last.failure, isNotNull);
    });

    test('a 304 only touches fetched_at, and re-emits the same rows as just confirmed', () async {
      await seedDay([first], at: DateTime(2026, 10, 28, 11, 50));
      http.enqueueNotModified(etag: '"v1"');
      clock = DateTime(2026, 10, 28, 12);

      final events = await repository.watchDay(day).toList();

      expect(events, hasLength(2));
      expect(events.first.fetchedAt, DateTime(2026, 10, 28, 11, 50).toUtc());
      expect(events.last.data!.map((m) => m.id), [1]);
      expect(events.last.fetchedAt, DateTime(2026, 10, 28, 12).toUtc(),
          reason: 'a copy the server confirmed must not read as stale');
      expect(events.last.failure, isNull);
      final window = (await database.windowFor(dayKey))!;
      expect(window.etag, '"v1"');
      expect(window.fetchedAt, DateTime(2026, 10, 28, 12).toUtc());
      expect((await database.readAll()).map((m) => m.id), [1]);
    });

    test('offline emits the cache and an error flag, never an empty list over a cached one',
        () async {
      await seedDay([first]);
      http.enqueueOffline();

      final events = await repository.watchDay(day).toList();

      expect(events, hasLength(2));
      expect(events.last.data!.map((m) => m.id), [1]);
      expect(events.last.failure, isA<ApiFailure>().having((f) => f.isOffline, 'isOffline', true));
      expect(events.first.failure, isNull);
    });

    test('a stored day the models can no longer read is refetched in full, never stuck', () async {
      await seedDay([first]);
      await database.customStatement("UPDATE matches SET competition_json = 'not json'");
      http.enqueueData([_json(second)], etag: '"v2"');

      final events = await repository.watchDay(day).toList();

      expect(http.ifNoneMatch(0), isNull, reason: 'its ETag would only confirm rows it cannot read');
      expect(events, hasLength(1));
      expect(events.single.data!.map((m) => m.id), [2]);
      expect((await database.windowFor(dayKey))!.etag, '"v2"');
      expect((await database.readDay(day)).map((m) => m.id), [2]);
    });

    test('an unreadable stored day with no answer is an error, not an empty list', () async {
      await seedDay([first]);
      await database.customStatement("UPDATE matches SET competition_json = 'not json'");
      http.enqueueOffline();

      await expectLater(
        repository.watchDay(day),
        emitsError(isA<ApiFailure>().having((f) => f.isOffline, 'isOffline', true)),
      );
    });

    test('a server error with a cache keeps the cache and carries the error code', () async {
      await seedDay([first]);
      http.enqueueError('internal_error');

      final events = await repository.watchDay(day).toList();

      expect(events.last.data!.map((m) => m.id), [1]);
      expect(events.last.failure, isA<ApiFailure>().having((f) => f.code, 'code', 'internal_error'));
    });

    test('with no cache an error is an error, not an empty list', () async {
      http.enqueueOffline();

      await expectLater(
        repository.watchDay(day),
        emitsError(isA<ApiFailure>().having((f) => f.isOffline, 'isOffline', true)),
      );
    });

    test('an empty day that was fetched is a cache, not "nothing yet"', () async {
      await seedDay(const [], etag: '"empty"');
      http.enqueueNotModified(etag: '"empty"');

      final events = await repository.watchDay(day).toList();

      expect(events.first.data, isEmpty);
      expect(events.first.data, isNotNull);
    });

    test('a 304 for a cache the interceptor already resolved reads as unchanged', () async {
      // An interceptor may turn a 304 into a response holding the body it already has
      // (`EtagInterceptor` does). The repository must read that the same as a raw 304: the
      // request carries the app's interceptors (M-R2-5).
      await seedDay([first]);
      final dio = fakeDio(http)
        ..interceptors.add(
          InterceptorsWrapper(
            onError: (error, handler) => handler.resolve(
              Response<dynamic>(
                requestOptions: error.requestOptions,
                statusCode: 304,
                data: const <String, Object?>{
                  'success': true,
                  'data': <Object?>[],
                  'error': null,
                  'meta': <String, Object?>{},
                },
              ),
            ),
          ),
        );
      http.enqueueNotModified(etag: '"v1"');

      final events = await SwrRepository(dio: dio, database: database).watchDay(day).toList();

      expect(events, hasLength(2), reason: 'the cache, then the cache as confirmed');
      expect(events.last.failure, isNull);
      expect((await database.readAll()).map((m) => m.id), [1]);
    });
  });

  group('freshness', () {
    test('matches and match detail go stale after 5 minutes', () {
      final fetched = DateTime.utc(2026, 10, 28, 12);
      final snapshot = SwrSnapshot<int>(data: 1, fetchedAt: fetched);

      expect(snapshot.isStale(Freshness.matches, now: fetched.add(const Duration(minutes: 5))), isFalse);
      expect(
        snapshot.isStale(Freshness.matches, now: fetched.add(const Duration(minutes: 5, seconds: 1))),
        isTrue,
      );
      expect(Freshness.matches, const Duration(minutes: 5));
      expect(Freshness.matchDetail, const Duration(minutes: 5));
    });

    test('satellites and channels go stale after 24 hours', () {
      final fetched = DateTime.utc(2026, 10, 28, 12);
      final snapshot = SwrSnapshot<int>(data: 1, fetchedAt: fetched);

      expect(snapshot.isStale(Freshness.satellites, now: fetched.add(const Duration(hours: 24))), isFalse);
      expect(
        snapshot.isStale(Freshness.satellites, now: fetched.add(const Duration(hours: 24, seconds: 1))),
        isTrue,
      );
      expect(Freshness.satellites, const Duration(hours: 24));
      expect(Freshness.channels, const Duration(hours: 24));
    });

    test('a copy with no fetch time is stale, and a copy with no data has no age', () {
      expect(const SwrSnapshot<int>(data: 1).isStale(Freshness.matches, now: DateTime.utc(2026)), isTrue);
      expect(const SwrSnapshot<int>().age(DateTime.utc(2026)), isNull);
    });

    group('staleAge, the age a StaleHint shows (FR-046)', () {
      final fetched = DateTime.utc(2026, 10, 28, 12);

      test('is null while the copy is inside its freshness target', () {
        final snapshot = SwrSnapshot<int>(data: 1, fetchedAt: fetched);

        expect(
          snapshot.staleAge(Freshness.matches, now: fetched.add(const Duration(minutes: 5))),
          isNull,
        );
      });

      test('is the copy\'s age once it is past the target', () {
        final snapshot = SwrSnapshot<int>(data: 1, fetchedAt: fetched);

        expect(
          snapshot.staleAge(Freshness.matches, now: fetched.add(const Duration(minutes: 6))),
          const Duration(minutes: 6),
        );
      });

      test('a failed revalidation alone does not make a fresh copy stale', () {
        final snapshot = SwrSnapshot<int>(
          data: 1,
          fetchedAt: fetched,
          failure: const ApiFailure(isOffline: true),
        );

        expect(
          snapshot.staleAge(Freshness.matches, now: fetched.add(const Duration(minutes: 1))),
          isNull,
        );
      });

      test('is null for a copy with no fetch time, since there is no age to say', () {
        expect(const SwrSnapshot<int>(data: 1).staleAge(Freshness.matches, now: fetched), isNull);
      });
    });
  });

  group('documents (match detail, satellites, channels, S4)', () {
    final ids = {2, 5};
    final key = DocumentKeys.matchesBySatellites(day, ids);

    Stream<SwrSnapshot<List<MatchSummary>>> watch() =>
        repository.watchMatchesBySatellites(day: day, satelliteIds: ids);

    test('stores the body and the ETag, then serves them from the cache next time', () async {
      http.enqueueData([_json(first)], etag: '"s1"');
      final firstEvents = await watch().toList();
      expect(firstEvents.single.data!.map((m) => m.id), [1]);

      http.enqueueNotModified(etag: '"s1"');
      final second = <SwrSnapshot<List<MatchSummary>>>[];
      var requestsAtFirstEvent = -1;
      await for (final event in watch()) {
        if (second.isEmpty) requestsAtFirstEvent = http.requests.length;
        second.add(event);
      }

      expect(requestsAtFirstEvent, 1, reason: 'only the first call used the network so far');
      expect(second, hasLength(2), reason: 'the cache, then the cache as confirmed by the 304');
      expect(second.first.data!.map((m) => m.id), [1]);
      expect(second.last.data!.map((m) => m.id), [1]);
      expect(second.last.fetchedAt, clock.toUtc());
      expect(second.last.failure, isNull);
      expect(http.ifNoneMatch(1), '"s1"');
    });

    test('a 200 replaces the body and the ETag and emits again', () async {
      await database.putDocument(
        key: key,
        etag: '"s1"',
        body: jsonEncode([_json(first)]),
        fetchedAt: clock.toUtc(),
      );
      http.enqueueData([_json(second)], etag: '"s2"');

      final events = await watch().toList();

      expect(events.map((e) => e.data!.map((m) => m.id).toList()), [
        [1],
        [2],
      ]);
      expect((await database.documentFor(key))!.etag, '"s2"');
    });

    test('offline keeps the document and flags the error', () async {
      await database.putDocument(
        key: key,
        etag: '"s1"',
        body: jsonEncode([_json(first)]),
        fetchedAt: clock.toUtc(),
      );
      http.enqueueOffline();

      final events = await watch().toList();

      expect(events.last.data!.map((m) => m.id), [1]);
      expect(events.last.failure, isA<ApiFailure>());
    });

    test('S4 isolation: its filtered day leaves S2 rows and the window ETag unchanged', () async {
      await seedDay([first, second]);
      http.enqueueData([_json(second)], etag: '"filtered"');

      final events = await watch().toList();

      expect(events.single.data!.map((m) => m.id), [2]);
      expect((await database.documentFor(key))!.etag, '"filtered"');
      // The unfiltered day is exactly as it was.
      expect((await database.readAll()).map((m) => m.id).toSet(), {1, 2});
      final window = (await database.windowFor(dayKey))!;
      expect(window.etag, '"v1"');
      expect(window.fetchedAt, DateTime(2026, 10, 28, 12).toUtc());
      // The request asked for exactly those satellites, through the generated client.
      final query = http.requests.single.uri.queryParameters;
      expect(query['satellite_ids'], '2,5');
      expect(query['from'], '2026-10-27T21:00:00.000Z');
    });

    test('document keys are stable', () {
      expect(DocumentKeys.satellites, 'satellites');
      expect(DocumentKeys.matchDetail(48213), 'match:48213');
      expect(DocumentKeys.satelliteChannels(2), 'satellite:2:channels');
      expect(
        DocumentKeys.matchesBySatellites(day, {5, 2}),
        'matches:2026-10-28:sat:2,5',
      );
    });
  });

  group("the app's Dio and its interceptors (M-R2-5)", () {
    test("an interceptor added to the app's Dio sees a cached read", () async {
      final seen = <RequestOptions>[];
      final dio = fakeDio(http)
        ..interceptors.add(
          InterceptorsWrapper(
            onRequest: (options, handler) {
              seen.add(options);
              handler.next(options);
            },
          ),
        );
      http.enqueueData([_json(first)], etag: '"v1"');

      await SwrRepository(dio: dio, database: database).watchDay(day).toList();

      expect(seen, hasLength(1), reason: 'the cached read goes through the app\'s Dio');
      expect(seen.single.uri.path, '/v1/matches');
    });

    test("EtagInterceptor's memory never decides what a cached read sends", () async {
      final dio = fakeDio(http)..interceptors.add(EtagInterceptor());
      // A plain call through the app's Dio leaves EtagInterceptor holding an ETag for it.
      http.enqueueData(const [], etag: '"memory"');
      await dio.get<Object?>('/v1/matches');

      http.enqueueData([_json(first)], etag: '"v1"');
      await SwrRepository(dio: dio, database: database).watchDay(day).toList();

      expect(
        http.ifNoneMatch(http.requests.length - 1),
        isNull,
        reason: 'nothing is in drift, so there is nothing to revalidate',
      );
    });
  });

  group('a storage failure after a good 200 (M-R1-15)', () {
    test('a document that cannot be written is still emitted', () async {
      final failing = _FailingWrites(NativeDatabase.memory(), now: () => clock);
      addTearDown(failing.close);
      final repo = SwrRepository(dio: fakeDio(http), database: failing);
      http.enqueueData([_json(first)], etag: '"s1"');

      final events =
          await repo.watchMatchesBySatellites(day: day, satelliteIds: {2}).toList();

      expect(events.single.data!.map((m) => m.id), [1], reason: 'the answer still stands');
      expect(events.single.failure, isNull);
    });

    test('a day that cannot be written is still emitted', () async {
      final failing = _FailingWrites(NativeDatabase.memory(), now: () => clock);
      addTearDown(failing.close);
      final repo = SwrRepository(dio: fakeDio(http), database: failing);
      http.enqueueData([_json(first)], etag: '"s1"');

      final events = await repo.watchDay(day).toList();

      expect(events.single.data!.map((m) => m.id), [1]);
      expect(events.single.failure, isNull);
    });
  });
}

/// A database whose writes fail, as a full disk or a locked file would (M-R1-15).
class _FailingWrites extends AppDatabase {
  _FailingWrites(super.e, {super.now});

  @override
  Future<void> putDocument({
    required String key,
    required String? etag,
    required String body,
    required DateTime fetchedAt,
  }) async =>
      throw StateError('disk full');

  @override
  Future<void> replaceDay(
    DateTime day,
    List<MatchSummary> rows, {
    required String? etag,
    required DateTime fetchedAt,
    String? windowKey,
  }) async =>
      throw StateError('disk full');
}

Map<String, Object?> _json(MatchSummary match) =>
    jsonDecode(jsonEncode(match.toJson())) as Map<String, Object?>;
