// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'connectivity.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Whether the last request reached the server (research R29). No new plugin: a request
/// that fails with no response marks the app offline, and the next success marks it online
/// again.

@ProviderFor(ConnectivityStatus)
final connectivityStatusProvider = ConnectivityStatusProvider._();

/// Whether the last request reached the server (research R29). No new plugin: a request
/// that fails with no response marks the app offline, and the next success marks it online
/// again.
final class ConnectivityStatusProvider
    extends $NotifierProvider<ConnectivityStatus, bool> {
  /// Whether the last request reached the server (research R29). No new plugin: a request
  /// that fails with no response marks the app offline, and the next success marks it online
  /// again.
  ConnectivityStatusProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'connectivityStatusProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$connectivityStatusHash();

  @$internal
  @override
  ConnectivityStatus create() => ConnectivityStatus();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(bool value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<bool>(value),
    );
  }
}

String _$connectivityStatusHash() =>
    r'5c8285f9212b43358f2bd7598c7c49b1fedf980a';

/// Whether the last request reached the server (research R29). No new plugin: a request
/// that fails with no response marks the app offline, and the next success marks it online
/// again.

abstract class _$ConnectivityStatus extends $Notifier<bool> {
  bool build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<bool, bool>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<bool, bool>,
              bool,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
