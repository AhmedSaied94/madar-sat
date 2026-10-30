import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madar_sat/core/db/app_database.dart';
import 'package:madar_sat/core/network/generated/models/match_summary.dart';
import 'package:madar_sat/core/network/generated/models/status.dart';

import '../../fixtures/sample_models.dart';

void main() {
  // The fixtures are on Oct 28 in the device's local zone.
  final day = DateTime(2026, 10, 28);
  late AppDatabase database;

  Future<void> store(List<MatchSummary> rows) =>
      database.replaceDay(day, rows, etag: null, fetchedAt: DateTime.utc(2026, 10, 28, 12));

  setUp(() => database = AppDatabase(NativeDatabase.memory()));
  tearDown(() => database.close());

  test('a parsed MatchSummary round-trips through drift unchanged', () async {
    // Built with fromJson, as the client builds it: `match_date` is a date string, which
    // parses to local midnight, never to a UTC instant (M-R2-1, FR-047).
    final fixture = sampleMatchFromJson();

    await store([fixture]);
    final rows = await database.readAll();

    expect(rows, hasLength(1));
    expect(rows.single, fixture);
  });

  test('the calendar date keeps its day in every zone', () async {
    await store([sampleMatchFromJson()]);

    final read = (await database.readAll()).single;

    expect(read.matchDate.year, 2026);
    expect(read.matchDate.month, 10);
    expect(read.matchDate.day, 28);
    expect(read.matchDate.isUtc, isFalse);
  });

  test('an unknown status and a null kickoff round-trip unchanged', () async {
    final fixture = sampleMatchFromJson(status: 'added_on_d2', nullKickoff: true);

    await store([fixture]);
    final read = (await database.readAll()).single;

    expect(read, fixture);
    expect(read.status, Status.$unknown);
    expect(read.kickoffAt, isNull);
    expect(read.timeTbd, isTrue);
  });

  test('instants are read back as UTC', () async {
    await store([sampleMatchFromJson()]);

    final read = (await database.readAll()).single;

    expect(read.kickoffAt!.isUtc, isTrue);
    expect(read.updatedAt.isUtc, isTrue);
  });

  test('replacing the day drops rows that are no longer listed', () async {
    final first = sampleMatch();
    final second = sampleMatch(id: 48214, home: 'الإسماعيلي');
    await store([first, second]);
    expect(await database.readAll(), hasLength(2));

    await store([second]);
    final rows = await database.readAll();
    expect(rows, hasLength(1));
    expect(rows.single.home.name, 'الإسماعيلي');
  });

  test('the day read back is the day replaced', () async {
    await store([sampleMatch(), sampleMatchFromJson(nullKickoff: true).copyWith(id: 9)]);

    final rows = await database.readDay(day);

    expect(rows.map((m) => m.id).toSet(), {48213, 9});
    expect(await database.readDay(DateTime(2026, 10, 29)), isEmpty);
  });
}
