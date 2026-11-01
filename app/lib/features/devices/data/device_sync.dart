import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show setEquals;
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/db/app_database.dart';
import '../../../core/db/database_provider.dart';
import '../../../core/network/api_failure.dart';
import '../../../core/network/generated/export.dart';
import '../../../core/settings/app_settings.dart';
import '../../../core/settings/settings_providers.dart';
import '../../follows/data/follows_repository.dart';
import '../../system/data/connectivity.dart';
import 'device_identity_provider.dart';
import 'device_repository.dart';

part 'device_sync.g.dart';

/// Brings the server's copy of this device up to date (US2 scenarios 4, 6, 7; FR-041).
///
/// Three things reach `/v1/devices`: the registration (once), `PUT /v1/devices/me` when the
/// sync state says `device` is dirty (a push id, the satellite choice or the app version
/// changed) and `PUT /v1/devices/me/follows` when `follows` is dirty. A failure changes
/// nothing locally: the dirty flag stays and the next launch, resume, reconnect or change
/// tries again. A `401` drops the token, so the next attempt registers the same install id
/// again.
@Riverpod(keepAlive: true)
class DeviceSync extends _$DeviceSync {
  bool _running = false;
  bool _again = false;

  @override
  Future<void> build() async {
    // A reconnect is a natural retry point (R29): the last attempt failed offline.
    ref.listen(connectivityStatusProvider, (previous, next) {
      if (next && previous != true) unawaited(sync());
    });
    // Whatever flags the device or the follows — the push id, the satellite choice, the
    // zone, a follow toggle — is sent as soon as it is flagged, from one place. Only the
    // false → true edge: a failed attempt writes the flag again, and syncing on every write
    // would retry in a loop.
    ref.listen(deviceSyncStateProvider, (previous, next) {
      if (next.value?.dirty == true && previous?.value?.dirty != true) unawaited(sync());
    });
    ref.listen(followsSyncStateProvider, (previous, next) {
      if (next.value?.dirty == true && previous?.value?.dirty != true) unawaited(sync());
    });
    // The first settings read lands here too, so a first launch sends its choice without
    // waiting for a follow. Only a field `PUT /v1/devices/me` carries flags the device.
    ref.listen(appSettingsProvider, (previous, next) {
      final value = next.value;
      if (value == null) return;
      final before = previous?.value;
      // The first read is not a change. A choice made in S1.3 or S15 is, and so is finishing
      // the flow: that is when the device row and its choices are first worth sending.
      if (before == null) return;
      final finished = !before.onboardingDone && value.onboardingDone;
      if (!finished &&
          before.zone == value.zone &&
          setEquals(before.satelliteIds, value.satelliteIds)) {
        return;
      }
      unawaited(flagDeviceAndSync());
    });
    // The launch attempt belongs to the app (`MadarApp`), not to this provider's build: a
    // provider that sends on creation makes every screen that reads it wait on the network.
  }

  /// Marks the device dirty and sends, without waiting.
  Future<void> flagDeviceAndSync() async {
    await _record('device', null);
    await sync();
  }

  /// One sync at a time; a call that arrives while one runs makes it run once more, so a
  /// change made during a send is never lost.
  Future<void> sync() async {
    // Before S1 finishes there is nothing the server needs: no follows are being queued yet
    // and the device row would be empty. It also keeps «حذف بيانات جهازي» honest — the wipe
    // returns to S1.1, and no sync registers a new device behind the person's back.
    final settings = ref.read(appSettingsProvider).value;
    if (settings == null || !settings.onboardingDone) return;
    if (_running) {
      _again = true;
      return;
    }
    _running = true;
    try {
      do {
        _again = false;
        await _once();
      } while (_again);
    } catch (_) {
      // A closed database, a disposed container or a malformed answer: the flag stays and
      // the next trigger tries again. Nothing here may escape into the app's zone.
    } finally {
      _running = false;
    }
  }

  /// Records why the last attempt failed. A storage failure must not throw again, or the
  /// error escapes an unawaited sync and the flag is lost.
  Future<void> _record(String key, String? code) async {
    try {
      await ref.read(appDatabaseProvider).markSyncDirty(key, error: code);
    } catch (_) {
      // Nothing to record in.
    }
  }

  Future<void> _once() async {
    final repository = ref.read(deviceRepositoryProvider);
    final database = ref.read(appDatabaseProvider);
    // Which flag is in flight, so a failure is recorded on the right row.
    var key = 'device';
    try {
      await repository.ensureRegistered();
      key = 'device';
      await _sendDevice(repository, database);
      key = 'follows';
      await _sendFollows(repository, database);
    } on ApiFailure catch (failure) {
      if (failure.statusCode == 401) {
        // The token the server knows is gone (a rotated install, a deleted device): keep the
        // install id, drop the token, and let the next sync register it again.
        await ref.read(deviceIdentityControllerProvider.notifier).setToken(null);
        await _record(key, 'unauthenticated');
        return;
      }
      await _record(key, failure.code ?? (failure.isOffline ? 'network' : 'failed'));
    } on DioException catch (error) {
      await _record(key, error.response?.statusCode == 401 ? 'unauthenticated' : 'network');
    } catch (_) {
      // A malformed envelope or a storage failure: the next attempt tries again, and the
      // screen is never held by this.
      await _record(key, 'failed');
    }
  }

  /// `PUT /v1/devices/me`, only when something changed. The push id is the body's
  /// `push_token` — never an auth header (M-R1-2) — and a null field is not serialized.
  Future<void> _sendDevice(DeviceRepository repository, AppDatabase database) async {
    if (!await _isDirty(database, 'device')) return;
    final identity = await repository.identity();
    final settings = ref.read(appSettingsProvider).value ?? const AppSettingsValue();
    final satellites = settings.satelliteIds.toList()..sort();
    await repository.update(
      DeviceUpdate(
        appVersion: currentAppVersion(),
        locale: 'ar',
        pushToken: identity.pushToken,
        satelliteIds: satellites.isEmpty ? null : satellites,
        tz: ianaTimeZoneName(),
      ),
    );
    await database.markSyncClean('device');
  }

  /// `PUT /v1/devices/me/follows`: the whole set, every kind, so the server's copy is
  /// exactly this device's. An empty set clears the server's follows.
  Future<void> _sendFollows(DeviceRepository repository, AppDatabase database) async {
    if (!await _isDirty(database, 'follows')) return;
    final follows = await ref.read(followsRepositoryProvider).read();
    await repository.replaceFollows(
      FollowSet(
        teams: _sorted(follows.teams),
        competitions: _sorted(follows.competitions),
        channels: _sorted(follows.channels),
        commentators: _sorted(follows.commentators),
        matches: _sorted(follows.matches),
      ),
    );
    await database.markSyncClean('follows');
  }

  static Future<bool> _isDirty(AppDatabase database, String key) async =>
      (await database.readSyncState(key))?.dirty ?? false;

  static List<int> _sorted(Set<int> ids) => ids.toList()..sort();
}

/// The `device` row of `sync_state`, watched: its `dirty` flag is what makes
/// [DeviceSync] send `PUT /v1/devices/me`.
@riverpod
Stream<SyncRecord?> deviceSyncState(Ref ref) =>
    ref.watch(appDatabaseProvider).watchSyncState('device');

/// The `follows` row of `sync_state`, watched: `PUT /v1/devices/me/follows`.
@riverpod
Stream<SyncRecord?> followsSyncState(Ref ref) =>
    ref.watch(appDatabaseProvider).watchSyncState('follows');
