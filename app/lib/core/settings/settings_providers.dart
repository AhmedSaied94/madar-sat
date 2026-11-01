import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../db/database_provider.dart';
import 'app_settings.dart';
import 'zone_holder.dart';

part 'settings_providers.g.dart';

/// The device's settings (data-model, drift v3).
///
/// Read from drift on start and re-read after every write, so the onboarding controller,
/// S15 and the theme all see one value and it survives a restart. A [Future], not a stream:
/// a screen only needs the value after a change it made, and every setter invalidates this.
/// While the first read is in flight the widgets use the bundled defaults, which is what a
/// fresh install shows.
@Riverpod(keepAlive: true)
class AppSettings extends _$AppSettings {
  @override
  Future<AppSettingsValue> build() async {
    final value =
        AppSettingsValue.fromMap(await ref.watch(appDatabaseProvider).readSettings());
    // The drift layer groups local days in this zone (M-R1-6): it cannot read this provider
    // (it is built on the database), so the value is handed over through the holder.
    ref.read(zoneHolderProvider).zone = value.zone;
    return value;
  }

  /// The current value, or the bundled defaults before the first read lands.
  AppSettingsValue get value => state.value ?? const AppSettingsValue();

  Future<void> setOnboardingStep(int step) => _write(SettingsKeys.onboardingStep, '$step');

  /// Finishing or skipping the flow: the last step and the flag land together.
  Future<void> completeOnboarding() =>
      _writeAll({SettingsKeys.onboardingDone: 'true'});

  /// S15's «إعادة خطوات البداية»: the flow opens at S1.1 next time and is shown again now.
  Future<void> restartOnboarding() =>
      _writeAll({SettingsKeys.onboardingStep: '0', SettingsKeys.onboardingDone: 'false'});

  Future<void> setTheme(MadarThemeChoice theme) => _write(SettingsKeys.theme, theme.name);

  Future<void> setZone(MadarZone zone) =>
      _write(SettingsKeys.zoneOffsetMinutes, zone.fixed?.inMinutes.toString());

  Future<void> setTimeFormat(MadarTimeFormat format) =>
      _write(SettingsKeys.timeFormat, format.name);

  Future<void> setFontScale(MadarFontScale scale) =>
      _write(SettingsKeys.fontScale, scale.name);

  /// My satellites: the empty set removes the row, so the O10 default stands again.
  Future<void> setSatellites(Set<int> ids) => _write(
        SettingsKeys.satelliteIds,
        ids.isEmpty ? null : (ids.toList()..sort()).join(','),
      );

  Future<void> _write(String key, String? value) async {
    await ref.read(appDatabaseProvider).writeSetting(key, value);
    ref.invalidateSelf();
  }

  Future<void> _writeAll(Map<String, String?> values) async {
    await ref.read(appDatabaseProvider).writeSettings(values);
    ref.invalidateSelf();
  }
}

/// The settings as a plain value, for widgets that only read them.
@riverpod
AppSettingsValue settings(Ref ref) =>
    ref.watch(appSettingsProvider).value ?? const AppSettingsValue();

/// The zone times and local days are shown in (S15 «المنطقة الزمنية»).
@Riverpod(keepAlive: true)
MadarZone appZone(Ref ref) =>
    ref.watch(appSettingsProvider).value?.zone ?? const MadarZone.auto();
