import 'dart:async';

import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/foundation.dart';

import 'app_config.dart';
import 'remote_config.dart';

/// Reads Remote Config on start (research R28): the bundled defaults for every
/// system-design §5.1 key, then `fetchAndActivate` with a 10 s timeout and a one-hour
/// minimum interval in production.
///
/// Nothing here throws: a build without Firebase, a console that has no parameters yet, an
/// offline phone — every one of them keeps the bundled defaults, which are the values the
/// app shipped with.
class RemoteConfigRepository {
  const RemoteConfigRepository({this.timeout = const Duration(seconds: 10)});

  final Duration timeout;

  Future<RemoteConfigValues> load() async {
    final bundled = RemoteConfigValues.bundled;
    if (!AppConfig.isFirebaseConfigured) return bundled;

    final remote = FirebaseRemoteConfig.instance;
    try {
      await remote.setDefaults(const {
        'api_base_url': AppConfig.apiBaseUrl,
        'media_base_url': AppConfig.mediaBaseUrl,
        'min_supported_build': '${RemoteConfigValues.buildNumberFloor}',
        'latest_build': '${RemoteConfigValues.buildNumberFloor}',
        'live_poll_interval_s': '${RemoteConfigValues.defaultLivePollSeconds}',
      });
      await remote.setConfigSettings(
        RemoteConfigSettings(
          // A debug build refetches on every start so an editor can try a value; release
          // builds keep the console's one-hour floor.
          fetchTimeout: timeout,
          minimumFetchInterval: kReleaseMode ? const Duration(hours: 1) : Duration.zero,
        ),
      );
      await remote.fetchAndActivate().timeout(timeout);
    } on Object {
      // Timeout, offline, no parameters, the plugin missing: the defaults stand (R28).
      return bundled;
    }

    return RemoteConfigValues.fromRaw(
      {
        for (final key in const [
          'api_base_url',
          'media_base_url',
          'min_supported_build',
          'latest_build',
          'live_poll_interval_s',
        ])
          key: remote.getString(key),
      },
      bundled: bundled,
    );
  }

  /// The bundle as the repository would apply it, for tests and the runbook.
  @visibleForTesting
  static RemoteConfigValues apply(Map<String, String> raw) =>
      RemoteConfigValues.fromRaw(raw, bundled: RemoteConfigValues.bundled);
}
