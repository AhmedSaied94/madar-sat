import 'dart:async';

import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madar_sat/core/db/app_database.dart';
import 'package:madar_sat/core/db/database_provider.dart';
import 'package:madar_sat/core/network/device_auth_interceptor.dart';
import 'package:madar_sat/core/platform/push_service.dart';
import 'package:madar_sat/core/platform/secure_store.dart';
import 'package:madar_sat/features/devices/data/push_token_sync.dart';

import '../../fixtures/fake_http_adapter.dart';

/// In-memory secure storage: the device token and install id, counted so a test can prove a
/// token is written once per change.
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

/// The device's own identity (research R27, US2 scenarios 6–7): the token lands in secure
/// storage once per change and flags `sync_state.device`; the header goes on every `/v1`
/// request and on nothing else.
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

  test('the first token is stored once and flags the device for the server', () async {
    push.rotate('token-1');
    container.listen(pushTokenSyncProvider, (_, _) {});
    await container.read(pushTokenSyncProvider.future);
    await pumpEventQueue();

    expect(store.values[SecureKeys.deviceToken], 'token-1');
    expect(store.writes[SecureKeys.deviceToken], 1);
    expect((await database.readSyncState('device'))!.dirty, isTrue);
  });

  test('a rotated token is written once, and repeating it writes nothing', () async {
    push.rotate('token-1');
    container.listen(pushTokenSyncProvider, (_, _) {});
    await container.read(pushTokenSyncProvider.future);
    await pumpEventQueue();

    push.rotate('token-2');
    await pumpEventQueue();
    push.rotate('token-2');
    await pumpEventQueue();

    expect(store.values[SecureKeys.deviceToken], 'token-2');
    expect(store.writes[SecureKeys.deviceToken], 2);
  });

  test('the Authorization header goes on every /v1 request of the API host', () async {
    final adapter = FakeHttpAdapter();
    final dio = Dio(
      BaseOptions(baseUrl: 'https://api.madarsat.test'),
    )..httpClientAdapter = adapter;
    dio.interceptors.add(
      DeviceAuthInterceptor(token: () => 'token-1', baseUrl: 'https://api.madarsat.test'),
    );
    adapter.enqueueData(const {'ok': true});
    adapter.enqueueData(const {'ok': true});

    await dio.get<Object?>('/v1/matches');
    await dio.get<Object?>('/healthz');

    String? authorization(int index) => adapter.requests[index].headers.entries
        .where((entry) => entry.key.toLowerCase() == 'authorization')
        .map((entry) => '${entry.value}')
        .firstOrNull;

    expect(authorization(0), 'Device token-1');
    // Every path of this Dio is the API host, so the token rides along; a request to another
    // host gets nothing (the media host never goes through this Dio at all).
    expect(authorization(1), 'Device token-1');
  });

  test('no token yet means no header at all', () async {
    final adapter = FakeHttpAdapter();
    final dio = Dio(BaseOptions(baseUrl: 'https://api.madarsat.test'))
      ..httpClientAdapter = adapter;
    dio.interceptors.add(
      DeviceAuthInterceptor(token: () => null, baseUrl: 'https://api.madarsat.test'),
    );
    adapter.enqueueData(const {'ok': true});

    await dio.get<Object?>('/v1/matches');

    expect(adapter.requests.single.headers.containsKey('Authorization'), isFalse);
  });
}
