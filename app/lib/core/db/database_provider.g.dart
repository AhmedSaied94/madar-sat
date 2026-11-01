// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'database_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The app's one drift database. Tests override it with an in-memory `AppDatabase`.
///
/// The zone the local days are grouped in comes from [zoneHolderProvider]: the settings
/// provider is built on this database, so a provider dependency here would be a cycle.

@ProviderFor(appDatabase)
final appDatabaseProvider = AppDatabaseProvider._();

/// The app's one drift database. Tests override it with an in-memory `AppDatabase`.
///
/// The zone the local days are grouped in comes from [zoneHolderProvider]: the settings
/// provider is built on this database, so a provider dependency here would be a cycle.

final class AppDatabaseProvider
    extends $FunctionalProvider<AppDatabase, AppDatabase, AppDatabase>
    with $Provider<AppDatabase> {
  /// The app's one drift database. Tests override it with an in-memory `AppDatabase`.
  ///
  /// The zone the local days are grouped in comes from [zoneHolderProvider]: the settings
  /// provider is built on this database, so a provider dependency here would be a cycle.
  AppDatabaseProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'appDatabaseProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$appDatabaseHash();

  @$internal
  @override
  $ProviderElement<AppDatabase> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  AppDatabase create(Ref ref) {
    return appDatabase(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AppDatabase value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AppDatabase>(value),
    );
  }
}

String _$appDatabaseHash() => r'8b8d52902e1ef0f331daa6701f95660d40acea13';
