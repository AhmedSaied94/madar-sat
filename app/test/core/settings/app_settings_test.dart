import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madar_sat/core/settings/app_settings.dart';

/// The stored settings (research R27, data-model drift v3): every value parses back, an
/// unreadable one falls back to the bundled default, and the theme, clock and scale derive
/// from it.
void main() {
  test('an empty map is a dark, automatic, 12-hour, normal-size fresh install', () {
    const value = AppSettingsValue();
    final parsed = AppSettingsValue.fromMap(const {});
    expect(parsed.theme, MadarThemeChoice.dark);
    expect(parsed.themeMode, ThemeMode.dark);
    expect(parsed.zone.fixed, isNull);
    expect(parsed.use24h, isFalse);
    expect(parsed.fontScale, MadarFontScale.normal);
    expect(parsed.onboardingDone, isFalse);
    expect(parsed.satelliteIds, isEmpty);
    expect(parsed.onboardingStep, value.onboardingStep);
  });

  test('a stored choice parses back, satellites included', () {
    final parsed = AppSettingsValue.fromMap(const {
      SettingsKeys.onboardingStep: '2',
      SettingsKeys.onboardingDone: 'true',
      SettingsKeys.theme: 'light',
      SettingsKeys.zoneOffsetMinutes: '-720',
      SettingsKeys.timeFormat: 'h24',
      SettingsKeys.fontScale: 'xlarge',
      SettingsKeys.satelliteIds: '9,2,31',
    });
    expect(parsed.onboardingStep, 2);
    expect(parsed.onboardingDone, isTrue);
    expect(parsed.themeMode, ThemeMode.light);
    expect(parsed.zone.fixed, const Duration(hours: -12));
    expect(parsed.use24h, isTrue);
    expect(parsed.fontScale.factor, 1.3);
    expect(parsed.satelliteIds, {2, 9, 31});
  });

  test('an unknown or corrupt value falls back instead of failing the app', () {
    final parsed = AppSettingsValue.fromMap(const {
      SettingsKeys.onboardingStep: '99',
      SettingsKeys.theme: 'sepia',
      SettingsKeys.timeFormat: 'h13',
      SettingsKeys.fontScale: 'huge',
      SettingsKeys.satelliteIds: '2,,x,',
    });
    expect(parsed.onboardingStep, AppSettingsValue.stepCount);
    expect(parsed.themeMode, ThemeMode.dark);
    expect(parsed.use24h, isFalse);
    expect(parsed.fontScale, MadarFontScale.normal);
    expect(parsed.satelliteIds, {2});
  });

  test('a zone names itself in Latin digits, and automatic keeps its own label', () {
    expect(const MadarZone.fixed(Duration(hours: 3)).label('تلقائي'), 'GMT+3');
    expect(const MadarZone.fixed(Duration(hours: -12)).label('تلقائي'), 'GMT−12');
    expect(
      const MadarZone.fixed(Duration(hours: 5, minutes: 30)).label('تلقائي'),
      'GMT+5:30',
    );
    expect(const MadarZone.auto().label('تلقائي'), 'تلقائي');
  });

  test('a fixed zone shifts the wall clock; automatic keeps the device one', () {
    const instant = '2026-11-01T21:00:00Z';
    final fixed = const MadarZone.fixed(Duration(hours: 3)).wallClock(DateTime.parse(instant));
    expect(fixed.hour, 0);
    expect(fixed.day, 2);
    final automatic = const MadarZone.auto().wallClock(DateTime.parse(instant));
    expect(automatic, DateTime.parse(instant).toLocal());
  });

  test('the S15 font choice multiplies the device size', () {
    expect(const AppSettingsValue().textScaler(1.0).scale(16), 16);
    expect(
      const AppSettingsValue(fontScale: MadarFontScale.xlarge).textScaler(1.0).scale(10),
      13,
    );
    // The device's own accessibility size is kept and multiplied, not replaced.
    expect(
      const AppSettingsValue(fontScale: MadarFontScale.large).textScaler(1.2).scale(10),
      13.799999999999999,
    );
  });
}
