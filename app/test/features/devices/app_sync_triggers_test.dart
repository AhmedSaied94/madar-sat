import 'package:dio/dio.dart' show RequestOptions;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:madar_sat/app.dart';
import 'package:madar_sat/core/db/app_database.dart';
import 'package:madar_sat/core/db/database_provider.dart';
import 'package:madar_sat/core/network/dio_provider.dart';
import 'package:madar_sat/core/platform/push_service.dart';
import 'package:madar_sat/core/platform/secure_store.dart';
import 'package:madar_sat/core/settings/app_settings.dart';
import 'package:madar_sat/features/follows/data/follows_repository.dart';
import 'package:madar_sat/features/follows/domain/follow_set.dart' show FollowKind;

import '../../fixtures/fake_http_adapter.dart';

class _Store implements SecureStore {
  final Map<String, String> values = {};

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async => values[key] = value;

  @override
  Future<void> delete(String key) async => values.remove(key);
}

/// The two moments the app itself must retry an unsent device or follow change (US2
/// scenario 6, T114): at launch, once the settings are read, and when it comes back to the
/// foreground. Both belong to `MadarApp`, not to a screen.
void main() {
  const deviceBody = {
    'device_id': 812,
    'platform': 'android',
    'app_version': '1.0.0+1',
    'tz': null,
    'locale': 'ar',
    'satellite_ids': <int>[],
    'has_push_token': false,
    'prefs': <String, Object?>{'types': <String, Object?>{}},
  };

  late AppDatabase database;
  late FakeHttpAdapter adapter;
  late ProviderContainer container;

  setUp(() {
    database = AppDatabase(NativeDatabase.memory(), now: () => DateTime.utc(2026, 11, 1, 9));
    adapter = FakeHttpAdapter();
    // An install that is registered already: the token is in secure storage.
    final store = _Store()
      ..values[SecureKeys.installId] = '6f1c0b8e-2d3a-4c8b-9f0e-1a2b3c4d5e6f'
      ..values[SecureKeys.deviceToken] = 'stored-token';
    container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(database),
        secureStoreProvider.overrideWithValue(store),
        dioProvider.overrideWithValue(fakeDio(adapter)),
        pushServiceProvider.overrideWithValue(const NoPushService()),
      ],
    );
    addTearDown(() async {
      container.dispose();
      await database.close();
    });
  });

  List<RequestOptions> requestsTo(String path) =>
      adapter.requests.where((request) => request.path == path).toList();

  /// The in-memory database and the scripted adapter answer on the test clock, so pumping
  /// a few frames lets every continuation run.
  Future<void> settle(WidgetTester tester) async {
    for (var round = 0; round < 20; round++) {
      await tester.pump(const Duration(milliseconds: 10));
    }
  }

  Future<void> pumpApp(WidgetTester tester) async {
    final router = GoRouter(
      routes: [GoRoute(path: '/', builder: (context, state) => const SizedBox.shrink())],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: MadarApp(router: router)),
    );
    await settle(tester);
  }

  testWidgets('a flag the last session left set is sent at launch, once the settings are read',
      (tester) async {
    await database.writeSetting(SettingsKeys.onboardingDone, 'true');
    await database.markSyncDirty('device');
    await database.markSyncDirty('follows');
    adapter.enqueueData(deviceBody);
    adapter.enqueueData(const {'teams': <int>[]});

    await pumpApp(tester);

    expect(requestsTo('/v1/devices/me'), hasLength(1));
    expect(requestsTo('/v1/devices/me/follows'), hasLength(1));
    expect((await database.readSyncState('device'))!.dirty, isFalse);
    expect((await database.readSyncState('follows'))!.dirty, isFalse);
  });

  testWidgets('a failed follow send is retried when the app returns to the foreground',
      (tester) async {
    await database.writeSetting(SettingsKeys.onboardingDone, 'true');
    // The ID is known, so no device update is forced ahead of the follows (FR-062).
    await database.writeSetting(SettingsKeys.deviceId, '812');
    await pumpApp(tester);

    adapter.enqueueOffline();
    await container.read(followsRepositoryProvider).toggle(FollowKind.team, 7);
    await settle(tester);
    expect(requestsTo('/v1/devices/me/follows'), hasLength(1));
    expect((await database.readSyncState('follows'))!.dirty, isTrue);

    adapter.enqueueData(const {'teams': <int>[7]});
    // Backgrounded and back, through each step the platform reports.
    for (final state in const [
      AppLifecycleState.inactive,
      AppLifecycleState.hidden,
      AppLifecycleState.paused,
      AppLifecycleState.hidden,
      AppLifecycleState.inactive,
      AppLifecycleState.resumed,
    ]) {
      tester.binding.handleAppLifecycleStateChanged(state);
    }
    await settle(tester);

    expect(requestsTo('/v1/devices/me/follows'), hasLength(2));
    expect((await database.readSyncState('follows'))!.dirty, isFalse);
  });
}
