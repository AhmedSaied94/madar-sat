import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import '../config/app_config.dart';
import 'crash_reporter.dart';

/// Starts Firebase from the flavor's public identifiers (research R25): no
/// `google-services.json` and no generated `firebase_options.dart`, so `env/<flavor>.json`
/// stays the one source of the values.
///
/// A build without identifiers (a local `flutter run`, CI's widget tests) skips it and runs
/// with no push, no Remote Config and no Crashlytics. Nothing here throws: an app that
/// cannot reach Firebase must still open.
abstract final class FirebaseBootstrap {
  static bool _started = false;

  static bool get started => _started;

  static Future<void> start() async {
    if (_started || !AppConfig.isFirebaseConfigured) return;
    try {
      await Firebase.initializeApp(options: options());
    } on Object catch (error) {
      // A bad identifier or no network at start: the bundled defaults stand (R28).
      debugPrint('Firebase did not start: $error');
      return;
    }
    _started = true;
    createCrashReporter(firebaseConfigured: true).install();
  }

  /// The public identifiers for the platform this build runs on. Each Firebase project
  /// registers one app id per platform.
  static FirebaseOptions options() => FirebaseOptions(
        apiKey: AppConfig.firebaseApiKey,
        appId: _appId,
        messagingSenderId: AppConfig.firebaseMessagingSenderId,
        projectId: AppConfig.firebaseProjectId,
        authDomain: AppConfig.firebaseAuthDomain.isEmpty ? null : AppConfig.firebaseAuthDomain,
        storageBucket:
            AppConfig.firebaseStorageBucket.isEmpty ? null : AppConfig.firebaseStorageBucket,
      );

  static String get _appId {
    if (kIsWeb) return AppConfig.firebaseWebAppId;
    if (defaultTargetPlatform == TargetPlatform.android) {
      return AppConfig.firebaseAndroidAppId.isNotEmpty
          ? AppConfig.firebaseAndroidAppId
          : AppConfig.firebaseIosAppId;
    }
    return AppConfig.firebaseIosAppId.isNotEmpty
        ? AppConfig.firebaseIosAppId
        : AppConfig.firebaseAndroidAppId;
  }
}
