import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madar_sat/core/db/app_database.dart';
import 'package:madar_sat/core/db/database_provider.dart';
import 'package:madar_sat/core/network/api_failure.dart';
import 'package:madar_sat/core/network/device_auth_interceptor.dart';
import 'package:madar_sat/core/network/dio_provider.dart';
import 'package:madar_sat/core/network/generated/export.dart';
import 'package:madar_sat/core/platform/push_service.dart';
import 'package:madar_sat/core/platform/secure_store.dart';
import 'package:madar_sat/core/settings/app_settings.dart';
import 'package:madar_sat/core/settings/settings_providers.dart';
import 'package:madar_sat/features/devices/data/device_identity_provider.dart';
import 'package:madar_sat/features/devices/data/device_repository.dart';
import 'package:madar_sat/features/devices/data/device_sync.dart';
import 'package:madar_sat/features/follows/domain/follow_set.dart' show FollowKind;
import 'package:madar_sat/features/follows/data/follows_repository.dart';

import '../../fixtures/fake_http_adapter.dart';

/// In-memory secure storage.
class _Store implements SecureStore {
  final Map<String, String> values = {};

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async => values[key] = value;

  @override
  Future<void> delete(String key) async => values.remove(key);
}

/// The device's half of the server contract (US2 scenarios 4, 6, 7, 10; FR-041, T114, T115,
/// T133): registration once per install, the device update and the follow sync, each body
/// carrying only the fields the app actually set, and a flag that clears only on success.
void main() {
  const installId = '6f1c0b8e-2d3a-4c8b-9f0e-1a2b3c4d5e6f';
  const registered = {'device_id': 812, 'device_token': 'srv-token'};
  // What `PUT /v1/devices/me` answers: the stored device, every field required.
  const deviceBody = {
    'device_id': 812,
    'platform': 'android',
    'app_version': '1.0.0+1',
    'tz': null,
    'locale': 'ar',
    'satellite_ids': <int>[3, 7],
    'has_push_token': true,
    'prefs': <String, Object?>{'types': <String, Object?>{}},
  };

  late FakeHttpAdapter adapter;
  late AppDatabase database;
  String? token;
  String? pushToken;

  setUp(() {
    adapter = FakeHttpAdapter();
    database = AppDatabase(NativeDatabase.memory(), now: () => DateTime.utc(2026, 11, 1, 9));
    token = null;
    pushToken = null;
    addTearDown(database.close);
  });

  DeviceRepository repository() => DeviceRepository(
        client: MadarApi(fakeDio(adapter)).madarApi,
        identityReader: () async =>
            DeviceIdentity(installId: installId, token: token, pushToken: pushToken),
        tokenWriter: (value) async => token = value,
      );

  Map<String, Object?> body(int index) => adapter.requests[index].data as Map<String, Object?>;

  List<RequestOptions> requestsTo(String path) =>
      adapter.requests.where((request) => request.path == path).toList();

  group('the repository', () {
    test('a first launch registers once and keeps the server token', () async {
      adapter.enqueueData(registered, status: 201);

      await repository().ensureRegistered();
      expect(token, 'srv-token');
      expect(adapter.requests.single.method, 'POST');
      expect(adapter.requests.single.path, '/v1/devices');
      expect(body(0)['install_id'], installId);
      expect(body(0)['platform'], isNotNull);

      // The token is in force now, so a second start does not register again.
      await repository().ensureRegistered();
      expect(adapter.requests, hasLength(1));
    });

    test('a failed registration keeps the install id and the next try registers', () async {
      adapter.enqueueOffline();

      await expectLater(
        repository().ensureRegistered(),
        throwsA(isA<ApiFailure>().having((f) => f.isOffline, 'isOffline', isTrue)),
      );
      expect(token, isNull);

      adapter.enqueueData(registered, status: 201);
      await repository().ensureRegistered();

      expect(token, 'srv-token');
      expect(body(1)['install_id'], installId, reason: 'the same install id, never a new one');
    });

    test('the device update sends only the fields that were set', () async {
      adapter.enqueueData(registered, status: 201);
      pushToken = 'fcm-1';
      await repository().ensureRegistered();

      adapter.enqueueData(deviceBody);
      await repository().update(
        DeviceUpdate(
          appVersion: currentAppVersion(),
          locale: 'ar',
          pushToken: 'fcm-1',
          satelliteIds: const [3, 7],
        ),
      );

      final sent = body(1);
      expect(adapter.requests[1].method, 'PUT');
      expect(adapter.requests[1].path, '/v1/devices/me');
      expect(sent['push_token'], 'fcm-1');
      expect(sent['app_version'], currentAppVersion());
      expect(sent['satellite_ids'], [3, 7]);
      // An omitted field must not arrive as `null`: the server reads a null as "clear it".
      expect(sent.containsKey('prefs'), isFalse);
      expect(sent.containsKey('tz'), isFalse);
    });

    test('the follow sync sends the whole set, every kind', () async {
      adapter.enqueueData(const {'teams': <int>[31, 32]});

      await repository().replaceFollows(
        const FollowSet(
          teams: [31, 32],
          competitions: [9],
          matches: [900],
          channels: [],
          commentators: [],
        ),
      );

      final sent = body(0);
      expect(adapter.requests.single.path, '/v1/devices/me/follows');
      expect(sent['teams'], [31, 32]);
      expect(sent['competitions'], [9]);
      expect(sent['matches'], [900]);
      expect(sent['channels'], isEmpty);
      expect(sent['commentators'], isEmpty);
    });

    test('a refusal becomes the envelope’s code, never a bare exception', () async {
      adapter.enqueueError('unknown_satellite', status: 422);

      await expectLater(
        repository().replaceFollows(const FollowSet()),
        throwsA(isA<ApiFailure>().having((f) => f.code, 'code', 'unknown_satellite')),
      );
    });

    test('deleting the device is one DELETE', () async {
      adapter.enqueue((_) => ResponseBody.fromString('', 204));

      await repository().deleteDevice();

      expect(adapter.requests.single.method, 'DELETE');
      expect(adapter.requests.single.path, '/v1/devices/me');
    });

    test('the auth header carries the server token, never the push id', () async {
      final dio = fakeDio(adapter);
      dio.interceptors.add(
        DeviceAuthInterceptor(token: () => token, baseUrl: 'https://api.test'),
      );
      token = 'srv-token';
      pushToken = 'fcm-1';
      adapter.enqueueData(const {'ok': true});

      await dio.get<Object?>('/v1/matches');

      final header = adapter.requests.single.headers.entries
          .where((entry) => entry.key.toLowerCase() == 'authorization')
          .map((entry) => '${entry.value}')
          .first;
      expect(header, 'Device srv-token');
    });
  });

  group('the sync', () {
    late _Store store;
    late ProviderContainer container;

    setUp(() async {
      store = _Store();
      container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(database),
          secureStoreProvider.overrideWithValue(store),
          dioProvider.overrideWithValue(fakeDio(adapter)),
          pushServiceProvider.overrideWithValue(const NoPushService()),
        ],
      );
      addTearDown(container.dispose);
      // The two state streams drive the sync; a listener keeps them alive.
      container.listen(deviceSyncStateProvider, (_, _) {});
      container.listen(followsSyncStateProvider, (_, _) {});
    });

    /// The first launch after S1: the flow is done, so the device is worth sending.
    Future<void> launch() async {
      await database.writeSetting(SettingsKeys.onboardingDone, 'true');
      await container.read(appSettingsProvider.future);
      adapter.enqueueData(registered, status: 201);
      container.listen(deviceSyncProvider, (_, _) {});
      await container.read(deviceSyncProvider.notifier).sync();
      await pumpEventQueue();
    }

    test('a follow change is sent in full and its flag clears on success', () async {
      await launch();
      expect(requestsTo('/v1/devices'), hasLength(1));

      adapter.enqueueData(const {'teams': <int>[7]});
      await container.read(followsRepositoryProvider).toggle(FollowKind.team, 7);
      await pumpEventQueue();

      expect(requestsTo('/v1/devices/me/follows'), hasLength(1));
      final sent = requestsTo('/v1/devices/me/follows').single.data as Map<String, Object?>;
      expect(sent['teams'], [7]);
      expect((await database.readSyncState('follows'))!.dirty, isFalse);
    });

    test('a failed follow send keeps the flag, so the next attempt retries', () async {
      await launch();

      adapter.enqueueError('internal_error', status: 500);
      await container.read(followsRepositoryProvider).toggle(FollowKind.team, 7);
      await pumpEventQueue();

      final failed = await database.readSyncState('follows');
      expect(failed!.dirty, isTrue);
      expect(failed.lastError, 'internal_error');
    });

    test('a second launch with a stored token does not register again', () async {
      await launch();
      final before = requestsTo('/v1/devices').length;

      await container.read(deviceSyncProvider.notifier).sync();
      await pumpEventQueue();

      expect(requestsTo('/v1/devices'), hasLength(before));
      expect(store.values[SecureKeys.deviceToken], 'srv-token');
      expect(store.values[SecureKeys.pushToken], isNull);
    });
  });
}
