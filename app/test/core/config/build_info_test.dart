import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:madar_sat/core/config/build_info.dart';

/// `pubspec.yaml` is the release's version; [BuildInfo] repeats it because nothing reads the
/// manifest at run time. This test is what keeps the two from drifting apart (S16's about
/// card and S0's forced update both show it).
void main() {
  test('BuildInfo repeats pubspec.yaml\'s version and build number', () {
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
}
