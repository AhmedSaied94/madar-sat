import 'dart:developer' as developer;

import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';

import 'crash_reporter.dart';

/// Crashlytics on the native builds (research R25). The plugin is not initialised on the
/// web, where this class is never compiled; the conditional import in
/// `crash_reporter.dart` picks the no-op there instead.
class FirebaseCrashReporter implements CrashReporter {
  FirebaseCrashReporter();

  static final FirebaseCrashlytics _crashlytics = FirebaseCrashlytics.instance;

  @override
  bool get isEnabled => true;

  @override
  void recordError(Object error, StackTrace? stackTrace, {bool fatal = false}) {
    _crashlytics.recordError(error, stackTrace, fatal: fatal);
  }

  @override
  void log(String message) => _crashlytics.log(message);

  @override
  void install() {
    FlutterError.onError = (details) {
      _crashlytics.recordFlutterFatalError(details);
      FlutterError.presentError(details);
    };
    PlatformDispatcher.instance.onError = (error, stackTrace) {
      _crashlytics.recordError(error, stackTrace, fatal: true);
      return true;
    };
  }
}

/// A native build with no Firebase project: errors go to the developer log only.
class ConsoleCrashReporter implements CrashReporter {
  const ConsoleCrashReporter();

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
    firebaseConfigured ? FirebaseCrashReporter() : const ConsoleCrashReporter();
