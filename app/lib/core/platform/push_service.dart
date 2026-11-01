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

/// `firebase_messaging` for Android, iOS and the web.
class FirebasePushService implements PushService {
  FirebasePushService({InstallGuide? guide}) : _guide = guide ?? createInstallGuide();

  static FirebaseMessaging get _messaging => FirebaseMessaging.instance;

  final InstallGuide _guide;

  @override
  bool get canRequestPermission => !_guide.needsInstallSteps;

  @override
  Future<bool> requestPermission() async {
    if (!canRequestPermission) return false;
    if (kIsWeb && AppConfig.firebaseVapidKey.isEmpty) return false;
    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    return settings.authorizationStatus == AuthorizationStatus.authorized ||
        settings.authorizationStatus == AuthorizationStatus.provisional;
  }

  /// The Firebase installation id registered for this app instance: FCM's direct-send
  /// target, which is what `push_token` carries (the plugin's `register()`/`onRegistered`
  /// pair replaced the FCM token API in v17).
  @override
  Future<String?> currentToken() async {
    final registered = Completer<String?>();
    final subscription = _messaging.onRegistered.listen((String id) {
      if (!registered.isCompleted) registered.complete(id);
    });
    try {
      await _messaging.register(
        vapidKey: kIsWeb && AppConfig.firebaseVapidKey.isNotEmpty
            ? AppConfig.firebaseVapidKey
            : null,
      );
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
  Stream<String?> get tokenChanges => _messaging.onRegistered.map<String?>((String id) => id);

  @override
  Stream<String> get openedRoutes => Stream<String>.multi((controller) {
        final subscriptions = [
          FirebaseMessaging.onMessageOpenedApp.listen((message) => _addRoute(controller, message)),
          FirebaseMessaging.onMessage.listen((message) => _addRoute(controller, message)),
        ];
        controller.onCancel = () async {
          for (final subscription in subscriptions) {
            await subscription.cancel();
          }
        };
        if (kIsWeb) return;
        unawaited(
          _messaging.getInitialMessage().then((message) {
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
