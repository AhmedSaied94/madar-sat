import 'dart:async';

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
import 'package:madar_sat/features/devices/data/push_token_sync.dart';
import 'package:madar_sat/features/system/data/connectivity.dart';

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

/// A push service whose token the test rotates, as FCM does.
class _FakePush implements PushService {
  final StreamController<String?> _changes = StreamController<String?>.broadcast();
  String? _token;

  @override
  Future<PushPermissionState> permission() async => PushPermissionState.allowed;

  @override
  Stream<ForegroundPush> get foregroundMessages => const Stream.empty();

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
    late _FakePush fakePush;
    late ProviderContainer container;

    setUp(() async {
      store = _Store();
      fakePush = _FakePush();
      container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(database),
          secureStoreProvider.overrideWithValue(store),
          dioProvider.overrideWithValue(fakeDio(adapter)),
          pushServiceProvider.overrideWithValue(fakePush),
        ],
      );
      addTearDown(container.dispose);
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

    group('the device ID (FR-062, R18)', () {
      Future<String?> stored() => database.readSetting(SettingsKeys.deviceId);

      test('registering keeps it, so no extra PUT is forced', () async {
        await launch();

        expect(await stored(), '812');
        expect(requestsTo('/v1/devices/me'), isEmpty);
      });

      test('an existing install with no ID forces one sync, then none', () async {
        store.values[SecureKeys.deviceToken] = 'old-token';
        store.values[SecureKeys.installId] = installId;
        await database.writeSetting(SettingsKeys.onboardingDone, 'true');
        await container.read(appSettingsProvider.future);
        adapter.enqueueData(deviceBody);
        container.listen(deviceSyncProvider, (_, _) {});

        await container.read(deviceSyncProvider.notifier).sync();
        await pumpEventQueue();
        expect(requestsTo('/v1/devices'), isEmpty);
        expect(requestsTo('/v1/devices/me'), hasLength(1));
        expect(await stored(), '812');

        await container.read(deviceSyncProvider.notifier).sync();
        await pumpEventQueue();
        expect(requestsTo('/v1/devices/me'), hasLength(1));
      });

      Future<void> existingInstall() async {
        store.values[SecureKeys.deviceToken] = 'old-token';
        store.values[SecureKeys.installId] = installId;
        await database.writeSetting(SettingsKeys.onboardingDone, 'true');
        await container.read(appSettingsProvider.future);
        container.listen(deviceSyncProvider, (_, _) {});
      }

      test('a failed forced send holds up nothing, and tries again next time', () async {
        await existingInstall();
        await database.markSyncDirty('follows');
        adapter
          ..enqueueData(const {'teams': <int>[]})
          ..enqueueOffline();

        await container.read(deviceSyncProvider.notifier).sync();
        await pumpEventQueue();

        expect(requestsTo('/v1/devices/me/follows'), hasLength(1));
        expect((await database.readSyncState('follows'))!.dirty, isFalse);
        expect((await database.readSyncState('device'))?.dirty ?? false, isFalse);
        expect(await stored(), isNull);

        adapter.enqueueData(deviceBody);
        await container.read(deviceSyncProvider.notifier).sync();
        await pumpEventQueue();
        expect(await stored(), '812');
      });

      test('an answer with no device is not asked for again this launch', () async {
        await existingInstall();
        adapter.enqueueData(null);

        await container.read(deviceSyncProvider.notifier).sync();
        await pumpEventQueue();
        await container.read(deviceSyncProvider.notifier).sync();
        await pumpEventQueue();

        expect(requestsTo('/v1/devices/me'), hasLength(1));
      });

      test('forget() clears it', () async {
        await launch();
        expect(await stored(), '812');

        await container.read(deviceIdentityControllerProvider.notifier).forget();

        expect(await stored(), isNull);
      });
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

    FollowsRepository follows() => container.read(followsRepositoryProvider);

    AppSettings settings() => container.read(appSettingsProvider.notifier);

    Map<String, Object?> sentBody(RequestOptions request) =>
        request.data as Map<String, Object?>;

    /// Holds the next answer back until the test completes it, so a change can land while
    /// that request is in flight.
    Completer<ResponseBody> hold() {
      final completer = Completer<ResponseBody>();
      adapter.enqueue((_) => completer.future);
      return completer;
    }

    group('a change made while a send is in flight is never lost (M-R2-1)', () {
      test('a follow toggled during PUT …/follows reaches the server in a second PUT',
          () async {
        await launch();
        final inFlight = hold();
        await follows().toggle(FollowKind.team, 7);
        await pumpEventQueue();
        expect(requestsTo('/v1/devices/me/follows'), hasLength(1));

        await follows().toggle(FollowKind.team, 8);
        adapter.enqueueData(const {'teams': <int>[7, 8]});
        inFlight.complete(FakeHttpAdapter.envelope(const {'teams': <int>[7]}));
        await pumpEventQueue();

        final puts = requestsTo('/v1/devices/me/follows');
        expect(puts, hasLength(2));
        expect(sentBody(puts.last)['teams'], [7, 8]);
        expect((await database.readSyncState('follows'))!.dirty, isFalse);
      });

      test('a push id received during PUT /devices/me reaches the server in a second PUT',
          () async {
        await launch();
        container.listen(pushTokenSyncProvider, (_, _) {});
        await container.read(pushTokenSyncProvider.future);
        final inFlight = hold();
        await settings().setZone(const MadarZone.fixed(Duration(hours: 3)));
        await pumpEventQueue();
        expect(requestsTo('/v1/devices/me'), hasLength(1));

        fakePush.rotate('fcm-1');
        await pumpEventQueue();
        adapter.enqueueData(deviceBody);
        inFlight.complete(FakeHttpAdapter.envelope(deviceBody));
        await pumpEventQueue();

        final puts = requestsTo('/v1/devices/me');
        expect(puts, hasLength(2));
        expect(sentBody(puts.first).containsKey('push_token'), isFalse);
        expect(sentBody(puts.last)['push_token'], 'fcm-1');
        expect((await database.readSyncState('device'))!.dirty, isFalse);
      });

      test('a satellite chosen during PUT /devices/me reaches the server in a second PUT',
          () async {
        await launch();
        final inFlight = hold();
        await settings().setZone(const MadarZone.fixed(Duration(hours: 3)));
        await pumpEventQueue();
        expect(requestsTo('/v1/devices/me'), hasLength(1));

        await settings().setSatellites({7, 3});
        await pumpEventQueue();
        adapter.enqueueData(deviceBody);
        inFlight.complete(FakeHttpAdapter.envelope(deviceBody));
        await pumpEventQueue();

        final puts = requestsTo('/v1/devices/me');
        expect(puts, hasLength(2));
        expect(sentBody(puts.first).containsKey('satellite_ids'), isFalse);
        expect(sentBody(puts.last)['satellite_ids'], [3, 7]);
        expect((await database.readSyncState('device'))!.dirty, isFalse);
      });

      test('a follow changed after an earlier send failed is sent at once', () async {
        await launch();
        adapter.enqueueOffline();
        await follows().toggle(FollowKind.team, 7);
        await pumpEventQueue();
        expect((await database.readSyncState('follows'))!.dirty, isTrue);

        // The flag is already set, so this write is no false → true edge: it still sends.
        adapter.enqueueData(const {'teams': <int>[7, 8]});
        await follows().toggle(FollowKind.team, 8);
        await pumpEventQueue();

        final puts = requestsTo('/v1/devices/me/follows');
        expect(puts, hasLength(2));
        expect(sentBody(puts.last)['teams'], [7, 8]);
        expect((await database.readSyncState('follows'))!.dirty, isFalse);
      });
    });

    group('a 422 naming ids the server does not know (M-R2-2)', () {
      test('unknown_follow_target drops those follows locally and the next PUT goes without them',
          () async {
        await launch();
        adapter.enqueueData(const {'competitions': <int>[9]});
        await follows().replace(FollowKind.competition, {9});
        await pumpEventQueue();
        expect((await database.readSyncState('follows'))!.dirty, isFalse);

        adapter.enqueueError(
          'unknown_follow_target',
          status: 422,
          meta: const {
            'unknown': {
              'teams': [8],
            },
          },
        );
        adapter.enqueueData(const {'teams': <int>[7], 'competitions': <int>[9]});
        await follows().replace(FollowKind.team, {7, 8});
        await pumpEventQueue();

        final puts = requestsTo('/v1/devices/me/follows');
        expect(puts, hasLength(3));
        expect(sentBody(puts[1])['teams'], [7, 8]);
        expect(sentBody(puts[2])['teams'], [7]);
        expect(sentBody(puts[2])['competitions'], [9]);
        final stored = await follows().read();
        expect(stored.teams, {7});
        expect(stored.competitions, {9});
        final state = (await database.readSyncState('follows'))!;
        expect(state.dirty, isFalse);
        expect(state.lastError, isNull);
      });

      test('ids the app does not hold are recorded as the failure, never retried for ever',
          () async {
        await launch();
        adapter.enqueueError(
          'unknown_follow_target',
          status: 422,
          meta: const {
            'unknown': {
              'teams': [99],
            },
          },
        );
        await follows().replace(FollowKind.team, {7});
        await pumpEventQueue();

        expect(requestsTo('/v1/devices/me/follows'), hasLength(1));
        expect((await follows().read()).teams, {7});
        final state = (await database.readSyncState('follows'))!;
        expect(state.dirty, isTrue);
        expect(state.lastError, 'unknown_follow_target');
      });

      test('unknown_satellite drops those satellites from my satellites and sends again',
          () async {
        await launch();
        adapter.enqueueError('unknown_satellite', status: 422, meta: const {'unknown': [7]});
        // Spare answers: dropping a satellite is itself a change of the satellite choice.
        for (var spare = 0; spare < 3; spare++) {
          adapter.enqueueData(deviceBody);
        }
        await settings().setSatellites({3, 7});
        await pumpEventQueue(times: 100);

        final puts = requestsTo('/v1/devices/me');
        expect(sentBody(puts.first)['satellite_ids'], [3, 7]);
        expect(puts.length, greaterThan(1));
        for (final put in puts.skip(1)) {
          expect(sentBody(put)['satellite_ids'], [3]);
        }
        expect(await database.readSetting(SettingsKeys.satelliteIds), '3');
        final state = (await database.readSyncState('device'))!;
        expect(state.dirty, isFalse);
        expect(state.lastError, isNull);
      });
    });

    group('what the device sends and when it retries (T114, M-R2-4)', () {
      test('PUT /devices/me carries the chosen satellites, the push id and the app version',
          () async {
        await launch();
        container.listen(pushTokenSyncProvider, (_, _) {});
        await container.read(pushTokenSyncProvider.future);
        adapter.enqueueData(deviceBody);
        adapter.enqueueData(deviceBody);
        fakePush.rotate('fcm-1');
        await pumpEventQueue();

        await settings().setSatellites({7, 3});
        await pumpEventQueue();

        final sent = sentBody(requestsTo('/v1/devices/me').last);
        expect(sent['satellite_ids'], [3, 7]);
        expect(sent['push_token'], 'fcm-1');
        expect(sent['app_version'], currentAppVersion());
        expect(sent['locale'], 'ar');
        // An omitted field is "unchanged" on the server; a null would clear it.
        expect(sent.containsKey('prefs'), isFalse);
      });

      test('a 401 drops the token and the next sync registers the same install id',
          () async {
        await launch();
        final installId = store.values[SecureKeys.installId];
        // The answers are queued up front: whether the register-again runs inside the same
        // sync or on the next trigger, it takes the same two answers in the same order.
        adapter.enqueueError('unauthenticated', status: 401);
        adapter.enqueueData(
          const {'device_id': 812, 'device_token': 'second-token'},
          status: 201,
        );
        adapter.enqueueData(deviceBody);
        await settings().setZone(const MadarZone.fixed(Duration(hours: 3)));
        await pumpEventQueue();
        await container.read(deviceSyncProvider.notifier).sync();
        await pumpEventQueue();

        // The first registration, then the one after the 401: the same install.
        final registrations = requestsTo('/v1/devices');
        expect(registrations, hasLength(2));
        expect(sentBody(registrations.last)['install_id'], installId);
        expect(store.values[SecureKeys.deviceToken], 'second-token');
        expect(requestsTo('/v1/devices/me'), hasLength(2));
        final state = (await database.readSyncState('device'))!;
        expect(state.dirty, isFalse);
        expect(state.lastError, isNull);
      });

      test('a failed follow send is retried when the connection comes back', () async {
        await launch();
        adapter.enqueueOffline();
        await follows().toggle(FollowKind.team, 7);
        await pumpEventQueue();
        expect(requestsTo('/v1/devices/me/follows'), hasLength(1));
        expect((await database.readSyncState('follows'))!.dirty, isTrue);

        final connectivity = container.read(connectivityStatusProvider.notifier);
        connectivity.markOffline();
        adapter.enqueueData(const {'teams': <int>[7]});
        connectivity.markOnline();
        await pumpEventQueue();

        expect(requestsTo('/v1/devices/me/follows'), hasLength(2));
        expect((await database.readSyncState('follows'))!.dirty, isFalse);
      });
    });
  });
}
