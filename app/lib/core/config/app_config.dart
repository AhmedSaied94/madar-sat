/// Bundled flavor defaults (research R16). Public values only; Remote Config takes over on D3.
abstract final class AppConfig {
  static const String apiBaseUrl = String.fromEnvironment('API_BASE_URL');

  static const String mediaBaseUrl = String.fromEnvironment('MEDIA_BASE_URL');

  /// A build with no `--dart-define-from-file` must not guess a host.
  static bool get isConfigured => apiBaseUrl.isNotEmpty && mediaBaseUrl.isNotEmpty;

  static void ensureConfigured() {
    if (!isConfigured) {
      throw StateError(
        'API_BASE_URL and MEDIA_BASE_URL must be passed with '
        '--dart-define-from-file=env/<flavor>.json',
      );
    }
  }
}
