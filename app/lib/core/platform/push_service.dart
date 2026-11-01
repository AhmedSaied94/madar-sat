import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../config/app_config.dart';
import 'install_guide.dart';

part 'push_service.g.dart';

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

  /// The routes a message opens: `data.route` of a message received in the foreground, or
  /// of the message that launched the app from a notification tap.
  Stream<String> get openedRoutes;
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
  Stream<String> get openedRoutes => const Stream.empty();
}

/// The `firebase_messaging` calls [FirebasePushService] makes, as an interface.
///
/// T118's test file exists because of this seam: without it every case of the service needs
/// a real Firebase app, and none of them would ever be written. Only this file touches the
/// plugin.
abstract interface class PushMessaging {
  Future<AuthorizationStatus> requestPermission();

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
  })  : _guide = guide ?? createInstallGuide(),
        _messaging = messaging ?? const FirebasePushMessaging(),
        _isWeb = isWeb ?? kIsWeb,
        _vapidKey = vapidKey ?? AppConfig.firebaseVapidKey;

  final InstallGuide _guide;
  final PushMessaging _messaging;
  final bool _isWeb;
  final String _vapidKey;

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
  /// (M-R1-2).
  @override
  Future<String?> currentToken() async {
    final registered = Completer<String?>();
    final subscription = _messaging.onRegistered.listen((String id) {
      if (!registered.isCompleted) registered.complete(id);
    });
    try {
      await _messaging.register(vapidKey: _isWeb && _vapidKey.isNotEmpty ? _vapidKey : null);
      return await registered.future.timeout(const Duration(seconds: 10));
    } on Object {
      // No APNs token yet on an iPhone, no permission, or the service worker is not
      // registered: the next registration brings it.
      return null;
    } finally {
      await subscription.cancel();
    }
  }

  @override
  Stream<String?> get tokenChanges =>
      _messaging.onRegistered.map<String?>((String id) => id).distinct();

  @override
  Stream<String> get openedRoutes => Stream<String>.multi((controller) {
        final subscriptions = [
          _messaging.onMessageOpenedApp.listen((message) => _addRoute(controller, message)),
          _messaging.onMessage.listen((message) => _addRoute(controller, message)),
        ];
        controller.onCancel = () async {
          for (final subscription in subscriptions) {
            await subscription.cancel();
          }
        };
        if (_isWeb) return;
        unawaited(
          _messaging.getInitialMessage.then((message) {
            if (message != null) _addRoute(controller, message);
          }),
        );
      }, isBroadcast: false);

  static void _addRoute(MultiStreamController<String> controller, RemoteMessage message) {
    final route = message.data['route'];
    if (route is String && route.startsWith('/')) controller.add(route);
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
