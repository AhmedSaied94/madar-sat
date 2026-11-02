// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'remote_config.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The values in force. `main_*.dart` overrides it with the fetched ones before the app
/// builds; the bundled defaults are what a build without Firebase runs on.

@ProviderFor(remoteConfig)
final remoteConfigProvider = RemoteConfigProvider._();

/// The values in force. `main_*.dart` overrides it with the fetched ones before the app
/// builds; the bundled defaults are what a build without Firebase runs on.

final class RemoteConfigProvider
    extends
        $FunctionalProvider<
          RemoteConfigValues,
          RemoteConfigValues,
          RemoteConfigValues
        >
    with $Provider<RemoteConfigValues> {
  /// The values in force. `main_*.dart` overrides it with the fetched ones before the app
  /// builds; the bundled defaults are what a build without Firebase runs on.
  RemoteConfigProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'remoteConfigProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$remoteConfigHash();

  @$internal
  @override
  $ProviderElement<RemoteConfigValues> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  RemoteConfigValues create(Ref ref) {
    return remoteConfig(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(RemoteConfigValues value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<RemoteConfigValues>(value),
    );
  }
}

String _$remoteConfigHash() => r'e1df80e44f5e5672f23f0a10923d22f56ccbc25d';

/// The API host every request goes to (the bundled value until Remote Config answers).

@ProviderFor(apiBaseUrl)
final apiBaseUrlProvider = ApiBaseUrlProvider._();

/// The API host every request goes to (the bundled value until Remote Config answers).

final class ApiBaseUrlProvider
    extends $FunctionalProvider<String, String, String>
    with $Provider<String> {
  /// The API host every request goes to (the bundled value until Remote Config answers).
  ApiBaseUrlProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'apiBaseUrlProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$apiBaseUrlHash();

  @$internal
  @override
  $ProviderElement<String> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  String create(Ref ref) {
    return apiBaseUrl(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(String value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<String>(value),
    );
  }
}

String _$apiBaseUrlHash() => r'22b8010f2421fa115bc1817b20ed224e0fa37007';

/// The media host images may load from, and nothing else (R28, D2's security follow-up).

@ProviderFor(mediaBaseUrl)
final mediaBaseUrlProvider = MediaBaseUrlProvider._();

/// The media host images may load from, and nothing else (R28, D2's security follow-up).

final class MediaBaseUrlProvider
    extends $FunctionalProvider<String, String, String>
    with $Provider<String> {
  /// The media host images may load from, and nothing else (R28, D2's security follow-up).
  MediaBaseUrlProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'mediaBaseUrlProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$mediaBaseUrlHash();

  @$internal
  @override
  $ProviderElement<String> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  String create(Ref ref) {
    return mediaBaseUrl(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(String value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<String>(value),
    );
  }
}

String _$mediaBaseUrlHash() => r'409b2d08b70a9942419bcf4d656adb544a68b1b0';

/// The live poll interval from Remote Config, in place of D2's bundled constant.

@ProviderFor(livePollInterval)
final livePollIntervalProvider = LivePollIntervalProvider._();

/// The live poll interval from Remote Config, in place of D2's bundled constant.

final class LivePollIntervalProvider
    extends $FunctionalProvider<Duration, Duration, Duration>
    with $Provider<Duration> {
  /// The live poll interval from Remote Config, in place of D2's bundled constant.
  LivePollIntervalProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'livePollIntervalProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$livePollIntervalHash();

  @$internal
  @override
  $ProviderElement<Duration> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  Duration create(Ref ref) {
    return livePollInterval(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(Duration value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<Duration>(value),
    );
  }
}

String _$livePollIntervalHash() => r'b4d998e88674e9c518d6f6dc660242e9438aeb09';
