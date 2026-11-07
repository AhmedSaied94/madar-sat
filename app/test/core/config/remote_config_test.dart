import 'package:flutter_test/flutter_test.dart';
import 'package:madar_sat/core/config/build_info.dart';
import 'package:madar_sat/core/config/remote_config.dart';

/// Remote Config's rules (research R28, US2 scenario 12): the bundled defaults when nothing
/// is fetched, `https`-only hosts, the forced update, and the live interval the poller takes.
void main() {
  const bundled = RemoteConfigValues(
    apiBaseUrl: 'https://api.example.test',
    mediaBaseUrl: 'https://media.example.test',
    minSupportedBuild: 0,
    latestBuild: 0,
    livePollIntervalSeconds: 30,
  );

  test('a fetch that says nothing usable keeps every bundled default', () {
    final values = RemoteConfigValues.fromRaw(const {}, bundled: bundled);
    expect(values.apiBaseUrl, bundled.apiBaseUrl);
    expect(values.mediaBaseUrl, bundled.mediaBaseUrl);
    expect(values.minSupportedBuild, 0);
    expect(values.latestBuild, 0);
    expect(values.livePollIntervalSeconds, 30);
  });

  test('hosts are accepted only as https without userinfo, a port or a relative path', () {
    final values = RemoteConfigValues.fromRaw(
      const {
        'api_base_url': 'https://api.madarsat.test',
        'media_base_url': 'https://media.madarsat.test',
      },
      bundled: bundled,
    );
    expect(values.apiBaseUrl, 'https://api.madarsat.test');
    expect(values.mediaBaseUrl, 'https://media.madarsat.test');

    for (final bad in [
      'http://api.madarsat.test',
      'https://user:pass@api.madarsat.test',
      '/v1',
      'javascript:alert(1)',
      '',
    ]) {
      final refused = RemoteConfigValues.fromRaw({'api_base_url': bad}, bundled: bundled);
      expect(refused.apiBaseUrl, bundled.apiBaseUrl, reason: bad);
    }
  });

  test('a min_supported_build above this build asks for the forced update', () {
    final tooOld = RemoteConfigValues.fromRaw(
      {'min_supported_build': '${BuildInfo.buildNumber + 1}'},
      bundled: bundled,
    );
    expect(tooOld.updateRequired, isTrue);

    final fine = RemoteConfigValues.fromRaw(
      {'min_supported_build': '${BuildInfo.buildNumber}'},
      bundled: bundled,
    );
    expect(fine.updateRequired, isFalse);
  });

  test('live_poll_interval_s reaches the poller, and nonsense keeps 30 s', () {
    expect(
      RemoteConfigValues.fromRaw({'live_poll_interval_s': '45'}, bundled: bundled).livePollInterval,
      const Duration(seconds: 45),
    );
    for (final bad in ['0', '5', '9999', 'soon']) {
      expect(
        RemoteConfigValues.fromRaw({'live_poll_interval_s': bad}, bundled: bundled)
            .livePollInterval,
        const Duration(seconds: 30),
        reason: bad,
      );
    }
  });

  group('features', () {
    test('is bundled with live_center and lineups off', () {
      expect(RemoteConfigValues.bundled.features.liveCenter, isFalse);
      expect(RemoteConfigValues.bundled.features.lineups, isFalse);
      final values = RemoteConfigValues.fromRaw(const {}, bundled: bundled);
      expect(values.features, const AppFeatures());
    });

    test('reads each flag on its own from the JSON', () {
      final both = RemoteConfigValues.fromRaw(
        const {'features': '{"live_center": true, "lineups": true}'},
        bundled: bundled,
      );
      expect(both.features, const AppFeatures(liveCenter: true, lineups: true));

      final one = RemoteConfigValues.fromRaw(
        const {'features': '{"live_center": true}'},
        bundled: bundled,
      );
      expect(one.features, const AppFeatures(liveCenter: true));
    });

    test('bad JSON, or a value of the wrong type, keeps the bundle', () {
      const on = RemoteConfigValues(
        apiBaseUrl: 'https://api.example.test',
        mediaBaseUrl: 'https://media.example.test',
        minSupportedBuild: 0,
        latestBuild: 0,
        livePollIntervalSeconds: 30,
        features: AppFeatures(liveCenter: true, lineups: true),
      );
      for (final bad in ['', 'true', '[]', 'null', '{live_center: false}', '{"live_center": false']) {
        expect(
          RemoteConfigValues.fromRaw({'features': bad}, bundled: on).features,
          on.features,
          reason: bad,
        );
      }
      // One bad flag does not take the good one with it.
      final mixed = RemoteConfigValues.fromRaw(
        const {'features': '{"live_center": "false", "lineups": false}'},
        bundled: on,
      );
      expect(mixed.features, const AppFeatures(liveCenter: true));
    });
  });

  test('the bundled value is the flavor file\'s own host', () {
    // No dart-define in a test, so the bundled host is empty; the app refuses to start on it
    // rather than guessing one.
    expect(RemoteConfigValues.bundled.apiBaseUrl, '');
    expect(RemoteConfigValues.bundled.updateRequired, isFalse);
    expect(
      RemoteConfigValues.bundled.livePollInterval,
      const Duration(seconds: RemoteConfigValues.defaultLivePollSeconds),
    );
  });
}
