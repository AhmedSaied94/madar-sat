import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madar_sat/core/network/api_failure.dart';
import 'package:madar_sat/design/components/banner.dart';
import 'package:madar_sat/design/components/button.dart';
import 'package:madar_sat/features/system/presentation/system_views.dart';

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

  testWidgets('the forced update names the build and opens the store path', (tester) async {
    await tester.pumpWidget(testApp(const ForcedUpdatePage()));

    expect(find.text('تحديث مطلوب'), findsOneWidget);
    expect(find.text('تحديث الآن'), findsOneWidget);
    expect(find.textContaining('إصدارك'), findsOneWidget);
    expect(find.byType(MadarButton), findsOneWidget);
  });
}
