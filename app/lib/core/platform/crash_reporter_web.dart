import 'dart:developer' as developer;

import 'crash_reporter.dart';

/// The web has no crash reporter in the fixed stack (research R25, contract app-screens):
/// a caught error is logged for the developer tools and nothing leaves the browser.
class WebCrashReporter implements CrashReporter {
  const WebCrashReporter();

  @override
  bool get isEnabled => false;

  @override
  void recordError(Object error, StackTrace? stackTrace, {bool fatal = false}) => developer.log(
        fatal ? 'fatal error' : 'error',
        name: 'madar.crash',
        error: error,
        stackTrace: stackTrace,
      );

  @override
  void log(String message) => developer.log(message, name: 'madar.crash');

  @override
  void install() {}
}

CrashReporter platformCrashReporter({required bool firebaseConfigured}) =>
    const WebCrashReporter();
