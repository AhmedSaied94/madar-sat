import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madar_sat/core/links/url_opener.dart';
import 'package:madar_sat/core/network/api_failure.dart';
import 'package:madar_sat/design/components/banner.dart';
import 'package:madar_sat/design/components/button.dart';
import 'package:madar_sat/features/system/presentation/system_views.dart';

import '../../fixtures/fake_url_opener.dart';
import '../../fixtures/test_app.dart';

/// S0's states (research R29, US2 scenario 13): no connection offers «إعادة المحاولة», a
/// server error shows the load-failed copy, the offline banner carries the data's age, and
/// the exit snackbar says what a second back does.
void main() {
  testWidgets('no connection: its own words and a retry that runs', (tester) async {
    var retries = 0;
    await tester.pumpWidget(testApp(NoConnectionView(onRetry: () => retries++)));

    expect(find.text('لا يوجد اتصال بالإنترنت'), findsOneWidget);
    expect(find.text('تأكد من اتصالك بالإنترنت وحاول مرة أخرى'), findsOneWidget);

    await tester.tap(find.text('إعادة المحاولة'));
    expect(retries, 1);
  });

  testWidgets('a server error shows the load-failed copy, not the server message',
      (tester) async {
    await tester.pumpWidget(
      testApp(
        LoadFailedView(
          failure: const ApiFailure(code: 'internal_error'),
          onRetry: () {},
        ),
      ),
    );

    expect(find.text('تعذّر تحميل البيانات'), findsOneWidget);
    expect(find.text('حدث خطأ غير متوقع'), findsOneWidget);
  });

  testWidgets('a retry that is out says so instead of offering the action again',
      (tester) async {
    await tester.pumpWidget(
      testApp(const LoadFailedView(retrying: true)),
    );

    expect(find.text('جارٍ المحاولة...'), findsOneWidget);
    expect(find.text('إعادة المحاولة'), findsNothing);
  });

  testWidgets('the offline banner shows the age of the newest copy', (tester) async {
    await tester.pumpWidget(
      testApp(const OfflineBanner(age: Duration(minutes: 12))),
    );

    expect(find.text('أنت غير متصل — آخر تحديث منذ 12 د'), findsOneWidget);
    expect(find.textContaining('غير متصل'), findsOneWidget);
  });

  testWidgets('the exit snackbar says what a second back does', (tester) async {
    await tester.pumpWidget(
      testApp(
        Builder(
          builder: (context) => TextButton(
            onPressed: () => MadarSnackbar.show(context, 'اضغط رجوع مرة أخرى للخروج'),
            child: const Text('back'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('back'));
    await tester.pump();

    expect(find.text('اضغط رجوع مرة أخرى للخروج'), findsOneWidget);
    expect(find.byType(SnackBar), findsOneWidget);
  });

  testWidgets('the forced update names the build and its button opens Google Play',
      (tester) async {
    final opener = FakeUrlOpener();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [urlOpenerProvider.overrideWithValue(opener)],
        child: testApp(const ForcedUpdatePage()),
      ),
    );

    expect(find.text('تحديث مطلوب'), findsOneWidget);
    expect(find.text('تحديث الآن'), findsOneWidget);
    expect(find.textContaining('إصدارك'), findsOneWidget);
    expect(find.byType(MadarButton), findsOneWidget);

    // A native build cannot reload its own code: the button opens the store, which is what
    // the screen promises (M-R1-4).
    await tester.tap(find.text('تحديث الآن'));
    await tester.pump();

    expect(opener.opened.single.toString(), ForcedUpdatePage.playStoreUrl);
  });

  group('the exit rule on a root tab (M-R1-7)', () {
    late List<MethodCall> platformCalls;

    setUp(() {
      platformCalls = [];
    });

    Future<void> pumpGuard(WidgetTester tester) async {
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          platformCalls.add(call);
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger
            .setMockMethodCallHandler(SystemChannels.platform, null),
      );
      // `android: true` rather than a debug platform override: the binding refuses a test
      // that leaves a foundation variable changed.
      await tester.pumpWidget(
        testApp(const ExitGuard(android: true, child: Center(child: Text('root')))),
      );
    }

    int exits() => platformCalls.where((call) => call.method == 'SystemNavigator.pop').length;

    testWidgets('a first back shows the snackbar and does not leave the app', (tester) async {
      await pumpGuard(tester);

      await tester.binding.handlePopRoute();
      await tester.pump();

      expect(find.text('اضغط رجوع مرة أخرى للخروج'), findsOneWidget);
      expect(exits(), 0);
    });

    testWidgets('a second back within the window leaves the app', (tester) async {
      await pumpGuard(tester);

      await tester.binding.handlePopRoute();
      await tester.pump();
      await tester.binding.handlePopRoute();
      await tester.pump();

      expect(exits(), 1);
    });

    testWidgets('the window closes after two seconds, so the next back asks again',
        (tester) async {
      await pumpGuard(tester);

      await tester.binding.handlePopRoute();
      await tester.pump(const Duration(seconds: 3));
      await tester.binding.handlePopRoute();
      await tester.pump();

      expect(exits(), 0);
      expect(find.text('اضغط رجوع مرة أخرى للخروج'), findsWidgets);
    });
  });
}
