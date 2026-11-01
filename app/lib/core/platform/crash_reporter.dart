/// Where a failed operation goes (research R25, constitution VIII): Crashlytics on the
/// native builds, nothing on the web, always behind this interface so a feature never
/// imports `firebase_crashlytics`.
library;

import 'crash_reporter_native.dart'
    if (dart.library.js_interop) 'crash_reporter_web.dart' as platform;

abstract interface class CrashReporter {
  /// True on a platform that records crashes: Android and iOS today, never the web.
  bool get isEnabled;

  /// Records a caught error. [fatal] marks one that ended a session.
  void recordError(Object error, StackTrace? stackTrace, {bool fatal = false});

  /// A breadcrumb that makes the next crash readable.
  void log(String message);

  /// Hooks the framework's own error handlers so an uncaught error is reported too.
  void install();
}

/// The reporter this build uses: Crashlytics when the flavor carries Firebase identifiers,
/// a no-op otherwise (a local build without a Firebase project).
CrashReporter createCrashReporter({required bool firebaseConfigured}) =>
    platform.platformCrashReporter(firebaseConfigured: firebaseConfigured);
