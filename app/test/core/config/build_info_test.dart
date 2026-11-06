import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:madar_sat/core/config/build_info.dart';

/// A build that isn't given a version falls back to `pubspec.yaml`'s, which [BuildInfo] repeats
/// because nothing reads the manifest at run time. The release workflows give it the real one.
/// S16's about card and S0's forced update both show it.
void main() {
  test('without a version from the build, BuildInfo repeats pubspec.yaml', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final match = RegExp(r'^version:\s*(\d+)\.(\d+)\.(\d+)\+(\d+)\s*$', multiLine: true)
        .firstMatch(pubspec);
    expect(match, isNotNull, reason: 'pubspec.yaml has no version: x.y.z+n line');
    final version = '${match!.group(1)}.${match.group(2)}.${match.group(3)}';
    final build = int.parse(match.group(4)!);
    expect(BuildInfo.version, version, reason: 'update lib/core/config/build_info.dart');
    expect(BuildInfo.buildNumber, build, reason: 'update lib/core/config/build_info.dart');
    expect(BuildInfo.label, '$version ($build)');
  });

  // A release build that isn't given these reports pubspec's values, so every phone looks like
  // build 1 and raising `min_supported_build` above 1 blocks even the newest build.
  for (final workflow in const ['app-release.yml', 'pwa.yml']) {
    test('$workflow gives the build its version and build number', () {
      final file = File('../.github/workflows/$workflow');
      if (!file.existsSync()) {
        markTestSkipped('$workflow is not synced to this checkout; CI has it');
        return;
      }
      final text = file.readAsStringSync();
      expect(text, contains('--dart-define=APP_VERSION='));
      expect(text, contains('--dart-define=APP_BUILD_NUMBER='));
    });
  }
}
