import 'dart:async';
import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madar_sat/core/db/app_database.dart';
import 'package:madar_sat/core/network/api_failure.dart';
import 'package:madar_sat/core/network/swr_repository.dart';

import 'fake_http_adapter.dart';

/// The six behaviours every document reader in `SwrRepository` shares (T080, FR-046): the
/// drift copy first, the conditional GET, a `200`, a `304`, a failure that keeps the copy, and
/// a failure with no copy. Each feature's test file calls this for its own reader, so the
/// readers cannot drift apart.
///
/// Call it from `main()`: it registers its own `setUp`/`tearDown`.
void documentReaderCases<T>({
  required String path,
  required String key,
  required Stream<SwrSnapshot<T>> Function(SwrRepository repository) watch,
  required Object? payload,
  required T Function(Object? json) decode,
}) {
  late AppDatabase database;
  late FakeHttpAdapter http;
  late SwrRepository repository;
  final clock = DateTime(2026, 10, 28, 12);

  setUp(() {
    database = AppDatabase(
      NativeDatabase.memory(),
      now: () => clock,
      offsetAt: (_) => const Duration(hours: 3),
    );
    http = FakeHttpAdapter();
    repository = SwrRepository(dio: fakeDio(http), database: database);
  });
  tearDown(() => database.close());

  Future<void> seed({required Object? body, String? etag = '"v1"', DateTime? at}) => database
      .putDocument(key: key, etag: etag, body: jsonEncode(body), fetchedAt: (at ?? clock).toUtc());

  test('asks the contract path', () async {
    http.enqueueData(payload, etag: '"v1"');

    await watch(repository).toList();

    expect(http.requests.single.path, path);
  });

  test('emits the drift copy first, then sends If-None-Match with its ETag', () async {
    await seed(body: payload);
    http.enqueueNotModified();

    final events = <SwrSnapshot<T>>[];
    var requestsAtFirstEvent = -1;
    await for (final event in watch(repository)) {
      if (events.isEmpty) requestsAtFirstEvent = http.requests.length;
      events.add(event);
    }

    expect(requestsAtFirstEvent, 0, reason: 'the cache is emitted before the network is used');
    expect(events.first.data, isNotNull);
    expect(events, hasLength(2));
    expect(http.ifNoneMatch(0), '"v1"');
  });

  test('with nothing cached it sends no If-None-Match and emits only the answer', () async {
    http.enqueueData(payload, etag: '"v1"');

    final events = await watch(repository).toList();

    expect(http.ifNoneMatch(0), isNull);
    expect(events, hasLength(1));
    expect(events.single.data, isNotNull);
    expect(events.single.failure, isNull);
  });

  test('a 200 replaces the body and its ETag', () async {
    await seed(body: const <String, Object?>{}, etag: '"v1"');
    http.enqueueData(payload, etag: '"v2"');

    final events = await watch(repository).toList();

    expect(events, hasLength(1), reason: 'a body the models cannot read is not emitted');
    expect((await database.documentFor(key))!.etag, '"v2"');
    expect(jsonDecode((await database.documentFor(key))!.body), payload);
  });

  test('a 304 moves fetched_at only and emits the same copy, confirmed', () async {
    await seed(body: payload, at: clock.subtract(const Duration(hours: 2)));
    http.enqueueNotModified(etag: '"v1"');

    final events = await watch(repository).toList();

    final stored = await database.documentFor(key);
    expect(events, hasLength(2));
    expect(events.last.data, isNotNull);
    expect(events.last.fetchedAt, clock.toUtc());
    expect(stored!.fetchedAt, clock.toUtc());
    expect(jsonDecode(stored.body), payload);
  });

  test('a failure with a copy keeps the copy and marks the snapshot', () async {
    await seed(body: payload, at: clock.subtract(const Duration(minutes: 30)));
    http.enqueueOffline();

    final events = await watch(repository).toList();

    expect(events, hasLength(2));
    expect(events.last.data, isNotNull);
    expect(events.last.failure, isA<ApiFailure>());
  });

  test('a failure with no copy reaches the stream as an error', () async {
    http.enqueueOffline();

    await expectLater(watch(repository).toList(), throwsA(isA<ApiFailure>()));
  });

  // The decode of a fresh body is the reader's own; a body it cannot read is refetched. This
  // one proves the shared path calls it at all.
  test('decodes the fresh body with the feature model', () async {
    http.enqueueData(payload, etag: '"v1"');

    final events = await watch(repository).toList();

    expect(events.single.data, decode(payload));
  });
}
