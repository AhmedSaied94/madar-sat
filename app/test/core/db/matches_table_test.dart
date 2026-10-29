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
    final read = rows.single;
    expect(read.id, fixture.id);
    expect(read.sport, fixture.sport);
    expect(read.status, fixture.status);
    expect(read.estimated, isTrue);
    expect(read.minute, '67');
    expect(read.score, isNull);
    expect(read.kickoffAt?.toUtc(), fixture.kickoffAt);
    expect(read.matchDate.year, fixture.matchDate.year);
    expect(read.matchDate.month, fixture.matchDate.month);
    expect(read.matchDate.day, fixture.matchDate.day);
    expect(read.updatedAt.toUtc(), fixture.updatedAt);

    expect(read.competition.name, fixture.competition.name);
    expect(read.competition.stage, fixture.competition.stage);
    expect(read.home.name, fixture.home.name);
    expect(read.away.name, fixture.away.name);
    expect(read.broadcast.channelCount, fixture.broadcast.channelCount);
    expect(read.broadcast.hasFree, isTrue);
    expect(read.broadcast.headline, hasLength(1));
    expect(read.broadcast.headline.single.name, 'ON Sport 1');
    expect(read.broadcast.headline.single.frequency?.mhz, 11843);
    expect(read.commentator, isNull);
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
