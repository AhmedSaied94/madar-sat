/// Bundled flavor defaults (research R16) and the Firebase identifiers every build carries
/// as `--dart-define-from-file=env/<flavor>.json` (research R25, R28).
///
/// Public values only: hosts and Firebase identifiers, never a key that grants access. A
/// build with no file must not guess a host, hence [isConfigured].
abstract final class AppConfig {
  static const String apiBaseUrl = String.fromEnvironment('API_BASE_URL');

  static const String mediaBaseUrl = String.fromEnvironment('MEDIA_BASE_URL');

  // The public Firebase identifiers. One app id per platform, because a Firebase project
  // registers its web, Android and iOS apps separately (R25); the key is the public web
  // key, also used by the Android/iOS SDKs unless a per-platform one is given.
  static const String firebaseApiKey = String.fromEnvironment('FIREBASE_API_KEY');
  static const String firebaseProjectId = String.fromEnvironment('FIREBASE_PROJECT_ID');
  static const String firebaseMessagingSenderId =
      String.fromEnvironment('FIREBASE_MESSAGING_SENDER_ID');
  static const String firebaseAuthDomain = String.fromEnvironment('FIREBASE_AUTH_DOMAIN');
  static const String firebaseStorageBucket = String.fromEnvironment('FIREBASE_STORAGE_BUCKET');
  static const String firebaseWebAppId = String.fromEnvironment('FIREBASE_WEB_APP_ID');
  static const String firebaseAndroidAppId = String.fromEnvironment('FIREBASE_ANDROID_APP_ID');
  static const String firebaseIosAppId = String.fromEnvironment('FIREBASE_IOS_APP_ID');

  /// The Web Push certificate key pair's public half (R26). Public by design; the private
  /// half never leaves the Firebase console.
  static const String firebaseVapidKey = String.fromEnvironment('FIREBASE_VAPID_KEY');

  /// The public links S15/S16 show, supplied by the flavor file once the owner has them
  /// (privacy policy, the app's own share address). Empty means the row is not drawn: the
  /// app never invents a policy address or a store link.
  static const String privacyUrl = String.fromEnvironment('PRIVACY_URL');
  static const String shareUrl = String.fromEnvironment('SHARE_URL');

  /// A build with no `--dart-define-from-file` must not guess a host.
  static bool get isConfigured => apiBaseUrl.isNotEmpty && mediaBaseUrl.isNotEmpty;

  /// True when the flavor file carries enough identifiers to start Firebase. A build
  /// without them still runs: push, Remote Config and Crashlytics are simply absent, which
  /// is what a local `flutter run` without a project does.
  static bool get isFirebaseConfigured =>
      firebaseApiKey.isNotEmpty &&
      firebaseProjectId.isNotEmpty &&
      firebaseMessagingSenderId.isNotEmpty &&
      (firebaseWebAppId.isNotEmpty ||
          firebaseAndroidAppId.isNotEmpty ||
          firebaseIosAppId.isNotEmpty);

  static void ensureConfigured() {
    if (!isConfigured) {
      throw StateError(
        'API_BASE_URL and MEDIA_BASE_URL must be passed with '
        '--dart-define-from-file=env/<flavor>.json',
      );
    }
  }
}
