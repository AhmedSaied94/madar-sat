import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madar_sat/core/db/app_database.dart';
import 'package:madar_sat/core/network/generated/models/status.dart';

import '../../fixtures/sample_models.dart';

void main() {
  late AppDatabase database;

  setUp(() => database = AppDatabase(NativeDatabase.memory()));
  tearDown(() => database.close());

  test('a MatchSummary round-trips through drift unchanged', () async {
    final fixture = sampleMatch(
      status: Status.live,
      score: null,
      minute: '67',
      estimated: true,
    );

    await database.replaceDay([fixture]);
    final rows = await database.readAll();

    expect(rows, hasLength(1));
    expect(rows.single, fixture);
  });

  test('an unknown status and a null kickoff round-trip unchanged', () async {
    final fixture = sampleMatch(status: Status.$unknown, timeTbd: true);

    await database.replaceDay([fixture]);
    final read = (await database.readAll()).single;

    expect(read, fixture);
    expect(read.status, Status.$unknown);
    expect(read.kickoffAt, isNull);
  });

  test('timestamps are read back as UTC', () async {
    await database.replaceDay([sampleMatch()]);

    final read = (await database.readAll()).single;

    expect(read.kickoffAt!.isUtc, isTrue);
    expect(read.matchDate.isUtc, isTrue);
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
