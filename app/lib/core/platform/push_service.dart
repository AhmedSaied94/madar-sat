import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../config/app_config.dart';
import 'crash_reporter.dart';
import 'firebase_bootstrap.dart';
import 'install_guide.dart';
import 'push_routes.dart';

part 'push_service.g.dart';

/// What the platform says about notifications for this app (S15's platform state).
///
/// Named apart from the [PushPermission] provider below. The no-Google-Play state that
/// constitution 1.4.0 adds for S15 becomes one more case here.
enum PushPermissionState {
  /// Granted, so pushes can show.
  allowed,

  /// Refused: only the device's settings can change it, on most platforms.
  denied,

  /// Never asked, for example after «ليس الآن» in S1.4. The prompt can still appear.
  notAsked,
}

/// A push received while the app is open. It shows a banner and moves nothing (FR-059).
@immutable
class ForegroundPush {
  const ForegroundPush({required this.title, required this.body, this.route});

  final String title;
  final String body;

  /// Where «عرض» goes, or null when the message names no route this build knows.
  final PushRoute? route;
}

/// Push on Android and the web behind one interface (research R25, R26, contract
/// app-screens). Feature code never imports `firebase_messaging`: it asks this, and the
/// tests answer with [NoPushService] or a fake.
abstract interface class PushService {
  /// Whether the platform may still show the prompt. False on an iPhone whose PWA is not
  /// installed, where S1.4 shows S1.5 instead (R26).
  bool get canRequestPermission;

  /// Asks for permission. Only ever called from a user action: iOS and the browser require
  /// the prompt to come from a tap (R26).
  Future<bool> requestPermission();

  /// The current FCM token, or null while none exists (no permission, no network, an
  /// iPhone without APNs).
  Future<String?> currentToken();

  /// Each new token, so it reaches `PUT /v1/devices/me` once per change (US2 scenario 7).
  Stream<String?> get tokenChanges;

  /// The platform's answer right now. It never prompts.
  Future<PushPermissionState> permission();

  /// The routes a tapped notification opens: `data.route` of a message tapped in the
  /// background, or of the one that launched the app. Only known shapes come through.
  Stream<String> get openedRoutes;

  /// Messages received while the app is open.
  Stream<ForegroundPush> get foregroundMessages;
}

/// The answer on a build with no Firebase identifiers: every method is a no-op, so the app
/// still runs and the onboarding step simply cannot be granted.
class NoPushService implements PushService {
  const NoPushService();

  @override
  bool get canRequestPermission => false;

  @override
  Future<bool> requestPermission() async => false;

  @override
  Future<String?> currentToken() async => null;

  @override
  Stream<String?> get tokenChanges => const Stream.empty();

  @override
  Future<PushPermissionState> permission() async => PushPermissionState.denied;

  @override
  Stream<String> get openedRoutes => const Stream.empty();

  @override
  Stream<ForegroundPush> get foregroundMessages => const Stream.empty();
}

/// The `firebase_messaging` calls [FirebasePushService] makes, as an interface.
///
/// T118's test file exists because of this seam: without it every case of the service needs
/// a real Firebase app, and none of them would ever be written. Only this file touches the
/// plugin.
abstract interface class PushMessaging {
  Future<AuthorizationStatus> requestPermission();

  /// The current answer, without prompting.
  Future<AuthorizationStatus> permission();

  /// Registers for push; the id arrives on [onRegistered] (plugin v17 replaced the FCM
  /// token API with this pair).
  Future<void> register({String? vapidKey});

  Stream<String> get onRegistered;

  Stream<RemoteMessage> get onMessage;

  Stream<RemoteMessage> get onMessageOpenedApp;

  Future<RemoteMessage?> get getInitialMessage;
}

/// The plugin behind [PushMessaging].
class FirebasePushMessaging implements PushMessaging {
  const FirebasePushMessaging();

  static FirebaseMessaging get _messaging => FirebaseMessaging.instance;

  @override
  Future<AuthorizationStatus> requestPermission() async {
    final settings = await _messaging.requestPermission(alert: true, badge: true, sound: true);
    return settings.authorizationStatus;
  }

  @override
  Future<AuthorizationStatus> permission() async =>
      (await _messaging.getNotificationSettings()).authorizationStatus;

  @override
  Future<void> register({String? vapidKey}) => _messaging.register(vapidKey: vapidKey);

  @override
  Stream<String> get onRegistered => _messaging.onRegistered;

  @override
  Stream<RemoteMessage> get onMessage => FirebaseMessaging.onMessage;

  @override
  Stream<RemoteMessage> get onMessageOpenedApp => FirebaseMessaging.onMessageOpenedApp;

  @override
  Future<RemoteMessage?> get getInitialMessage => _messaging.getInitialMessage();
}

/// `firebase_messaging` for Android, iOS and the web.
class FirebasePushService implements PushService {
  FirebasePushService({
    InstallGuide? guide,
    PushMessaging? messaging,
    bool? isWeb,
    String? vapidKey,
    this._registrationTimeout = const Duration(seconds: 10),
    void Function(Object error, StackTrace stackTrace)? onRegistrationFailed,
  }) : _guide = guide ?? createInstallGuide(),
       _messaging = messaging ?? const FirebasePushMessaging(),
       _isWeb = isWeb ?? kIsWeb,
       _vapidKey = vapidKey ?? AppConfig.firebaseVapidKey,
       _onRegistrationFailed = onRegistrationFailed ?? _reportRegistrationFailure;

  final InstallGuide _guide;
  final PushMessaging _messaging;
  final bool _isWeb;
  final String _vapidKey;
  final Duration _registrationTimeout;
  final void Function(Object error, StackTrace stackTrace) _onRegistrationFailed;

  /// To the log and, on a native build, to Crashlytics. On the server a device that failed
  /// to register looks like any other device without a token, so this is the only trace.
  static void _reportRegistrationFailure(Object error, StackTrace stackTrace) {
    debugPrint('Push registration failed: $error');
    if (!FirebaseBootstrap.started) return;
    createCrashReporter(firebaseConfigured: true).recordError(error, stackTrace);
  }

  @override
  bool get canRequestPermission => !_guide.needsInstallSteps;

  @override
  Future<bool> requestPermission() async {
    if (!canRequestPermission) return false;
    if (_isWeb && _vapidKey.isEmpty) return false;
    final status = await _messaging.requestPermission();
    return status == AuthorizationStatus.authorized || status == AuthorizationStatus.provisional;
  }

  /// The Firebase installation id registered for this app instance: FCM's direct-send
  /// target, which is what `push_token` carries. It is **not** the device's auth token
  /// (M-R1-2). Android reports it only with `firebase_messaging_installation_id_enabled` on
  /// in the manifest.
  @override
  Future<String?> currentToken() async {
    final registered = Completer<String?>();
    StreamSubscription<String>? subscription;
    try {
      subscription = _messaging.onRegistered.listen((String id) {
        if (!registered.isCompleted) registered.complete(id);
      });
      await _messaging.register(vapidKey: _isWeb && _vapidKey.isNotEmpty ? _vapidKey : null);
      return await registered.future.timeout(_registrationTimeout);
    } on Object catch (error, stackTrace) {
      // No APNs token yet on an iPhone, no permission, or the service worker is not
      // registered: the next registration brings it. Reported all the same, as the same
      // answer also hides a device that can never register.
      _onRegistrationFailed(error, stackTrace);
      return null;
    } finally {
      await subscription?.cancel();
    }
  }

  @override
  Stream<String?> get tokenChanges =>
      _messaging.onRegistered.map<String?>((String id) => id).distinct();

  @override
  Future<PushPermissionState> permission() async => switch (await _messaging.permission()) {
    AuthorizationStatus.authorized || AuthorizationStatus.provisional => PushPermissionState.allowed,
    AuthorizationStatus.denied || AuthorizationStatus.deniedPermanently => PushPermissionState.denied,
    AuthorizationStatus.notDetermined => PushPermissionState.notAsked,
  };

  @override
  Stream<String> get openedRoutes => Stream<String>.multi((controller) {
    final subscription = _messaging.onMessageOpenedApp.listen(
      (message) => _addRoute(controller, message),
    );
    controller.onCancel = subscription.cancel;
    if (_isWeb) return;
    unawaited(
      _messaging.getInitialMessage.then((message) {
        if (message != null) _addRoute(controller, message);
      }),
    );
  }, isBroadcast: false);

  @override
  Stream<ForegroundPush> get foregroundMessages =>
      _messaging.onMessage.map(_foregroundPush).where((push) => push != null).cast<ForegroundPush>();

  static void _addRoute(MultiStreamController<String> controller, RemoteMessage message) {
    final route = _routeOf(message);
    if (route != null) controller.add(route.location);
  }

  static PushRoute? _routeOf(RemoteMessage message) {
    final route = message.data['route'];
    return route is String ? parsePushRoute(route) : null;
  }

  /// A data-only message has nothing to show, so it's dropped.
  static ForegroundPush? _foregroundPush(RemoteMessage message) {
    final title = message.notification?.title ?? '';
    final body = message.notification?.body ?? '';
    if (title.isEmpty && body.isEmpty) return null;
    return ForegroundPush(title: title, body: body, route: _routeOf(message));
  }
}

/// The service in force.
@Riverpod(keepAlive: true)
PushService pushService(Ref ref) =>
    AppConfig.isFirebaseConfigured ? FirebasePushService() : const NoPushService();

/// Whether notifications were granted on this device. Set by the onboarding step and read
/// by S15; the OS remains the authority, this only mirrors the last answer.
@Riverpod(keepAlive: true)
class PushPermission extends _$PushPermission {
  @override
  bool build() => false;

  void set(bool granted) => state = granted;
}
