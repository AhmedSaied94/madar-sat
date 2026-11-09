import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:madar_sat/core/db/app_database.dart';
import 'package:madar_sat/core/db/database_provider.dart';
import 'package:madar_sat/core/network/dio_provider.dart';
import 'package:madar_sat/core/platform/install_guide.dart';
import 'package:madar_sat/core/platform/install_guide_provider.dart';
import 'package:madar_sat/core/platform/push_service.dart';
import 'package:madar_sat/core/platform/secure_store.dart';
import 'package:madar_sat/core/settings/app_settings.dart';
import 'package:madar_sat/core/theme/madar_theme.dart';
import 'package:madar_sat/design/components/form_controls.dart';
import 'package:madar_sat/features/settings/presentation/settings_page.dart';
import 'package:madar_sat/l10n/app_localizations.dart';

import '../../fixtures/fake_http_adapter.dart';

class _MemoryStore implements SecureStore {
  final Map<String, String> values = {};

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async => values[key] = value;

  @override
  Future<void> delete(String key) async => values.remove(key);
}

class _FakePush extends NoPushService {
  _FakePush(this.answer, {this.grants = false});

  PushPermissionState answer;
  final bool grants;
  int prompts = 0;

  @override
  bool get canRequestPermission => true;

  @override
  Future<PushPermissionState> permission() async => answer;

  @override
  Future<bool> requestPermission() async {
    prompts++;
    if (grants) answer = PushPermissionState.allowed;
    return grants;
  }
}

class _Guide implements InstallGuide {
  const _Guide({this.needsInstallSteps = false});

  @override
  bool get isWeb => needsInstallSteps;

  @override
  bool get isInstalled => !needsInstallSteps;

  @override
  final bool needsInstallSteps;
}

/// S15 core (US2 scenario 10, contract app-screens): the time zone, the clock format, the
/// theme and the font size are written to drift and read back; deleting the device data asks
/// first, then clears everything and starts the app over.
void main() {
  late AppDatabase database;
  late _MemoryStore store;
  late FakeHttpAdapter http;

  setUp(() {
    database = AppDatabase(NativeDatabase.memory(), now: () => DateTime.utc(2026, 11, 1, 9));
    store = _MemoryStore();
    http = FakeHttpAdapter();
  });

  tearDown(() async {
    await database.close();
  });

  Future<void> scrollTo(WidgetTester tester, String text) async {
    await tester.scrollUntilVisible(
      find.text(text),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(find.text(text));
    await tester.pumpAndSettle();
  }

  Future<void> pump(
    WidgetTester tester, {
    String? section,
    PushService? push,
    InstallGuide guide = const _Guide(),
  }) async {
    // Tall enough to build the whole page, as the group under test is not on one screen.
    tester.view
      ..physicalSize = const Size(360, 2400)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(database),
          secureStoreProvider.overrideWithValue(store),
          // «حذف بيانات جهازي» sends DELETE /v1/devices/me first (M-R1-3).
          dioProvider.overrideWithValue(fakeDio(http)),
          pushServiceProvider.overrideWithValue(push ?? _FakePush(PushPermissionState.allowed)),
          installGuideProvider.overrideWithValue(guide),
        ],
        child: MaterialApp.router(
          locale: const Locale('ar'),
          supportedLocales: const [Locale('ar')],
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          theme: MadarTheme.dark,
          routerConfig: GoRouter(
            initialLocation: '/settings',
            routes: [
              GoRoute(
                path: '/settings',
                builder: (context, state) => SettingsPage(section: section),
              ),
              GoRoute(
                path: '/settings/satellites',
                builder: (context, state) => const SettingsPage(section: 'satellites'),
              ),
              GoRoute(
                path: '/onboarding/welcome',
                builder: (context, state) => const Scaffold(body: Text('onboarding')),
              ),
              GoRoute(path: '/more', builder: (context, state) => const Text('more')),
              GoRoute(path: '/install', builder: (context, state) => const Text('install-steps')),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('the clock format follows the segmented control at once', (tester) async {
    await pump(tester);

    await tester.tap(find.textContaining('24 ساعة'));
    await tester.pumpAndSettle();

    expect(await database.readSetting(SettingsKeys.timeFormat), 'h24');
  });

  testWidgets('the theme and the font size are written', (tester) async {
    await pump(tester);

    await tester.tap(find.text('فاتح'));
    await tester.pumpAndSettle();
    expect(await database.readSetting(SettingsKeys.theme), 'light');

    await tester.tap(find.text('كبير جداً'));
    await tester.pumpAndSettle();
    expect(await database.readSetting(SettingsKeys.fontScale), 'xlarge');
  });

  testWidgets('the time zone sheet offers automatic and every GMT hour', (tester) async {
    await pump(tester);

    await tester.tap(find.text('المنطقة الزمنية'));
    await tester.pumpAndSettle();

    expect(find.text('GMT−12'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('GMT+2'),
      200,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.ensureVisible(find.text('GMT+2'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('GMT+2'));
    await tester.pumpAndSettle();

    expect(await database.readSetting(SettingsKeys.zoneOffsetMinutes), '120');
    expect(find.textContaining('GMT+2'), findsOneWidget);
  });

  testWidgets('my satellites opens S1.3 as a settings section', (tester) async {
    await pump(tester);

    await tester.tap(find.text('اختر أقماري'));
    await tester.pumpAndSettle();

    expect(find.text('اختر الأقمار التي يستقبلها طبقك'), findsOneWidget);
  });

  testWidgets('deleting the device sends DELETE first, then clears drift and storage',
      timeout: const Timeout(Duration(minutes: 2)), (tester) async {
    await database.setFollow(kind: 'team', targetId: 1, on: true);
    await database.writeSetting(SettingsKeys.theme, 'light');
    store.values[SecureKeys.deviceToken] = 'token-1';
    store.values[SecureKeys.pushToken] = 'fcm-1';
    // S15's «أقماري» row reads the catalogue, then the delete is the next call.
    http.enqueueData(const <Object?>[]);
    await pump(tester);
    http.enqueue((_) => ResponseBody.fromString('', 204));

    await scrollTo(tester, 'حذف بيانات جهازي');
    await tester.tap(find.text('حذف بيانات جهازي'));
    await tester.pumpAndSettle();

    expect(find.text('حذف بيانات جهازي؟'), findsOneWidget);
    expect(
      find.text('سنحذف متابعاتك ورمز الإشعارات من الخادم، وسيبدأ التطبيق من جديد.'),
      findsOneWidget,
    );

    await tester.tap(find.text('حذف').last);
    // Bounded pumps: the snackbar's own timer never settles under pumpAndSettle.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    final sent = http.requests.map((request) => '${request.method} ${request.path}').toList();
    final delete = sent.indexOf('DELETE /v1/devices/me');
    expect(delete, isNot(-1), reason: 'the server is told first: $sent');
    expect(sent.where((call) => call == 'DELETE /v1/devices/me'), hasLength(1));
    expect(sent.sublist(delete + 1), isEmpty, reason: 'nothing is sent after the delete');
    expect(await database.readFollows(), isEmpty);
    expect(await database.readSettings(), isEmpty);
    expect(store.values[SecureKeys.deviceToken], isNull);
    expect(store.values[SecureKeys.pushToken], isNull);
    expect(find.text('onboarding'), findsOneWidget);
    expect(find.text('حُذفت بيانات جهازك'), findsOneWidget);

    // Let the snackbar's four seconds pass, so no timer outlives the test's tree. No
    // `pumpAndSettle`: the satellites skeleton is a repeating animation.
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('a failed delete keeps the device data and says why',
      timeout: const Timeout(Duration(minutes: 2)), (tester) async {
    await database.setFollow(kind: 'team', targetId: 1, on: true);
    store.values[SecureKeys.deviceToken] = 'token-1';
    http.enqueueData(const <Object?>[]);
    await pump(tester);
    http.enqueueError('internal_error', status: 500);

    await scrollTo(tester, 'حذف بيانات جهازي');
    await tester.tap(find.text('حذف بيانات جهازي'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('حذف').last);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect((await database.readFollows()).length, 1, reason: 'nothing is wiped on a failure');
    expect(store.values[SecureKeys.deviceToken], 'token-1');
    expect(find.text('حدث خطأ غير متوقع'), findsOneWidget);
    expect(find.text('onboarding'), findsNothing);

    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('cancelling the dialog keeps everything', (tester) async {
    await database.setFollow(kind: 'team', targetId: 1, on: true);
    await pump(tester);

    await scrollTo(tester, 'حذف بيانات جهازي');
    await tester.tap(find.text('حذف بيانات جهازي'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('إلغاء'));
    await tester.pumpAndSettle();

    expect((await database.readFollows()).length, 1);
  });

  testWidgets('reopening the onboarding steps never resets the flag', (tester) async {
    await database.writeSetting(SettingsKeys.onboardingDone, 'true');
    await pump(tester);

    await scrollTo(tester, 'إعادة خطوات البداية');
    await tester.tap(find.text('إعادة خطوات البداية'));
    await tester.pumpAndSettle();

    expect(find.text('onboarding'), findsOneWidget);
    expect(await database.readSetting(SettingsKeys.onboardingDone), 'true');
  });

  group('the notification group (FR-063)', () {
    /// The switch on the row called [label].
    MadarSwitch switchOf(WidgetTester tester, String label) => tester.widget<MadarSwitch>(
          find.byWidgetPredicate((widget) => widget is MadarSwitch && widget.label == label),
        );

    testWidgets('sits before satellites, with every row at its default', (tester) async {
      await pump(tester);

      expect(
        tester.getTopLeft(find.text('الإشعارات')).dy,
        lessThan(tester.getTopLeft(find.text('أقماري')).dy),
      );
      const defaults = {
        'السماح بالإشعارات': true,
        'تذكير قبل المباراة': true,
        'بداية المباراة': false,
        'الأهداف': true,
        'النتيجة النهائية': true,
        'تحديث القنوات': true,
        'تغيير التردد': true,
        'إعلانات التطبيق': true,
      };
      for (final row in defaults.entries) {
        await scrollTo(tester, row.key);
        expect(switchOf(tester, row.key).value, row.value, reason: row.key);
      }
      // The lead-time control waits for D8: `lead_min` isn't honoured until then.
      expect(find.text('التذكير الافتراضي'), findsNothing);
    });

    testWidgets('a type switch is stored and read back', (tester) async {
      await pump(tester);
      await scrollTo(tester, 'بداية المباراة');

      await tester.tap(find.text('بداية المباراة'));
      await tester.pumpAndSettle();
      expect(switchOf(tester, 'بداية المباراة').value, isTrue);

      await pump(tester);
      await scrollTo(tester, 'بداية المباراة');
      expect(switchOf(tester, 'بداية المباراة').value, isTrue);
      expect(await database.readSetting(SettingsKeys.notificationPrefs), isNotNull);
    });

    testWidgets('master off dims the types and keeps their values', (tester) async {
      await pump(tester);
      await scrollTo(tester, 'الأهداف');
      await tester.tap(find.text('الأهداف'));
      await tester.pumpAndSettle();
      expect(switchOf(tester, 'الأهداف').value, isFalse);

      await tester.tap(find.text('السماح بالإشعارات'));
      await tester.pumpAndSettle();

      expect(switchOf(tester, 'السماح بالإشعارات').value, isFalse);
      expect(switchOf(tester, 'الأهداف').enabled, isFalse);
      expect(switchOf(tester, 'النتيجة النهائية').enabled, isFalse);
      expect(switchOf(tester, 'النتيجة النهائية').value, isTrue);

      await tester.tap(find.text('السماح بالإشعارات'));
      await tester.pumpAndSettle();
      expect(switchOf(tester, 'الأهداف').enabled, isTrue);
      expect(switchOf(tester, 'الأهداف').value, isFalse);
      expect(switchOf(tester, 'النتيجة النهائية').value, isTrue);
    });

    group('the platform state', () {
      testWidgets('allowed says so', (tester) async {
        await pump(tester);

        expect(find.text('مسموح على هذا الجهاز'), findsOneWidget);
        expect(find.text('الإشعارات متوقفة لهذا التطبيق'), findsNothing);
      });

      testWidgets('denied shows the steps, and «تفعيل» asks again', (tester) async {
        final push = _FakePush(PushPermissionState.denied);
        await pump(tester, push: push);

        expect(find.text('الإشعارات متوقفة لهذا التطبيق'), findsOneWidget);
        expect(
          find.text('لن تصلك التنبيهات حتى تسمح بها من إعدادات الجهاز.'),
          findsOneWidget,
        );
        expect(find.text('مسموح على هذا الجهاز'), findsNothing);

        await tester.tap(find.text('تفعيل'));
        await tester.pumpAndSettle();

        expect(push.prompts, 1);
        expect(find.text('الإشعارات متوقفة لهذا التطبيق'), findsOneWidget);
        await tester.pump(const Duration(seconds: 5));
      });

      testWidgets('never asked: «تفعيل» prompts, and a grant shows allowed', (tester) async {
        final push = _FakePush(PushPermissionState.notAsked, grants: true);
        await pump(tester, push: push);

        await tester.tap(find.text('تفعيل'));
        await tester.pumpAndSettle();

        expect(find.text('مسموح على هذا الجهاز'), findsOneWidget);
        expect(find.text('الإشعارات متوقفة لهذا التطبيق'), findsNothing);
      });

      testWidgets('coming back from the device\'s settings reads the answer again',
          (tester) async {
        final push = _FakePush(PushPermissionState.denied);
        await pump(tester, push: push);

        push.answer = PushPermissionState.allowed;
        for (final state in const [
          AppLifecycleState.inactive,
          AppLifecycleState.hidden,
          AppLifecycleState.paused,
          AppLifecycleState.hidden,
          AppLifecycleState.inactive,
          AppLifecycleState.resumed,
        ]) {
          tester.binding.handleAppLifecycleStateChanged(state);
        }
        await tester.pumpAndSettle();

        expect(find.text('مسموح على هذا الجهاز'), findsOneWidget);
      });

      testWidgets('an iPhone browser links to the install steps, with no switches',
          (tester) async {
        await pump(tester, guide: const _Guide(needsInstallSteps: true));

        expect(find.text('الأهداف'), findsNothing);
        expect(find.text('السماح بالإشعارات'), findsNothing);
        expect(find.text('الإشعارات'), findsOneWidget);

        await tester.tap(find.text('تثبيت التطبيق'));
        await tester.pumpAndSettle();
        expect(find.text('install-steps'), findsOneWidget);
      });
    });
  });

  group('the device ID (FR-062)', () {
    testWidgets('is hidden until known', (tester) async {
      await pump(tester);
      expect(find.text('معرّف الجهاز'), findsNothing);
    });

    testWidgets('shows in عن التطبيق after the version, with a copy action', (tester) async {
      await database.writeSetting(SettingsKeys.deviceId, '812');
      String? copied;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (
        call,
      ) async {
        if (call.method == 'Clipboard.setData') {
          copied = (call.arguments as Map<Object?, Object?>)['text'] as String?;
        }
        return null;
      });
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      await pump(tester);
      await scrollTo(tester, 'معرّف الجهاز');

      expect(
        tester.getTopLeft(find.text('معرّف الجهاز')).dy,
        greaterThan(tester.getTopLeft(find.text('الإصدار')).dy),
      );
      expect(find.text('812'), findsOneWidget);

      await tester.tap(find.text('معرّف الجهاز'));
      await tester.pump();
      expect(copied, '812');
      expect(find.text('تم نسخ معرّف الجهاز'), findsOneWidget);
      await tester.pump(const Duration(seconds: 5));
    });
  });
}
