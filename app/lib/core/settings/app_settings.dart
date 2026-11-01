import 'package:flutter/material.dart';

/// The device's own settings (D3, research R27): one immutable value read from drift's
/// `app_settings` table, so every screen sees the same theme, zone, clock format, font scale
/// and satellite choice.
///
/// Pure apart from `ThemeMode`/`IconData`: the parsing lives here, the drift reads in
/// `settings_providers.dart`.

/// The three values of «المظهر» (S1.1, S15).
enum MadarThemeChoice { dark, light, system }

/// 12 or 24 hours (S15 «صيغة الوقت»).
enum MadarTimeFormat { h12, h24 }

/// The three font sizes of S15: 1.0, 1.15 and 1.3 times the device's own size.
enum MadarFontScale {
  normal(1.0),
  large(1.15),
  xlarge(1.3);

  const MadarFontScale(this.factor);

  final double factor;
}

/// The zone the app shows times in: the device's own, or a fixed GMT offset chosen in S15.
class MadarZone {
  const MadarZone.auto() : fixed = null;

  const MadarZone.fixed(Duration this.fixed);

  /// Null means the device's zone, DST included.
  final Duration? fixed;

  /// The offset of a local wall-clock instant, in the shape `MadarTime.dayWindow` takes.
  Duration offsetAt(DateTime local) => fixed ?? local.timeZoneOffset;

  /// [instant]'s wall clock in this zone. With no fixed offset the device's own wall clock
  /// stays exact across DST; a fixed offset is a plain shift of UTC.
  DateTime wallClock(DateTime instant) =>
      fixed == null ? instant.toLocal() : instant.toUtc().add(fixed!);

  /// «تلقائي (GMT+3)» or «GMT−12» … «GMT+14», with Western digits (constitution III).
  String label(String automatic) {
    if (fixed == null) return automatic;
    final minutes = fixed!.inMinutes;
    final sign = minutes < 0 ? '−' : '+';
    final absolute = minutes.abs();
    final hours = absolute ~/ 60;
    final rest = absolute % 60;
    return rest == 0 ? 'GMT$sign$hours' : 'GMT$sign$hours:${rest.toString().padLeft(2, '0')}';
  }

  @override
  bool operator ==(Object other) => other is MadarZone && other.fixed == fixed;

  @override
  int get hashCode => fixed.hashCode;
}

/// The keys `app_settings` stores (data-model, drift schema v3). One place, so the drift
/// reads, the onboarding writer and the tests agree.
abstract final class SettingsKeys {
  static const String onboardingStep = 'onboarding.step';
  static const String onboardingDone = 'onboarding.done';
  static const String theme = 'theme';
  static const String zoneOffsetMinutes = 'time.zone_offset_minutes';
  static const String timeFormat = 'time.format';
  static const String fontScale = 'font.scale';
  static const String satelliteIds = 'satellites.my';
  static const String notificationsAsked = 'notifications.asked';
}

/// Everything the app reads once at start and on every change.
@immutable
class AppSettingsValue {
  const AppSettingsValue({
    this.onboardingStep = 0,
    this.onboardingDone = false,
    this.theme = MadarThemeChoice.dark,
    this.zone = const MadarZone.auto(),
    this.timeFormat = MadarTimeFormat.h12,
    this.fontScale = MadarFontScale.normal,
    this.satelliteIds = const {},
  });

  /// The onboarding step last shown (S1.1 … S1.5), resumed at launch.
  final int onboardingStep;

  /// True once the flow was finished or skipped; S1 is never shown again.
  final bool onboardingDone;

  final MadarThemeChoice theme;
  final MadarZone zone;
  final MadarTimeFormat timeFormat;
  final MadarFontScale fontScale;

  /// My satellites, as the user chose them; empty means "the O10 default set stands".
  final Set<int> satelliteIds;

  ThemeMode get themeMode => switch (theme) {
        MadarThemeChoice.dark => ThemeMode.dark,
        MadarThemeChoice.light => ThemeMode.light,
        MadarThemeChoice.system => ThemeMode.system,
      };

  bool get use24h => timeFormat == MadarTimeFormat.h24;

  /// The text scale the whole app is built with: the S15 choice on top of the device's own.
  TextScaler textScaler(double device) => TextScaler.linear(device * fontScale.factor);

  /// The number S1.1's four progress dots use: the step, 0-based, capped at the last one.
  static const int stepCount = 4;

  AppSettingsValue copyWith({
    int? onboardingStep,
    bool? onboardingDone,
    MadarThemeChoice? theme,
    MadarZone? zone,
    MadarTimeFormat? timeFormat,
    MadarFontScale? fontScale,
    Set<int>? satelliteIds,
  }) =>
      AppSettingsValue(
        onboardingStep: onboardingStep ?? this.onboardingStep,
        onboardingDone: onboardingDone ?? this.onboardingDone,
        theme: theme ?? this.theme,
        zone: zone ?? this.zone,
        timeFormat: timeFormat ?? this.timeFormat,
        fontScale: fontScale ?? this.fontScale,
        satelliteIds: satelliteIds ?? this.satelliteIds,
      );

  /// A stored map back into the typed value. Anything unreadable falls back to the bundled
  /// default rather than failing the app (a downgraded build, a hand-edited row).
  static AppSettingsValue fromMap(Map<String, String> stored) {
    final step = int.tryParse(stored[SettingsKeys.onboardingStep] ?? '');
    final zoneMinutes = int.tryParse(stored[SettingsKeys.zoneOffsetMinutes] ?? '');
    final ids = <int>{};
    for (final part in (stored[SettingsKeys.satelliteIds] ?? '').split(',')) {
      final id = int.tryParse(part.trim());
      if (id != null) ids.add(id);
    }
    return AppSettingsValue(
      onboardingStep: (step ?? 0).clamp(0, stepCount),
      onboardingDone: stored[SettingsKeys.onboardingDone] == 'true',
      theme: MadarThemeChoice.values.firstWhere(
        (value) => value.name == stored[SettingsKeys.theme],
        orElse: () => MadarThemeChoice.dark,
      ),
      zone: zoneMinutes == null
          ? const MadarZone.auto()
          : MadarZone.fixed(Duration(minutes: zoneMinutes)),
      timeFormat: MadarTimeFormat.values.firstWhere(
        (value) => value.name == stored[SettingsKeys.timeFormat],
        orElse: () => MadarTimeFormat.h12,
      ),
      fontScale: MadarFontScale.values.firstWhere(
        (value) => value.name == stored[SettingsKeys.fontScale],
        orElse: () => MadarFontScale.normal,
      ),
      satelliteIds: ids,
    );
  }
}
