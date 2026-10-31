import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart' show RequestOptions, ResponseBody;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:madar_sat/core/db/app_database.dart';
import 'package:madar_sat/core/format/bidi.dart';
import 'package:madar_sat/core/format/clock.dart';
import 'package:madar_sat/core/format/local_day.dart';
import 'package:madar_sat/core/format/time.dart';
import 'package:madar_sat/core/network/generated/export.dart';
import 'package:madar_sat/core/network/swr_providers.dart';
import 'package:madar_sat/core/network/swr_repository.dart';
import 'package:madar_sat/core/theme/madar_theme.dart';
import 'package:madar_sat/design/components/date_strip.dart';
import 'package:madar_sat/design/components/empty_state.dart';
import 'package:madar_sat/design/components/filter_chip_row.dart';
import 'package:madar_sat/design/components/match_row.dart';
import 'package:madar_sat/design/components/skeleton.dart';
import 'package:madar_sat/design/components/stale_hint.dart';
import 'package:madar_sat/design/components/status_block.dart' show LiveDot;
import 'package:madar_sat/features/live/live_poller.dart';
import 'package:madar_sat/features/matches/presentation/matches_page.dart';
import 'package:madar_sat/l10n/app_localizations.dart';

import '../../fixtures/fake_http_adapter.dart';
import '../../fixtures/sample_models.dart';

const _egypt = CompetitionRef(
  id: 1,
  logo: null,
  name: 'الدوري المصري الممتاز',
  priority: 2,
  stage: 'الجولة 9',
);
const _asia = CompetitionRef(
  id: 2,
  logo: null,
  name: 'دوري أبطال آسيا',
  priority: 1,
  stage: 'الجولة 3',
);
const _italy = CompetitionRef(
  id: 3,
  logo: null,
  name: 'الدوري الإيطالي',
  priority: null,
  stage: 'الجولة 9',
);
const _cup = CompetitionRef(id: 4, logo: null, name: 'كأس مصر', priority: 2, stage: 'دور 16');

const _teams = [
  'الأهلي',
  'الزمالك',
  'بيراميدز',
  'سموحة',
  'الاتحاد',
  'المصري',
  'الإسماعيلي',
  'الجونة',
  'إنبي',
  'الداخلية',
  'المقاصة',
  'طلائع الجيش',
  'بتروجت',
  'غزل المحلة',
  'فاركو',
  'زد',
];

/// Swiping toward the right reveals the NEXT day: in RTL the pages run right to left, so
/// the next page sits on the left.
const _toNextDay = Offset(300, 0);
const _toPreviousDay = Offset(-300, 0);

/// A match on [day] (0 is today, Oct 28) at the local wall-clock [hour]:[minute].
MatchSummary _match(
  int id, {
  CompetitionRef competition = _egypt,
  int dayOffset = 0,
  int hour = 21,
  int minute = 0,
  Status status = Status.scheduled,
  Score? score,
  String? clockMinute,
  bool timeTbd = false,
  bool withChannels = true,
}) =>
    sampleMatch(
      id: id,
      status: status,
      score: score,
      minute: clockMinute,
      timeTbd: timeTbd,
      withChannels: withChannels,
      kickoff: DateTime(2026, 10, 28 + dayOffset, hour, minute).toUtc(),
      home: _teams[(2 * id) % _teams.length],
      away: _teams[(2 * id + 1) % _teams.length],
    ).copyWith(
      competition: competition,
      matchDate: DateTime(2026, 10, 28 + dayOffset),
    );

Score _score(int home, int away) => Score(home: home, away: away, homePen: null, awayPen: null);

LiveState _liveState(
  int id, {
  Status status = Status.live,
  Score? score,
  String? minute,
  bool estimated = false,
}) =>
    LiveState(
      matchId: id,
      status: status,
      statusLabel: null,
      period: null,
      minute: minute,
      score: score,
      estimated: estimated,
      statusUpdatedAt: DateTime.utc(2026, 10, 28, 15),
    );

Map<String, Object?> _json(MatchSummary match) =>
    jsonDecode(jsonEncode(match.toJson())) as Map<String, Object?>;

/// `FakeHttpAdapter` plus a server for `/v1/matches`: scripted responses (an error, an
/// offline failure, a pending answer) are consumed first, in order; every request after
/// them is answered by day, with an ETag, and a matching `If-None-Match` gets a `304`.
class _DayAdapter extends FakeHttpAdapter {
  /// The rows each local day answers with, by `yyyy-MM-dd`; a missing day answers `[]`.
  final Map<String, List<MatchSummary>> days = {};
  int _scripted = 0;

  @override
  void enqueue(FutureOr<ResponseBody> Function(RequestOptions options) respond) {
    _scripted += 1;
    super.enqueue(respond);
  }

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    if (_scripted > 0) {
      _scripted -= 1;
      return super.fetch(options, requestStream, cancelFuture);
    }
    requests.add(options);
    // The window starts at the local midnight of the day it asks for.
    final from = DateTime.parse(options.uri.queryParameters['from']!).toLocal();
    final key = LocalDays.key(DateTime(from.year, from.month, from.day));
    final body = [for (final row in days[key] ?? const <MatchSummary>[]) _json(row)];
    final etag = '"$key:${jsonEncode(body).hashCode}"';
    if (ifNoneMatch(requests.length - 1) == etag) {
      return FakeHttpAdapter.notModified(etag: etag);
    }
    return FakeHttpAdapter.envelope(body, etag: etag);
  }
}

/// A page host: the repository on an in-memory database and a scripted HTTP adapter, a
/// pinned clock (Oct 28, 18:00 local) and a router with the routes the page can open.
class _Harness {
  _Harness() {
    database = AppDatabase(NativeDatabase.memory(), now: () => clock);
    repository = SwrRepository(dio: fakeDio(http), database: database);
    router = GoRouter(
      routes: [
        GoRoute(path: '/', builder: (context, state) => const MatchesPage()),
        for (final path in const [
          '/search',
          '/my-satellites',
          '/satellites',
          '/favorites',
          '/settings',
        ])
          GoRoute(path: path, builder: (context, state) => _Marker(path)),
        GoRoute(
          path: '/match/:id',
          builder: (context, state) => _Marker('/match/${state.pathParameters['id']}'),
        ),
      ],
    );
  }

  DateTime clock = DateTime(2026, 10, 28, 18);
  final _DayAdapter http = _DayAdapter();
  late final AppDatabase database;
  late final SwrRepository repository;
  late final GoRouter router;

  /// What `/v1/live` answers.
  List<LiveState> live = const [];
  int liveCalls = 0;

  /// What the server answers for the day [dayOffset] days from today (Oct 28).
  void serve(List<MatchSummary> rows, {int dayOffset = 0}) =>
      http.days[LocalDays.key(DateTime(2026, 10, 28 + dayOffset))] = rows;

  /// The drift copy of [day], fetched [age] ago.
  Future<void> seed(
    WidgetTester tester,
    List<MatchSummary> rows, {
    DateTime? day,
    Duration age = const Duration(minutes: 1),
    String etag = '"seeded"',
  }) async {
    await tester.runAsync(
      () => database.replaceDay(
        day ?? DateTime(2026, 10, 28),
        rows,
        etag: etag,
        fetchedAt: clock.subtract(age).toUtc(),
      ),
    );
  }

  Future<void> pump(
    WidgetTester tester, {
    bool settle = true,
    Brightness brightness = Brightness.dark,
    double textScale = 1,
  }) async {
    // 360 x 1600 logical pixels: a phone width, tall enough that no row is lazily skipped.
    tester.view
      ..physicalSize = const Size(1080, 4800)
      ..devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    addTearDown(database.close);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          swrRepositoryProvider.overrideWithValue(repository),
          clockProvider.overrideWithValue(() => clock),
          liveFetcherProvider.overrideWithValue(() async {
            liveCalls += 1;
            return live;
          }),
        ],
        child: MaterialApp.router(
          routerConfig: router,
          locale: const Locale('ar'),
          supportedLocales: const [Locale('ar')],
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          theme: brightness == Brightness.dark ? MadarTheme.dark : MadarTheme.light,
          builder: (context, child) => Directionality(
            textDirection: TextDirection.rtl,
            child: MediaQuery(
              data: MediaQuery.of(context).copyWith(
                disableAnimations: true,
                textScaler: TextScaler.linear(textScale),
              ),
              child: child ?? const SizedBox.shrink(),
            ),
          ),
        ),
      ),
    );
    if (settle) {
      await tester.pumpAndSettle();
    } else {
      await tester.pump();
    }
  }
}

class _Marker extends StatelessWidget {
  const _Marker(this.label);

  final String label;

  @override
  Widget build(BuildContext context) => Scaffold(body: Center(child: Text(label)));
}

Finder _row(int id) =>
    find.byWidgetPredicate((w) => w is MatchRow && w.match.id == id, description: 'MatchRow $id');

Finder _inRow(int id, Finder matching) => find.descendant(of: _row(id), matching: matching);

Finder get _strip => find.byType(DateStrip);

Finder get _chips => find.byWidgetPredicate((w) => w is FilterChipRow);

Finder _inStrip(String text) => find.descendant(of: _strip, matching: find.text(text));

List<FilterChipItem<dynamic>> _chipItems(WidgetTester tester) =>
    tester.widget<FilterChipRow<dynamic>>(_chips).items;

double _top(WidgetTester tester, Finder finder) => tester.getTopLeft(finder).dy;

Future<void> _drawTo(WidgetTester tester, Offset by) async {
  await tester.fling(find.byType(PageView), by, 2000);
  await tester.pumpAndSettle();
}

String _allText(WidgetTester tester) {
  final buffer = StringBuffer();
  for (final text in tester.widgetList<Text>(find.byType(Text))) {
    buffer.write(text.data ?? text.textSpan?.toPlainText() ?? '');
    buffer.write(' ');
  }
  return buffer.toString();
}

/// S2 Matches (FR-040, FR-041, FR-046, FR-047, SC-008). Every instant is a local wall-clock
/// time, so the suite holds in any host zone.
void main() {
  late _Harness h;

  setUp(() => h = _Harness());

  group('header and date strip', () {
    testWidgets('show the wordmark and a search action that opens /search', (tester) async {
      h.serve([_match(1)]);
      await h.pump(tester);

      expect(find.text('مدار'), findsOneWidget);

      await tester.tap(find.byTooltip('بحث'));
      await tester.pumpAndSettle();

      expect(find.text('/search'), findsOneWidget);
    });

    testWidgets('the strip runs right to left with «اليوم» on today and the date in words',
        (tester) async {
      h.serve([_match(1)]);
      await h.pump(tester);

      final strip = tester.widget<DateStrip>(_strip);
      expect(strip.selected, DateTime(2026, 10, 28));
      expect(strip.today, DateTime(2026, 10, 28));
      expect(_inStrip('اليوم'), findsOneWidget);
      // Earlier days sit to the right in RTL.
      final x27 = tester.getCenter(_inStrip('27')).dx;
      final x29 = tester.getCenter(_inStrip('29')).dx;
      final x30 = tester.getCenter(_inStrip('30')).dx;
      expect(x27, greaterThan(tester.getCenter(_inStrip('اليوم')).dx));
      expect(x29, lessThan(tester.getCenter(_inStrip('اليوم')).dx));
      expect(x30, lessThan(x29));
      expect(find.text('الأربعاء 28 أكتوبر'), findsOneWidget);
      // No jump-to-today shortcut while today is open.
      expect(find.text('اليوم'), findsOneWidget);
    });

    testWidgets('swiping follows RTL order and the strip follows the page', (tester) async {
      h.serve([_match(1)]);
      h.serve([_match(2, dayOffset: 1)], dayOffset: 1);
      await h.pump(tester);

      await _drawTo(tester, _toNextDay);

      expect(tester.widget<DateStrip>(_strip).selected, DateTime(2026, 10, 29));
      expect(find.text('الخميس 29 أكتوبر'), findsOneWidget);
      expect(_row(2), findsOneWidget);
      expect(_row(1), findsNothing);

      await _drawTo(tester, _toPreviousDay);
      await _drawTo(tester, _toPreviousDay);

      expect(tester.widget<DateStrip>(_strip).selected, DateTime(2026, 10, 27));
      expect(find.text('الثلاثاء 27 أكتوبر'), findsOneWidget);
    });

    testWidgets('coming back after midnight opens the new today, not yesterday', (tester) async {
      h.serve([_match(1)]);
      h.serve([_match(2, dayOffset: 1)], dayOffset: 1);
      await h.pump(tester);
      expect(find.text('الأربعاء 28 أكتوبر'), findsOneWidget);

      // The phone slept through midnight with the app open.
      h.clock = DateTime(2026, 10, 29, 0, 5);
      for (final state in const [
        AppLifecycleState.inactive,
        AppLifecycleState.hidden,
        AppLifecycleState.paused,
      ]) {
        tester.binding.handleAppLifecycleStateChanged(state);
      }
      for (final state in const [
        AppLifecycleState.hidden,
        AppLifecycleState.inactive,
        AppLifecycleState.resumed,
      ]) {
        tester.binding.handleAppLifecycleStateChanged(state);
      }
      await tester.pumpAndSettle();

      expect(find.text('الخميس 29 أكتوبر'), findsOneWidget);
      expect(tester.widget<DateStrip>(_strip).selected, DateTime(2026, 10, 29));
      expect(_row(2), findsOneWidget);
      expect(find.text('اليوم'), findsOneWidget, reason: 'the strip marks the new today');
    });

    testWidgets('tapping a day pages straight to it and «اليوم» jumps back to today',
        (tester) async {
      h.serve([_match(1)]);
      h.serve([_match(3, dayOffset: 2)], dayOffset: 2);
      await h.pump(tester);
      final requestsBefore = h.http.requests.length;

      await tester.tap(_inStrip('30'));
      await tester.pumpAndSettle();

      expect(tester.widget<DateStrip>(_strip).selected, DateTime(2026, 10, 30));
      expect(find.text('الجمعة 30 أكتوبر'), findsOneWidget);
      expect(_row(3), findsOneWidget);
      // The days in between were never built, so they were never requested.
      expect(h.http.requests.length, requestsBefore + 1);

      // Today's button sits beside the date, outside the strip.
      final jump = find.widgetWithText(TextButton, 'اليوم');
      expect(jump, findsOneWidget);
      await tester.tap(jump);
      await tester.pumpAndSettle();

      expect(tester.widget<DateStrip>(_strip).selected, DateTime(2026, 10, 28));
      expect(find.widgetWithText(TextButton, 'اليوم'), findsNothing);
      expect(_row(1), findsOneWidget);
    });

    testWidgets('keep seven cells and slide by one cell to show the last kept day', (tester) async {
      h.serve([_match(1)]);
      h.serve([_match(4, dayOffset: 6)], dayOffset: 6);
      await h.pump(tester);

      expect(_inStrip('27'), findsOneWidget);
      expect(_inStrip('2'), findsOneWidget);
      expect(_inStrip('3'), findsNothing);

      // Nov 2 is the seventh cell; one more swipe reaches Nov 3, the eighth kept day.
      await tester.tap(_inStrip('2'));
      await tester.pumpAndSettle();
      await _drawTo(tester, _toNextDay);

      expect(tester.widget<DateStrip>(_strip).selected, DateTime(2026, 11, 3));
      expect(_inStrip('3'), findsOneWidget);
      expect(_inStrip('27'), findsNothing);
      expect(find.text('الثلاثاء 3 نوفمبر'), findsOneWidget);
    });

    testWidgets('request each day as the UTC window of the device local day', (tester) async {
      h.serve([_match(1)]);
      h.serve([_match(2, dayOffset: 1)], dayOffset: 1);
      await h.pump(tester);

      final today = MadarTime.dayWindow(DateTime(2026, 10, 28));
      var query = h.http.requests.first.uri.queryParameters;
      expect(query['from'], today.from.toIso8601String());
      expect(query['to'], today.to.toIso8601String());
      // The server ranks the channel line itself: S2 never sends my satellites.
      expect(query.containsKey('my_satellite_ids'), isFalse);

      await _drawTo(tester, _toNextDay);

      // A fast fling can overshoot for a frame and build the next neighbour too, so look
      // for tomorrow's window among the requests rather than expecting it to be the last.
      final tomorrow = MadarTime.dayWindow(DateTime(2026, 10, 29));
      final asked = [
        for (final request in h.http.requests)
          (request.uri.queryParameters['from'], request.uri.queryParameters['to']),
      ];
      expect(asked, contains((tomorrow.from.toIso8601String(), tomorrow.to.toIso8601String())));
    });
  });

  group('filter chips', () {
    testWidgets('«الكل» and «مباشر ‹count›» count the live rows of the selected day',
        (tester) async {
      h.live = [_liveState(1, score: _score(1, 0), minute: '34'), _liveState(2)];
      h.serve([
        _match(1, status: Status.live, score: _score(1, 0), clockMinute: '34'),
        _match(2, status: Status.halftime, score: _score(0, 0)),
        _match(3),
        _match(4, status: Status.finished, score: _score(2, 1)),
      ]);
      await h.pump(tester);

      final items = _chipItems(tester);
      expect(items.map((item) => item.label), ['الكل', 'مباشر']);
      expect(items.last.count, 2);
      expect(items.last.isLive, isTrue);
      expect(tester.widget<FilterChipRow<dynamic>>(_chips).selected, items.first.value);
      expect(
        find.descendant(of: _chips, matching: find.text('2')),
        findsOneWidget,
      );
    });

    testWidgets('the live count and its red dot are hidden at zero', (tester) async {
      h.serve([_match(1), _match(2, status: Status.finished, score: _score(2, 1))]);
      await h.pump(tester);

      expect(find.descendant(of: _chips, matching: find.text('مباشر')), findsOneWidget);
      final live = _chipItems(tester).last;
      expect(live.count ?? 0, 0);
      expect(live.isLive, isFalse, reason: 'the dot is for live matches only (US3 scenario 1)');
      expect(find.descendant(of: _chips, matching: find.byType(LiveDot)), findsNothing);
      expect(find.descendant(of: _chips, matching: find.text('0')), findsNothing);
    });

    testWidgets('the live chip draws its dot once something is live', (tester) async {
      h.live = [_liveState(1)];
      h.serve([_match(1, status: Status.live)]);
      await h.pump(tester);

      expect(find.descendant(of: _chips, matching: find.byType(LiveDot)), findsOneWidget);
    });

    testWidgets('the live chip filters the day to live rows and drops groups left empty',
        (tester) async {
      h.live = [_liveState(1)];
      h.serve([
        _match(1, status: Status.live),
        _match(2, competition: _asia, status: Status.finished, score: _score(1, 1)),
        _match(3, competition: _cup, hour: 22),
      ]);
      await h.pump(tester);
      expect(find.text(_asia.name), findsOneWidget);
      expect(find.text(_cup.name), findsOneWidget);

      await tester.tap(find.descendant(of: _chips, matching: find.text('مباشر')));
      await tester.pumpAndSettle();

      expect(_row(1), findsOneWidget);
      expect(_row(2), findsNothing);
      expect(_row(3), findsNothing);
      expect(find.text(_egypt.name), findsOneWidget);
      expect(find.text(_asia.name), findsNothing);
      expect(find.text(_cup.name), findsNothing);

      await tester.tap(find.descendant(of: _chips, matching: find.text('الكل')));
      await tester.pumpAndSettle();

      expect(_row(2), findsOneWidget);
    });
  });

  group('competition groups', () {
    testWidgets('run by admin priority, no priority last, then earliest kickoff', (tester) async {
      h.serve([
        _match(1, competition: _italy, hour: 16),
        _match(2, hour: 21),
        _match(3, hour: 19),
        _match(4, competition: _cup, hour: 18, minute: 30),
        _match(5, competition: _asia, hour: 22),
      ]);
      await h.pump(tester);

      final order = [_asia.name, _cup.name, _egypt.name, _italy.name]
          .map((name) => _top(tester, find.text(name)))
          .toList();
      expect(order, orderedEquals([...order]..sort()));
      expect(order.toSet(), hasLength(4));
      // Rows inside a group follow the kickoff, whatever order the server sent.
      expect(_top(tester, _row(3)), lessThan(_top(tester, _row(2))));
    });

    testWidgets('each group has its competition and stage', (tester) async {
      h.serve([_match(1), _match(2, competition: _asia)]);
      await h.pump(tester);

      expect(find.text(_egypt.name), findsOneWidget);
      expect(find.text('الجولة 9'), findsOneWidget);
      expect(find.text(_asia.name), findsOneWidget);
      expect(find.text('الجولة 3'), findsOneWidget);
    });

    testWidgets('group by the device local day of the kickoff, never by match_date',
        (tester) async {
      // 23:30 tonight carries tomorrow's match_date; it still belongs to today.
      final lateTonight = _match(1, hour: 23, minute: 30)
          .copyWith(matchDate: DateTime(2026, 10, 29));
      h.serve([lateTonight, _match(2)]);
      await h.pump(tester);

      expect(_row(1), findsOneWidget);
      expect(_row(2), findsOneWidget);
    });
  });

  group('rows', () {
    testWidgets('show the channel line: names, +N and «مجانية»; none without channels',
        (tester) async {
      h.serve([_match(1), _match(2, withChannels: false)]);
      await h.pump(tester);

      expect(_inRow(1, find.text('ON Sport 1')), findsOneWidget);
      expect(_inRow(1, find.text('+13')), findsOneWidget);
      expect(_inRow(1, find.text('مجانية')), findsOneWidget);
      expect(_inRow(2, find.text('ON Sport 1')), findsNothing);
      expect(_inRow(2, find.text('مجانية')), findsNothing);
    });

    testWidgets('open /match/:id on tap', (tester) async {
      h.serve([_match(7)]);
      await h.pump(tester);

      await tester.tap(_row(7));
      await tester.pumpAndSettle();

      expect(find.text('/match/7'), findsOneWidget);
    });

    testWidgets('show every StatusBlock variant', (tester) async {
      h.live = [
        _liveState(3, score: _score(2, 1), minute: '67'),
        _liveState(4, estimated: true),
        _liveState(5, status: Status.halftime, score: _score(1, 1)),
      ];
      h.serve([
        _match(1, hour: 21), // scheduled
        _match(2, hour: 18, minute: 25), // imminent: 25 minutes after the pinned 18:00
        _match(3, status: Status.live, score: _score(9, 9), clockMinute: '12'), // live
        _match(4, status: Status.live), // estimated live, from /v1/live
        _match(5, status: Status.live), // halftime, from the live state
        _match(6, hour: 14, status: Status.finished, score: _score(3, 0)),
        _match(7, status: Status.postponed),
        _match(8, timeTbd: true),
      ]);
      await h.pump(tester);

      // scheduled
      expect(_inRow(1, find.text('9:00 م')), findsOneWidget);
      // imminent
      expect(_inRow(2, find.text('بعد 25 د')), findsOneWidget);
      // live, with its score and minute from /v1/live, not the cached ones
      expect(_inRow(3, find.text('67′')), findsOneWidget);
      final liveScore = tester.widget<ScoreParts>(_inRow(3, find.byType(ScoreParts)));
      expect((liveScore.home, liveScore.away), ('2', '1'));
      expect(_inRow(3, find.text('12′')), findsNothing);
      // estimated live, from /v1/live: «مباشر» only, no score and no minute
      expect(_inRow(4, find.text('مباشر')), findsOneWidget);
      expect(_inRow(4, find.byType(ScoreParts)), findsNothing);
      expect(_inRow(4, find.textContaining('′')), findsNothing);
      // halftime
      expect(_inRow(5, find.text('استراحة')), findsOneWidget);
      expect(tester.widget<ScoreParts>(_inRow(5, find.byType(ScoreParts))).home, '1');
      // finished
      expect(_inRow(6, find.text('انتهت')), findsOneWidget);
      final finalScore = tester.widget<ScoreParts>(_inRow(6, find.byType(ScoreParts)));
      expect((finalScore.home, finalScore.away), ('3', '0'));
      // postponed
      expect(_inRow(7, find.text('تأجلت')), findsOneWidget);
      // time unknown
      expect(_inRow(8, find.text('لم يُحدد')), findsOneWidget);
    });

    testWidgets(
        'a cached in-play row is never shown as live: it gets its kickoff time and no count (SC-008)',
        (tester) async {
      // /v1/live answers nothing, so none of the cached states can be confirmed.
      h.serve([
        _match(1, status: Status.live, score: _score(2, 1), clockMinute: '67'),
        _match(2, status: Status.halftime, score: _score(1, 1)),
        _match(3, status: Status.extraTime, score: _score(1, 1), clockMinute: '95'),
        _match(4, status: Status.penalties, score: _score(1, 1)),
      ]);
      await h.pump(tester);
      final semantics = tester.ensureSemantics();
      await tester.pump();

      for (final id in [1, 2, 3, 4]) {
        final row = tester.widget<MatchRow>(_row(id));
        expect(row.match.status, Status.scheduled, reason: 'match $id');
        expect(row.match.score, isNull, reason: 'match $id');
        expect(row.match.minute, isNull, reason: 'match $id');
        expect(_inRow(id, find.text('مباشر')), findsNothing, reason: 'match $id');
        expect(_inRow(id, find.text('9:00 م')), findsOneWidget, reason: 'match $id');
        expect(_inRow(id, find.byType(ScoreParts)), findsNothing, reason: 'match $id');
        expect(_inRow(id, find.textContaining('′')), findsNothing, reason: 'match $id');
        final label = tester.getSemantics(_row(id)).label;
        expect(label, isNot(contains('مباشر')), reason: 'match $id');
        expect(label, isNot(contains('النتيجة')), reason: 'match $id');
        expect(label, isNot(contains('الدقيقة')), reason: 'match $id');
      }
      // None of them counts as live, so the chip stays quiet.
      expect(_chipItems(tester).last.count ?? 0, 0);
      expect(find.descendant(of: _chips, matching: find.byType(LiveDot)), findsNothing);
      semantics.dispose();
    });

    testWidgets('an estimated live state from /v1/live shows no score or minute', (tester) async {
      h.live = [_liveState(1, score: _score(4, 4), minute: '70', estimated: true)];
      h.serve([_match(1, status: Status.live)]);
      await h.pump(tester);

      final row = tester.widget<MatchRow>(_row(1));
      expect(row.match.estimated, isTrue);
      expect(row.match.score, isNull);
      expect(row.match.minute, isNull);
      expect(_inRow(1, find.text('مباشر')), findsOneWidget);
      expect(_inRow(1, find.byType(ScoreParts)), findsNothing);
      expect(_inRow(1, find.text('70′')), findsNothing);
    });

    testWidgets('the light theme at 1.3× draws the same day without an overflow', (tester) async {
      h.serve([
        _match(1, status: Status.live, score: _score(2, 1), clockMinute: '67'),
        _match(2, status: Status.finished, score: _score(3, 0)),
        _match(3, timeTbd: true),
      ]);
      await h.pump(tester, brightness: Brightness.light, textScale: 1.3);

      expect(tester.takeException(), isNull, reason: 'no RenderFlex overflow at 1.3×');
      expect(find.text('مباشر'), findsWidgets);
      expect(find.text('انتهت'), findsOneWidget);
      expect(_row(1), findsOneWidget);
      expect(_row(3), findsOneWidget);
    });

    testWidgets('the dark theme at 1.3× draws the same day without an overflow', (tester) async {
      h.serve([_match(1), _match(2, hour: 23, competition: _asia)]);
      await h.pump(tester, textScale: 1.3);

      expect(tester.takeException(), isNull);
      expect(_row(1), findsOneWidget);
      expect(_row(2), findsOneWidget);
    });

    testWidgets('put the «موعد لم يُحدد» group at the end of the day', (tester) async {
      h.serve([
        _match(1, competition: _italy, hour: 23),
        _match(2, timeTbd: true),
        _match(3, competition: _asia, hour: 22),
      ]);
      await h.pump(tester);

      final group = find.text('موعد لم يُحدد');
      expect(group, findsOneWidget);
      expect(_top(tester, group), greaterThan(_top(tester, _row(1))));
      expect(_top(tester, group), greaterThan(_top(tester, _row(3))));
      expect(_top(tester, _row(2)), greaterThan(_top(tester, group)));
    });

    testWidgets('use Western digits only', (tester) async {
      h.live = [_liveState(3, score: _score(2, 1), minute: '67')];
      h.serve([
        _match(1),
        _match(2, hour: 18, minute: 25),
        _match(3, status: Status.live),
        _match(4, status: Status.finished, score: _score(3, 0)),
        _match(5, timeTbd: true),
      ]);
      await h.pump(tester);

      expect(RegExp('[٠-٩]').hasMatch(_allText(tester)), isFalse);
      expect(_allText(tester), contains('67′'));
    });
  });

  group('states', () {
    testWidgets('show the skeleton while the first load has nothing, then the rows', (tester) async {
      final answer = Completer<ResponseBody>();
      h.http.enqueue((_) => answer.future);
      await h.pump(tester, settle: false);

      expect(find.byType(Skeleton), findsOneWidget);
      expect(find.byType(MatchRow), findsNothing);
      expect(find.byType(EmptyState), findsNothing);

      answer.complete(FakeHttpAdapter.envelope([_json(_match(1))], etag: '"v1"'));
      await tester.pumpAndSettle();

      expect(find.byType(Skeleton), findsNothing);
      expect(_row(1), findsOneWidget);
    });

    testWidgets('show the empty day with a hint to pull', (tester) async {
      h.serve(const []);
      await h.pump(tester);

      expect(find.text('لا توجد مباريات في هذا اليوم'), findsOneWidget);
      expect(find.text('جرّب يوماً آخر أو اسحب القائمة لتحديثها.'), findsOneWidget);
      expect(find.byType(MatchRow), findsNothing);
    });

    testWidgets('show the empty live state, with a way back to every match', (tester) async {
      h.serve([_match(1), _match(2, status: Status.finished, score: _score(1, 0))]);
      await h.pump(tester);

      await tester.tap(find.descendant(of: _chips, matching: find.text('مباشر')));
      await tester.pumpAndSettle();

      expect(find.text('لا توجد مباريات مباشرة الآن'), findsOneWidget);
      expect(find.byType(MatchRow), findsNothing);

      await tester.tap(find.text('عرض كل المباريات'));
      await tester.pumpAndSettle();

      expect(find.text('لا توجد مباريات مباشرة الآن'), findsNothing);
      expect(_row(1), findsOneWidget);
    });

    testWidgets('a failure with nothing cached shows the error copy, never error.message, and retries',
        (tester) async {
      h.http.enqueueError('internal_error');
      h.serve([_match(1)]);
      await h.pump(tester);

      expect(find.text('تعذّر تحميل البيانات'), findsOneWidget);
      expect(find.text('حدث خطأ غير متوقع'), findsOneWidget);
      expect(find.textContaining('for logs only'), findsNothing);
      expect(find.byType(Skeleton), findsNothing);

      await tester.tap(find.text('إعادة المحاولة'));
      await tester.pumpAndSettle();

      expect(find.byType(EmptyState), findsNothing);
      expect(_row(1), findsOneWidget);
    });

    testWidgets('offline with nothing cached says there is no connection, with a retry',
        (tester) async {
      h.http.enqueueOffline();
      h.serve([_match(1)]);
      await h.pump(tester);

      expect(find.text('لا يوجد اتصال بالإنترنت'), findsOneWidget);
      expect(find.text('تأكد من اتصالك بالإنترنت وحاول مرة أخرى'), findsOneWidget);
      expect(find.text('إعادة المحاولة'), findsOneWidget);

      await tester.tap(find.text('إعادة المحاولة'));
      await tester.pumpAndSettle();

      expect(_row(1), findsOneWidget);
    });

    testWidgets('keeps the error on screen, with its retry off, while a retry is out',
        (tester) async {
      h.http.enqueueOffline();
      final answer = Completer<ResponseBody>();
      h.http.enqueue((_) => answer.future);
      await h.pump(tester);

      await tester.tap(find.text('إعادة المحاولة'));
      // Dio starts a request on a zero-length timer, so let a little time pass.
      await tester.pump(const Duration(milliseconds: 10));
      await tester.pump(const Duration(milliseconds: 10));

      expect(h.http.requests, hasLength(2));
      expect(find.byType(Skeleton), findsNothing);
      expect(find.text('لا يوجد اتصال بالإنترنت'), findsOneWidget);
      expect(tester.widget<TextButton>(find.widgetWithText(TextButton, 'إعادة المحاولة')).onPressed,
          isNull);

      h.serve([_match(1)]);
      answer.complete(FakeHttpAdapter.envelope([_json(_match(1))], etag: '"v1"'));
      await tester.pumpAndSettle();

      expect(_row(1), findsOneWidget);
    });

    testWidgets('offline with a cache keeps the data and its age, not an error state',
        (tester) async {
      await h.seed(tester, [_match(1), _match(2, hour: 22)], age: const Duration(hours: 3));
      h.http.enqueueOffline();
      await h.pump(tester);

      expect(_row(1), findsOneWidget);
      expect(_row(2), findsOneWidget);
      expect(find.byType(EmptyState), findsNothing);
      expect(find.text('آخر تحديث منذ 3 س'), findsOneWidget);
    });

    testWidgets('offline with a copy still inside its 5 minutes says nothing about its age',
        (tester) async {
      await h.seed(tester, [_match(1)], age: const Duration(minutes: 2));
      h.http.enqueueOffline();
      await h.pump(tester);

      expect(_row(1), findsOneWidget);
      expect(find.byType(StaleHint), findsNothing);
    });

    testWidgets('StaleHint shows once the day is older than 5 minutes and clears when confirmed',
        (tester) async {
      await h.seed(tester, [_match(1)], age: const Duration(minutes: 7));
      final answer = Completer<ResponseBody>();
      h.http.enqueue((_) => answer.future);
      await h.pump(tester, settle: false);
      await tester.pump();
      await tester.pump();

      // The cached copy is on screen while the revalidation is still out.
      expect(_row(1), findsOneWidget);
      expect(find.byType(StaleHint), findsOneWidget);
      expect(find.text('آخر تحديث منذ 7 د'), findsOneWidget);

      answer.complete(FakeHttpAdapter.notModified(etag: '"v1"'));
      await tester.pumpAndSettle();

      expect(_row(1), findsOneWidget);
      expect(find.byType(StaleHint), findsNothing);
    });

    testWidgets('StaleHint is absent while the day is younger than 5 minutes', (tester) async {
      await h.seed(tester, [_match(1)], age: const Duration(minutes: 4));
      final answer = Completer<ResponseBody>();
      h.http.enqueue((_) => answer.future);
      await h.pump(tester, settle: false);
      await tester.pump();
      await tester.pump();

      expect(_row(1), findsOneWidget);
      expect(find.byType(StaleHint), findsNothing);

      answer.complete(FakeHttpAdapter.notModified(etag: '"seeded"'));
      await tester.pumpAndSettle();
    });

    testWidgets('a fresh 200 shows no StaleHint', (tester) async {
      h.serve([_match(1)]);
      await h.pump(tester);

      expect(find.byType(StaleHint), findsNothing);
    });

    testWidgets('pull to refresh revalidates the day and keeps the rows', (tester) async {
      h.serve([_match(1)]);
      await h.pump(tester);
      final before = h.http.requests.length;

      await tester.fling(find.byType(CustomScrollView), const Offset(0, 400), 1000);
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();

      expect(h.http.requests.length, greaterThan(before));
      expect(h.http.ifNoneMatch(h.http.requests.length - 1), isNotNull);
      expect(_row(1), findsOneWidget);
      expect(find.byType(Skeleton), findsNothing);
    });

    testWidgets('pull to refresh also works on the empty day', (tester) async {
      h.serve(const []);
      await h.pump(tester);
      final before = h.http.requests.length;

      await tester.fling(find.byType(CustomScrollView), const Offset(0, 400), 1000);
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();

      expect(h.http.requests.length, greaterThan(before));
      expect(find.text('لا توجد مباريات في هذا اليوم'), findsOneWidget);
    });
  });

  group('polling (FR-047)', () {
    testWidgets('revalidate the selected day every 60 seconds without a skeleton flash',
        (tester) async {
      h.http.enqueueData([_json(_match(1))], etag: '"v1"');
      final answer = Completer<ResponseBody>();
      h.http.enqueue((_) => answer.future);
      await h.pump(tester);
      expect(h.http.requests, hasLength(1));

      await tester.pump(const Duration(seconds: 60));
      await tester.pump();

      expect(h.http.requests, hasLength(2));
      expect(h.http.ifNoneMatch(1), '"v1"');
      expect(find.byType(Skeleton), findsNothing);
      expect(_row(1), findsOneWidget);

      answer.complete(FakeHttpAdapter.notModified(etag: '"v1"'));
      await tester.pumpAndSettle();
      expect(_row(1), findsOneWidget);
    });

    testWidgets('poll /v1/live while something is live', (tester) async {
      h.serve([_match(1, status: Status.live)]);
      await h.pump(tester);

      expect(h.liveCalls, greaterThanOrEqualTo(1));
    });

    testWidgets('do not poll /v1/live when nothing is live or about to start', (tester) async {
      h.serve([_match(1, hour: 22), _match(2, status: Status.finished, score: _score(1, 0))]);
      await h.pump(tester);

      expect(h.liveCalls, 0);
    });

    testWidgets('poll /v1/live for a match about to start', (tester) async {
      h.serve([_match(1, hour: 18, minute: 30)]);
      await h.pump(tester);

      expect(h.liveCalls, greaterThanOrEqualTo(1));
    });
  });

  group('navigation', () {
    testWidgets('coming back from a match keeps the day and the chip', (tester) async {
      h.live = [_liveState(3)];
      h.serve([_match(1)]);
      h.serve([_match(3, dayOffset: 2, status: Status.live), _match(4, dayOffset: 2)],
          dayOffset: 2);
      await h.pump(tester);

      await tester.tap(_inStrip('30'));
      await tester.pumpAndSettle();
      await tester.tap(find.descendant(of: _chips, matching: find.text('مباشر')));
      await tester.pumpAndSettle();
      expect(_row(4), findsNothing);

      await tester.tap(_row(3));
      await tester.pumpAndSettle();
      expect(find.text('/match/3'), findsOneWidget);

      h.router.pop();
      await tester.pumpAndSettle();

      expect(tester.widget<DateStrip>(_strip).selected, DateTime(2026, 10, 30));
      expect(_row(3), findsOneWidget);
      expect(_row(4), findsNothing);
    });

    testWidgets('the bottom navigation goes to the other root screens', (tester) async {
      h.serve([_match(1)]);
      await h.pump(tester);

      await tester.tap(find.text('أقماري'));
      await tester.pumpAndSettle();

      expect(find.text('/my-satellites'), findsOneWidget);
    });
  });
}
