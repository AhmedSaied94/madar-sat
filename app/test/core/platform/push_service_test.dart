import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madar_sat/core/platform/install_guide.dart';
import 'package:madar_sat/core/platform/push_service.dart';

/// A browser/OS answer, scripted: what `firebase_messaging` would say.
class _FakeMessaging implements PushMessaging {
  AuthorizationStatus permissionAnswer = AuthorizationStatus.authorized;

  /// What `permission()` answers.
  AuthorizationStatus permissionNow = AuthorizationStatus.notDetermined;

  final List<String?> registeredWith = [];
  final StreamController<String> registered = StreamController<String>.broadcast();
  final StreamController<RemoteMessage> foreground = StreamController<RemoteMessage>.broadcast();
  final StreamController<RemoteMessage> opened = StreamController<RemoteMessage>.broadcast();
  RemoteMessage? initial;

  int permissionCalls = 0;

  /// What the next [register] call throws, as FCM does when it cannot register.
  Object? registerError;

  @override
  Future<AuthorizationStatus> requestPermission() async {
    permissionCalls += 1;
    return permissionAnswer;
  }

  @override
  Future<AuthorizationStatus> permission() async => permissionNow;

  @override
  Future<void> register({String? vapidKey}) async {
    registeredWith.add(vapidKey);
    final error = registerError;
    if (error != null) throw error;
    // The plugin answers on `onRegistered`; the fake answers at once with `id`.
    final id = _nextId;
    if (id != null) scheduleMicrotask(() => registered.add(id));
  }

  String? _nextId;

  /// The id the next [register] call reports, as FCM does on a real device.
  void willReport(String id) => _nextId = id;

  @override
  Stream<String> get onRegistered => registered.stream;

  @override
  Stream<RemoteMessage> get onMessage => foreground.stream;

  @override
  Stream<RemoteMessage> get onMessageOpenedApp => opened.stream;

  @override
  Future<RemoteMessage?> get getInitialMessage async => initial;
}

class _Guide implements InstallGuide {
  _Guide({this.isWeb = false, this.isInstalled = true, this.needsInstallSteps = false});

  @override
  final bool isWeb;

  @override
  final bool isInstalled;

  @override
  final bool needsInstallSteps;
}

/// `FirebasePushService` behind its seam (T118, FR-053, spec scenarios 5 and 7): the prompt
/// only from a real user action, the iPhone-not-installed rule, the empty-VAPID guard, a
/// token per change, and a message's `route`.
void main() {
  late _FakeMessaging messaging;

  setUp(() => messaging = _FakeMessaging());

  FirebasePushService service({
    InstallGuide? guide,
    bool isWeb = false,
    String vapidKey = 'vapid-key',
    Duration registrationTimeout = const Duration(seconds: 10),
    void Function(Object error, StackTrace stackTrace)? onRegistrationFailed,
  }) => FirebasePushService(
    guide: guide ?? _Guide(),
    messaging: messaging,
    isWeb: isWeb,
    vapidKey: vapidKey,
    registrationTimeout: registrationTimeout,
    onRegistrationFailed: onRegistrationFailed,
  );

  test('an iPhone PWA that is not installed cannot ask for permission', () async {
    final push = service(guide: _Guide(isWeb: true, isInstalled: false, needsInstallSteps: true));

    expect(push.canRequestPermission, isFalse);
    expect(await push.requestPermission(), isFalse);
    expect(messaging.permissionCalls, 0, reason: 'the prompt needs an installed PWA first');
  });

  test('the web refuses an empty VAPID key before prompting', () async {
    final push = service(isWeb: true, vapidKey: '');

    expect(await push.requestPermission(), isFalse);
    expect(messaging.permissionCalls, 0);
  });

  test('permission is granted only for authorized or provisional', () async {
    messaging.permissionAnswer = AuthorizationStatus.denied;
    expect(await service().requestPermission(), isFalse);

    messaging.permissionAnswer = AuthorizationStatus.provisional;
    expect(await service().requestPermission(), isTrue);
  });

  test('the current token is the id FCM registered, and the web passes the VAPID key', () async {
    messaging.willReport('fcm-1');

    expect(await service(isWeb: true).currentToken(), 'fcm-1');
    expect(messaging.registeredWith.single, 'vapid-key');
  });

  test('a native build registers without a VAPID key', () async {
    messaging.willReport('fcm-1');

    expect(await service().currentToken(), 'fcm-1');
    expect(messaging.registeredWith.single, isNull);
  });

  test('a registration that works reports no failure', () async {
    final failures = <Object>[];
    messaging.willReport('fcm-1');

    final token = await service(onRegistrationFailed: (error, _) => failures.add(error))
        .currentToken();

    expect(token, 'fcm-1');
    expect(failures, isEmpty);
  });

  test('a registration FCM refuses gives no token, and is reported', () async {
    final failures = <Object>[];
    messaging.registerError = StateError('FIS_AUTH_ERROR');

    final token = await service(onRegistrationFailed: (error, _) => failures.add(error))
        .currentToken();

    expect(token, isNull);
    expect(failures.single, isA<StateError>());
  });

  test('a registration that never answers gives no token, and is reported', () async {
    final failures = <Object>[];

    final token = await service(
      registrationTimeout: Duration.zero,
      onRegistrationFailed: (error, _) => failures.add(error),
    ).currentToken();

    expect(token, isNull);
    expect(failures.single, isA<TimeoutException>());
  });

  test('a token change is reported once, and a repeat is not sent again', () async {
    final tokens = <String?>[];
    final subscription = service().tokenChanges.listen(tokens.add);
    addTearDown(subscription.cancel);

    messaging.registered.add('fcm-1');
    messaging.registered.add('fcm-2');
    messaging.registered.add('fcm-2');
    await pumpEventQueue();

    expect(tokens, ['fcm-1', 'fcm-2']);
  });

  test('permission maps the platform answer, and never prompts', () async {
    const answers = {
      AuthorizationStatus.authorized: PushPermissionState.allowed,
      AuthorizationStatus.provisional: PushPermissionState.allowed,
      AuthorizationStatus.denied: PushPermissionState.denied,
      AuthorizationStatus.deniedPermanently: PushPermissionState.denied,
      AuthorizationStatus.notDetermined: PushPermissionState.notAsked,
    };
    for (final answer in answers.entries) {
      messaging.permissionNow = answer.key;
      expect(await service().permission(), answer.value);
    }
    expect(messaging.permissionCalls, 0);
  });

  test('a foreground message emits no route: it can only show a banner', () async {
    final emitted = <String>[];
    final subscription = service().openedRoutes.listen(emitted.add);
    addTearDown(subscription.cancel);

    messaging.foreground.add(const RemoteMessage(data: {'route': '/match/42'}));
    await pumpEventQueue();

    expect(emitted, isEmpty);
  });

  test('a foreground message reaches the banner with its title, body and route', () async {
    final first = service().foregroundMessages.first;

    messaging.foreground.add(
      const RemoteMessage(
        notification: RemoteNotification(title: 'هدف', body: 'الأهلي 1 – 0'),
        data: {'route': '/match/42'},
      ),
    );

    final push = await first;
    expect(push.title, 'هدف');
    expect(push.body, 'الأهلي 1 – 0');
    expect(push.route?.location, '/match/42');
  });

  test('a foreground message with a route this build refuses has none', () async {
    final first = service().foregroundMessages.first;

    messaging.foreground.add(
      const RemoteMessage(
        notification: RemoteNotification(title: 'هدف'),
        data: {'route': '/evil'},
      ),
    );

    expect((await first).route, isNull);
  });

  test('a foreground message with nothing to show is dropped', () async {
    final emitted = <ForegroundPush>[];
    final subscription = service().foregroundMessages.listen(emitted.add);
    addTearDown(subscription.cancel);

    messaging.foreground.add(const RemoteMessage(data: {'route': '/match/42'}));
    await pumpEventQueue();

    expect(emitted, isEmpty);
  });

  test('a tapped message opens only a route of a known shape', () async {
    final emitted = <String>[];
    final subscription = service().openedRoutes.listen(emitted.add);
    addTearDown(subscription.cancel);

    messaging.opened.add(const RemoteMessage(data: {'route': '/evil'}));
    messaging.opened.add(const RemoteMessage(data: {'no_route': '1'}));
    messaging.opened.add(const RemoteMessage(data: {'route': '/channel/9'}));
    await pumpEventQueue();

    expect(emitted, ['/channel/9']);
  });

  test('on the web the launch message is not read, and the app waits for a tap', () async {
    messaging.initial = const RemoteMessage(data: {'route': '/match/42'});
    final routes = service(isWeb: true).openedRoutes;

    final emitted = <String>[];
    final subscription = routes.listen(emitted.add);
    await pumpEventQueue();
    expect(emitted, isEmpty);

    messaging.opened.add(const RemoteMessage(data: {'route': '/match/7'}));
    await pumpEventQueue();
    await subscription.cancel();

    expect(emitted, ['/match/7']);
  });
}
