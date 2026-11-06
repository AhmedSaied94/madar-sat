/// The app's version and build number, as S16's about card and S0's forced-update screen
/// show them.
///
/// Nothing reads the manifest at run time (no `package_info_plus` in the fixed stack), so a
/// release build is told both by its workflow: `app-release.yml` and `pwa.yml` pass
/// `--dart-define=APP_VERSION=<x.y.z>` and `--dart-define=APP_BUILD_NUMBER=<run number>`. Any
/// other build falls back to `pubspec.yaml`'s `version:` line, and
/// `test/core/config/build_info_test.dart` fails when these defaults disagree with it.
abstract final class BuildInfo {
  static const String version = String.fromEnvironment('APP_VERSION', defaultValue: '1.0.0');

  /// The build number the forced update compares with `min_supported_build`.
  static const int buildNumber = int.fromEnvironment('APP_BUILD_NUMBER', defaultValue: 1);

  /// «1.0.0 (1)» — Western digits, isolated as a Latin island by the widget that shows it.
  static String get label => '$version ($buildNumber)';
}
