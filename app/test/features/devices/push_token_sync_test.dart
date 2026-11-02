import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madar_sat/core/db/app_database.dart';
import 'package:madar_sat/core/db/database_provider.dart';
import 'package:madar_sat/core/platform/push_service.dart';
import 'package:madar_sat/core/platform/secure_store.dart';
import 'package:madar_sat/features/devices/data/push_token_sync.dart';

/// In-memory secure storage: the two tokens, counted so a test can prove a value is written
/// once per change and that one key is never mistaken for the other.
class _FakeSecureStore implements SecureStore {
  final Map<String, String> values = {};
  final Map<String, int> writes = {};

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async {
    values[key] = value;
    writes[key] = (writes[key] ?? 0) + 1;
  }

  @override
  Future<void> delete(String key) async {
    values.remove(key);
  }
}

class _FakePushService implements PushService {
  _FakePushService(this._token);

  String? _token;
  final StreamController<String?> _changes = StreamController<String?>.broadcast();

  @override
  bool get canRequestPermission => true;

  @override
  Future<bool> requestPermission() async => true;

  @override
  Future<String?> currentToken() async => _token;

  @override
  Stream<String?> get tokenChanges => _changes.stream;

  @override
  Stream<String> get openedRoutes => const Stream.empty();

  void rotate(String? token) {
    _token = token;
    _changes.add(token);
  }
}

/// The push id and the device token are two different things (M-R1-2, research R27, US2
/// scenario 7): FCM's installation id is kept under its own key and sent in
/// `PUT /v1/devices/me`'s body; `Authorization: Device` always carries the server's token.
void main() {
  late AppDatabase database;
  late _FakeSecureStore store;
  late _FakePushService push;
  late ProviderContainer container;

  setUp(() {
    database = AppDatabase(NativeDatabase.memory(), now: () => DateTime.utc(2026, 11, 1, 9));
    store = _FakeSecureStore();
    push = _FakePushService(null);
    container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(database),
        secureStoreProvider.overrideWithValue(store),
        pushServiceProvider.overrideWithValue(push),
      ],
    );
    addTearDown(() async {
      container.dispose();
      await database.close();
    });
  });

  test('the first push token is stored under its own key and flags the device', () async {
    push.rotate('fcm-1');
    container.listen(pushTokenSyncProvider, (_, _) {});
    await container.read(pushTokenSyncProvider.future);
    await pumpEventQueue();

    expect(store.values[SecureKeys.pushToken], 'fcm-1');
    expect(store.writes[SecureKeys.pushToken], 1);
    expect(store.values[SecureKeys.deviceToken], isNull, reason: 'the FCM id is not a token');
    expect((await database.readSyncState('device'))!.dirty, isTrue);
  });

  test('a rotated token is written once, and repeating it writes nothing', () async {
    push.rotate('fcm-1');
    container.listen(pushTokenSyncProvider, (_, _) {});
    await container.read(pushTokenSyncProvider.future);
    await pumpEventQueue();

    push.rotate('fcm-2');
    await pumpEventQueue();
    push.rotate('fcm-2');
    await pumpEventQueue();

    expect(store.values[SecureKeys.pushToken], 'fcm-2');
    expect(store.writes[SecureKeys.pushToken], 2);
  });

  test('a push event never overwrites the server-issued device token', () async {
    store.values[SecureKeys.deviceToken] = 'srv-token';
    push.rotate('fcm-1');
    container.listen(pushTokenSyncProvider, (_, _) {});
    await container.read(pushTokenSyncProvider.future);
    await pumpEventQueue();

    expect(store.values[SecureKeys.deviceToken], 'srv-token');
    expect(store.writes[SecureKeys.deviceToken], isNull, reason: 'never written by push');
    expect(store.values[SecureKeys.pushToken], 'fcm-1');
  });

  test('no token at all writes nothing', () async {
    container.listen(pushTokenSyncProvider, (_, _) {});
    await container.read(pushTokenSyncProvider.future);
    await pumpEventQueue();

    expect(store.values, isEmpty);
    expect(await database.readSyncState('device'), isNull);
  });
}
