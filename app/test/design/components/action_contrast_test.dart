import 'dart:math' as math;

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:madar_sat/core/db/app_database.dart';
import 'package:madar_sat/core/db/database_provider.dart';
import 'package:madar_sat/core/platform/install_guide.dart';
import 'package:madar_sat/core/platform/install_guide_provider.dart';
import 'package:madar_sat/core/platform/push_routes.dart';
import 'package:madar_sat/core/platform/push_service.dart';
import 'package:madar_sat/core/theme/madar_theme.dart';
import 'package:madar_sat/core/theme/madar_tokens.dart';
import 'package:madar_sat/features/notifications/presentation/foreground_banner.dart';
import 'package:madar_sat/features/settings/presentation/notification_settings.dart';
import 'package:madar_sat/l10n/app_localizations.dart';

class _Push extends NoPushService {
  const _Push();

  @override
  Future<PushPermissionState> permission() async => PushPermissionState.denied;
}

class _Guide implements InstallGuide {
  const _Guide();

  @override
  bool get isWeb => false;

  @override
  bool get isInstalled => true;

  @override
  bool get needsInstallSteps => false;
}

/// WCAG relative luminance of an opaque colour.
double _luminance(Color c) {
  double channel(double v) => v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
  return 0.2126 * channel(c.r) + 0.7152 * channel(c.g) + 0.0722 * channel(c.b);
}

double _contrast(Color a, Color b) {
  final la = _luminance(a);
  final lb = _luminance(b);
  final (hi, lo) = la > lb ? (la, lb) : (lb, la);
  return (hi + 0.05) / (lo + 0.05);
}

/// [top] laid over [bottom], so a translucent container is measured as it is seen.
Color _over(Color top, Color bottom) => Color.alphaBlend(top, bottom);

/// The first painted fill behind [text]: a `Material` or a decorated box with a colour,
/// laid over the screen's ground.
Color _backgroundBehind(WidgetTester tester, Finder text, Color ground) {
  final fills = <Color>[];
  tester.element(text).visitAncestorElements((element) {
    final widget = element.widget;
    Color? fill;
    if (widget is Material && widget.type != MaterialType.transparency) fill = widget.color;
    if (widget is DecoratedBox && widget.decoration is BoxDecoration) {
      fill = (widget.decoration as BoxDecoration).color;
    }
    if (widget is Container && widget.decoration is BoxDecoration) {
      fill = (widget.decoration as BoxDecoration).color;
    }
    if (fill != null && fill.a > 0) fills.add(fill);
    return fills.isEmpty || fills.last.a < 1;
  });
  return fills.reversed.fold(ground, (under, fill) => _over(fill, under));
}

Color _textColour(WidgetTester tester, Finder text) =>
    tester.renderObject<RenderParagraph>(text).text.style!.color!;

Widget _app(Brightness brightness, Widget child, {List<Override> overrides = const []}) =>
    ProviderScope(
      overrides: overrides,
      child: MaterialApp(
        locale: const Locale('ar'),
        supportedLocales: const [Locale('ar')],
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        theme: brightness == Brightness.dark ? MadarTheme.dark : MadarTheme.light,
        themeAnimationDuration: Duration.zero,
        home: Scaffold(body: child),
      ),
    );

/// «تفعيل» (S15's platform state, FR-063) and the banner's «عرض» (FR-059) read in both themes:
/// never volt `accent` text, and at least WCAG AA (4.5:1) against what they sit on
/// (constitution, accessibility; review M-R1-1).
void main() {
  for (final brightness in Brightness.values) {
    group('${brightness.name} theme', () {
      testWidgets('the banner\'s «عرض»', (tester) async {
        await tester.pumpWidget(
          _app(
            brightness,
            ForegroundBanner(
              push: ForegroundPush(
                title: 'هدف للأهلي',
                body: 'الأهلي 1 – 0 الزمالك',
                route: parsePushRoute('/match/7'),
              ),
              onView: () {},
              onDismiss: () {},
            ),
          ),
        );
        await tester.pumpAndSettle();

        final label = find.text('عرض');
        final colors = tester.element(label).madarColors;
        final ink = _textColour(tester, label);
        if (brightness == Brightness.light) expect(ink, isNot(colors.accent));
        expect(
          _contrast(ink, _backgroundBehind(tester, label, colors.bg)),
          greaterThanOrEqualTo(4.5),
        );
      });

      testWidgets('S15\'s «تفعيل» when notifications are denied', (tester) async {
        final database =
            AppDatabase(NativeDatabase.memory(), now: () => DateTime.utc(2026, 11, 1, 9));
        addTearDown(database.close);
        await tester.pumpWidget(
          _app(
            brightness,
            const SingleChildScrollView(child: NotificationSettingsGroup()),
            overrides: [
              appDatabaseProvider.overrideWithValue(database),
              pushServiceProvider.overrideWithValue(const _Push()),
              installGuideProvider.overrideWithValue(const _Guide()),
            ],
          ),
        );
        await tester.pumpAndSettle();

        final label = find.text('تفعيل');
        final colors = tester.element(label).madarColors;
        final ink = _textColour(tester, label);
        if (brightness == Brightness.light) expect(ink, isNot(colors.accent));
        expect(
          _contrast(ink, _backgroundBehind(tester, label, colors.bg)),
          greaterThanOrEqualTo(4.5),
        );
      });
    });
  }
}
