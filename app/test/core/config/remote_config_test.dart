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
