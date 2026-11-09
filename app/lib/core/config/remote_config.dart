import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../links/url_opener.dart';
import 'app_config.dart';
import 'build_info.dart';

part 'remote_config.g.dart';

/// The `features` parameter: what is switched on for this build (research R15, FR-050).
@immutable
class AppFeatures {
  const AppFeatures({this.liveCenter = false, this.lineups = false});

  /// S3's live center.
  final bool liveCenter;

  /// The التشكيل tab inside it.
  final bool lineups;

  /// The bundled value, as `setDefaults` sends it.
  static const String bundledJson = '{"live_center":false,"lineups":false}';

  /// [raw] read flag by flag. Bad JSON, or a flag that isn't a boolean, keeps [bundled]'s value.
  static AppFeatures parse(String? raw, {required AppFeatures bundled}) {
    final Object? decoded;
    try {
      decoded = jsonDecode(raw ?? '');
    } on FormatException {
      return bundled;
    }
    if (decoded is! Map<String, Object?>) return bundled;
    final liveCenter = decoded['live_center'];
    final lineups = decoded['lineups'];
    return AppFeatures(
      liveCenter: liveCenter is bool ? liveCenter : bundled.liveCenter,
      lineups: lineups is bool ? lineups : bundled.lineups,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is AppFeatures && other.liveCenter == liveCenter && other.lineups == lineups;

  @override
  int get hashCode => Object.hash(liveCenter, lineups);
}

/// The Remote Config values D3 reads (system-design §5.1, research R28), with the bundled
/// flavor values as their defaults.
///
/// Pure data: [RemoteConfigRepository] fetches it, the app passes it in through an override
/// at start, and every provider reads it synchronously from then on. A host change applies
/// on the next launch, never mid-session (cached ETags and drift keys are per host).
@immutable
class RemoteConfigValues {
  const RemoteConfigValues({
    required this.apiBaseUrl,
    required this.mediaBaseUrl,
    required this.minSupportedBuild,
    required this.latestBuild,
    required this.livePollIntervalSeconds,
    this.features = const AppFeatures(),
  });

  /// The bundled defaults: the flavor's own hosts, no forced update, 30 s live polling.
  static RemoteConfigValues get bundled => const RemoteConfigValues(
        apiBaseUrl: AppConfig.apiBaseUrl,
        mediaBaseUrl: AppConfig.mediaBaseUrl,
        minSupportedBuild: buildNumberFloor,
        latestBuild: buildNumberFloor,
        livePollIntervalSeconds: defaultLivePollSeconds,
      );

  /// 0 means "no forced update": every build is at least 0.
  static const int buildNumberFloor = 0;

  static const int defaultLivePollSeconds = 30;

  final String apiBaseUrl;
  final String mediaBaseUrl;

  /// The lowest build number that may run (S0 forced update).
  final int minSupportedBuild;

  /// The newest build number published; the soft-update banner renders it on D8.
  final int latestBuild;

  /// S2's live poll interval, in seconds.
  final int livePollIntervalSeconds;

  /// What is switched on; both flags are off in the bundle (FR-050).
  final AppFeatures features;

  /// True when this build may run: a floor of 0 never blocks anything (R28).
  bool get updateRequired => minSupportedBuild > BuildInfo.buildNumber;

  Duration get livePollInterval => Duration(seconds: livePollIntervalSeconds);

  /// The parsed values from Remote Config's raw strings, keeping a bundled default wherever
  /// the fetched value is missing or unusable (R28: a host must be `https` without userinfo).
  factory RemoteConfigValues.fromRaw(
    Map<String, String> raw, {
    required RemoteConfigValues bundled,
  }) {
    final api = httpsUri(raw['api_base_url'])?.toString();
    final media = httpsUri(raw['media_base_url'])?.toString();
    final seconds = int.tryParse(raw['live_poll_interval_s'] ?? '');
    return RemoteConfigValues(
      apiBaseUrl: api ?? bundled.apiBaseUrl,
      mediaBaseUrl: media ?? bundled.mediaBaseUrl,
      minSupportedBuild:
          int.tryParse(raw['min_supported_build'] ?? '') ?? bundled.minSupportedBuild,
      latestBuild: int.tryParse(raw['latest_build'] ?? '') ?? bundled.latestBuild,
      livePollIntervalSeconds: seconds != null && seconds >= 10 && seconds <= 600
          ? seconds
          : bundled.livePollIntervalSeconds,
      features: AppFeatures.parse(raw['features'], bundled: bundled.features),
    );
  }
}

/// The values in force. `main_*.dart` overrides it with the fetched ones before the app
/// builds; the bundled defaults are what a build without Firebase runs on.
@Riverpod(keepAlive: true)
RemoteConfigValues remoteConfig(Ref ref) => RemoteConfigValues.bundled;

/// The API host every request goes to (the bundled value until Remote Config answers).
@riverpod
String apiBaseUrl(Ref ref) => ref.watch(remoteConfigProvider).apiBaseUrl;

/// The media host images may load from, and nothing else (R28, D2's security follow-up).
@riverpod
String mediaBaseUrl(Ref ref) => ref.watch(remoteConfigProvider).mediaBaseUrl;

/// The live poll interval from Remote Config, in place of D2's bundled constant.
@riverpod
Duration livePollInterval(Ref ref) => ref.watch(remoteConfigProvider).livePollInterval;

/// Whether S3's live center is on (FR-050). It applies from the next launch.
@riverpod
bool liveCenterEnabled(Ref ref) => ref.watch(remoteConfigProvider).features.liveCenter;

/// Whether the التشكيل tab may show (FR-056).
@riverpod
bool lineupsEnabled(Ref ref) => ref.watch(remoteConfigProvider).features.lineups;
