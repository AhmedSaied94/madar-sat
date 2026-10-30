import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madar_sat/core/db/app_database.dart';
import 'package:madar_sat/core/network/generated/models/status.dart';

import '../../fixtures/sample_models.dart';

void main() {
  late AppDatabase database;

  setUp(() => database = AppDatabase(NativeDatabase.memory()));
  tearDown(() => database.close());

  test('a parsed MatchSummary round-trips through drift unchanged', () async {
    // Built with fromJson, as the client builds it: `match_date` is a date string, which
    // parses to local midnight, never to a UTC instant (M-R2-1, FR-047).
    final fixture = sampleMatchFromJson();

    await database.replaceDay([fixture]);
    final rows = await database.readAll();

    expect(rows, hasLength(1));
    expect(rows.single, fixture);
  });

  test('the calendar date keeps its day in every zone', () async {
    await database.replaceDay([sampleMatchFromJson()]);

    final read = (await database.readAll()).single;

    expect(read.matchDate.year, 2026);
    expect(read.matchDate.month, 10);
    expect(read.matchDate.day, 28);
    expect(read.matchDate.isUtc, isFalse);
  });

  test('an unknown status and a null kickoff round-trip unchanged', () async {
    final fixture = sampleMatchFromJson(status: 'added_on_d2', nullKickoff: true);

    await database.replaceDay([fixture]);
    final read = (await database.readAll()).single;

    expect(read, fixture);
    expect(read.status, Status.$unknown);
    expect(read.kickoffAt, isNull);
    expect(read.timeTbd, isTrue);
  });

  test('instants are read back as UTC', () async {
    await database.replaceDay([sampleMatchFromJson()]);

    final read = (await database.readAll()).single;

    expect(read.kickoffAt!.isUtc, isTrue);
    expect(read.updatedAt.isUtc, isTrue);
  });

  test('replacing the day drops rows that are no longer listed', () async {
    final first = sampleMatch();
    final second = sampleMatch(id: 48214, home: 'الإسماعيلي');
    await database.replaceDay([first, second]);
    expect(await database.readAll(), hasLength(2));

    await database.replaceDay([second]);
    final rows = await database.readAll();
    expect(rows, hasLength(1));
    expect(rows.single.home.name, 'الإسماعيلي');
  });
}
