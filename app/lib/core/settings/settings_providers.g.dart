// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'settings_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The device's settings (data-model, drift v3).
///
/// Read from drift on start and re-read after every write, so the onboarding controller,
/// S15 and the theme all see one value and it survives a restart. A [Future], not a stream:
/// a screen only needs the value after a change it made, and every setter invalidates this.
/// While the first read is in flight the widgets use the bundled defaults, which is what a
/// fresh install shows.

@ProviderFor(AppSettings)
final appSettingsProvider = AppSettingsProvider._();

/// The device's settings (data-model, drift v3).
///
/// Read from drift on start and re-read after every write, so the onboarding controller,
/// S15 and the theme all see one value and it survives a restart. A [Future], not a stream:
/// a screen only needs the value after a change it made, and every setter invalidates this.
/// While the first read is in flight the widgets use the bundled defaults, which is what a
/// fresh install shows.
final class AppSettingsProvider
    extends $AsyncNotifierProvider<AppSettings, AppSettingsValue> {
  /// The device's settings (data-model, drift v3).
  ///
  /// Read from drift on start and re-read after every write, so the onboarding controller,
  /// S15 and the theme all see one value and it survives a restart. A [Future], not a stream:
  /// a screen only needs the value after a change it made, and every setter invalidates this.
  /// While the first read is in flight the widgets use the bundled defaults, which is what a
  /// fresh install shows.
  AppSettingsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'appSettingsProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$appSettingsHash();

  @$internal
  @override
  AppSettings create() => AppSettings();
}

String _$appSettingsHash() => r'32b0b9d21b6b6766f75a330a2d803b5e51104d59';

/// The device's settings (data-model, drift v3).
///
/// Read from drift on start and re-read after every write, so the onboarding controller,
/// S15 and the theme all see one value and it survives a restart. A [Future], not a stream:
/// a screen only needs the value after a change it made, and every setter invalidates this.
/// While the first read is in flight the widgets use the bundled defaults, which is what a
/// fresh install shows.

abstract class _$AppSettings extends $AsyncNotifier<AppSettingsValue> {
  FutureOr<AppSettingsValue> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref =
        this.ref as $Ref<AsyncValue<AppSettingsValue>, AppSettingsValue>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<AppSettingsValue>, AppSettingsValue>,
              AsyncValue<AppSettingsValue>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

/// The settings as a plain value, for widgets that only read them.

@ProviderFor(settings)
final settingsProvider = SettingsProvider._();

/// The settings as a plain value, for widgets that only read them.

final class SettingsProvider
    extends
        $FunctionalProvider<
          AppSettingsValue,
          AppSettingsValue,
          AppSettingsValue
        >
    with $Provider<AppSettingsValue> {
  /// The settings as a plain value, for widgets that only read them.
  SettingsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'settingsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$settingsHash();

  @$internal
  @override
  $ProviderElement<AppSettingsValue> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  AppSettingsValue create(Ref ref) {
    return settings(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AppSettingsValue value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AppSettingsValue>(value),
    );
  }
}

String _$settingsHash() => r'7302216e214714b57776a96204abd8e2b8c5fac1';

/// The zone times and local days are shown in (S15 «المنطقة الزمنية»).

@ProviderFor(appZone)
final appZoneProvider = AppZoneProvider._();

/// The zone times and local days are shown in (S15 «المنطقة الزمنية»).

final class AppZoneProvider
    extends $FunctionalProvider<MadarZone, MadarZone, MadarZone>
    with $Provider<MadarZone> {
  /// The zone times and local days are shown in (S15 «المنطقة الزمنية»).
  AppZoneProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'appZoneProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$appZoneHash();

  @$internal
  @override
  $ProviderElement<MadarZone> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  MadarZone create(Ref ref) {
    return appZone(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(MadarZone value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<MadarZone>(value),
    );
  }
}

String _$appZoneHash() => r'6eeb8563cd8e42602b460474e31920fe6d89976b';
