import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madar_sat/core/db/app_database.dart';
import 'package:madar_sat/core/db/database_provider.dart';
import 'package:madar_sat/core/network/dio_provider.dart';
import 'package:madar_sat/core/network/generated/export.dart';
import 'package:madar_sat/core/platform/push_service.dart';
import 'package:madar_sat/core/platform/secure_store.dart';
import 'package:madar_sat/core/settings/app_settings.dart';
import 'package:madar_sat/core/settings/settings_providers.dart';
import 'package:madar_sat/features/devices/data/device_sync.dart';

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

/// S15's choices reaching the server (FR-063): saved through the existing device update, and
/// surviving being offline and a restart. Nothing is sent before onboarding ends.
void main() {
  const registered = {'device_id': 812, 'device_token': 'srv-token'};
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

  late FakeHttpAdapter adapter;
  late AppDatabase database;
  late _Store store;
  late ProviderContainer container;

  ProviderContainer open() {
    final created = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(database),
        secureStoreProvider.overrideWithValue(store),
        dioProvider.overrideWithValue(fakeDio(adapter)),
        pushServiceProvider.overrideWithValue(const NoPushService()),
      ],
    );
    addTearDown(created.dispose);
    return created;
  }

  setUp(() {
    adapter = FakeHttpAdapter();
    database = AppDatabase(NativeDatabase.memory(), now: () => DateTime.utc(2026, 11, 1, 9));
    addTearDown(database.close);
    store = _Store();
    container = open();
  });

  List<RequestOptions> puts() =>
      adapter.requests.where((request) => request.path == '/v1/devices/me').toList();

  /// The body as it goes on the wire: at this point Dio still holds the models.
  Map<String, Object?>? prefsOf(RequestOptions request) =>
      (jsonDecode(jsonEncode(request.data)) as Map<String, Object?>)['prefs']
          as Map<String, Object?>?;

  /// A settled install: onboarded and registered, with nothing left to send.
  Future<void> launch() async {
    await database.writeSetting(SettingsKeys.onboardingDone, 'true');
    await container.read(appSettingsProvider.future);
    adapter
      ..enqueueData(registered, status: 201)
      ..enqueueData(deviceBody);
    container.listen(deviceSyncProvider, (_, _) {});
    await container.read(deviceSyncProvider.notifier).flagDeviceAndSync();
    await pumpEventQueue();
  }

  Future<void> choose(NotificationType type, bool on) async {
    final notifier = container.read(appSettingsProvider.notifier);
    await notifier.setNotifications(notifier.value.notificationChoices.withType(type, on));
    await container.read(appSettingsProvider.future);
    await pumpEventQueue();
  }

  test('a device that chose nothing sends no prefs, so the server\'s defaults stand', () async {
    await launch();

    expect(prefsOf(puts().single), isNull);
  });

  test('a changed switch sends every type at once', () async {
    await launch();
    adapter.enqueueData(deviceBody);

    await choose(NotificationType.matchStarted, true);

    final types = prefsOf(puts().last)!['types']! as Map<String, Object?>;
    expect(types['match_started'], {'on': true});
    expect(types['goal'], {'on': true});
    expect(types.keys, hasLength(7));
    expect(types.keys, isNot(contains(null)));
  });

  test('a change made offline stays flagged and reaches the server on reconnect', () async {
    await launch();
    adapter.enqueueOffline();

    await choose(NotificationType.goal, false);
    expect((await database.readSyncState('device'))!.dirty, isTrue);

    adapter.enqueueData(deviceBody);
    await container.read(deviceSyncProvider.notifier).sync();
    await pumpEventQueue();

    final types = prefsOf(puts().last)!['types']! as Map<String, Object?>;
    expect(types['goal'], {'on': false});
    expect((await database.readSyncState('device'))!.dirty, isFalse);
  });

  test('a choice survives a restart', () async {
    await launch();
    adapter.enqueueData(deviceBody);
    await choose(NotificationType.goal, false);

    final restarted = open();
    final settings = await restarted.read(appSettingsProvider.future);

    expect(settings.notificationChoices.isOn(NotificationType.goal), isFalse);
    expect(settings.notificationChoices.isOn(NotificationType.finalScore), isTrue);
  });

  test('nothing is sent before onboarding ends, and it goes when it does', () async {
    await container.read(appSettingsProvider.future);
    container.listen(deviceSyncProvider, (_, _) {});

    await choose(NotificationType.goal, false);
    expect(adapter.requests, isEmpty);

    adapter
      ..enqueueData(registered, status: 201)
      ..enqueueData(deviceBody);
    await container.read(appSettingsProvider.notifier).completeOnboarding();
    await container.read(appSettingsProvider.future);
    await pumpEventQueue();

    final types = prefsOf(puts().single)!['types']! as Map<String, Object?>;
    expect(types['goal'], {'on': false});
  });

  group('the choices document', () {
    test('every type has its default, with match_started off', () {
      const choices = NotificationChoices();
      expect(choices.enabled, isTrue);
      for (final type in NotificationType.$valuesDefined) {
        expect(choices.isOn(type), type != NotificationType.matchStarted, reason: '$type');
      }
    });

    test('reads back what it wrote, keeping values when the master is off', () {
      final choices = const NotificationChoices()
          .withType(NotificationType.goal, false)
          .withEnabled(false);

      final read = NotificationChoices.decode(choices.encode());

      expect(read, choices);
      expect(read.enabled, isFalse);
      expect(read.isOn(NotificationType.goal), isFalse);
    });

    test('an unreadable document falls back to the defaults', () {
      for (final bad in ['', 'nope', '[]', '{"enabled":"yes","types":3}']) {
        expect(NotificationChoices.decode(bad), const NotificationChoices(), reason: bad);
      }
    });
  });
}
