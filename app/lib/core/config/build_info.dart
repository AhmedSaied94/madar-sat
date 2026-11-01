/// The app's version and build number, as S16's about card and S0's forced-update screen
/// show them.
///
/// They repeat `pubspec.yaml`'s `version:` line, because nothing reads the manifest at run
/// time (no `package_info_plus` in the fixed stack). `test/core/config/build_info_test.dart`
/// fails when the two disagree, so a release that forgets this file cannot ship.
abstract final class BuildInfo {
  static const String version = '1.0.0';

  /// The build number the forced update compares with `min_supported_build`. It defaults to
  /// the one this file repeats from `pubspec.yaml`; a release pipeline may pass the version
  /// code it actually built with `--dart-define=APP_BUILD_NUMBER=<n>`.
  static const int buildNumber = int.fromEnvironment('APP_BUILD_NUMBER', defaultValue: 1);

  /// «1.0.0 (1)» — Western digits, isolated as a Latin island by the widget that shows it.
  static String get label => '$version ($buildNumber)';
}
