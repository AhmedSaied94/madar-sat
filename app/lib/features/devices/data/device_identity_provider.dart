import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/db/database_provider.dart';
import '../../../core/platform/secure_store.dart';
import '../../../core/settings/app_settings.dart';

part 'device_identity_provider.g.dart';

/// This install's identity (research R1, R27): a random install id generated once and kept
/// in secure storage, the device token the server issued for it, and the push id FCM
/// registered for it.
///
/// The two tokens are kept apart on purpose (M-R1-2): `Authorization: Device` carries
/// [token], the server's, and [pushToken] travels only in `PUT /v1/devices/me`'s body.
@immutable
class DeviceIdentity {
  const DeviceIdentity({required this.installId, this.token, this.pushToken});

  /// A UUIDv4 generated on the first launch and never regenerated, so a `401` re-registers
  /// the same install instead of creating a second device.
  final String installId;

  /// The `Authorization: Device` token, or null before the first registration.
  final String? token;

  /// The FCM installation id, or null while push was never granted. Not an auth token.
  final String? pushToken;

  DeviceIdentity withToken(String? token) =>
      DeviceIdentity(installId: installId, token: token, pushToken: pushToken);

  DeviceIdentity withPushToken(String? pushToken) =>
      DeviceIdentity(installId: installId, token: token, pushToken: pushToken);
}

/// The identity in force, read from secure storage on start.
///
/// Registration (`POST /v1/devices`) is [DeviceRepository]'s, and it writes the token this
/// holds; the interceptor reads it on every `/v1` request.
@Riverpod(keepAlive: true)
class DeviceIdentityController extends _$DeviceIdentityController {
  @override
  Future<DeviceIdentity> build() async {
    final store = ref.watch(secureStoreProvider);
    final existing = await store.read(SecureKeys.installId);
    final installId = existing ?? _newInstallId();
    if (existing == null) await store.write(SecureKeys.installId, installId);
    return DeviceIdentity(
      installId: installId,
      token: await store.read(SecureKeys.deviceToken),
      pushToken: await store.read(SecureKeys.pushToken),
    );
  }

  /// The token right now, without awaiting the first read: the interceptor runs on every
  /// request and cannot wait.
  String? get token => state.value?.token;

  /// The server's token, after registration (or with null once the device is deleted).
  Future<void> setToken(String? token) async {
    final store = ref.read(secureStoreProvider);
    if (token == null) {
      await store.delete(SecureKeys.deviceToken);
    } else {
      await store.write(SecureKeys.deviceToken, token);
    }
    final current = state.value;
    if (current != null) state = AsyncData(current.withToken(token));
  }

  /// The FCM installation id, which `PUT /v1/devices/me` sends as `push_token`. It never
  /// touches [SecureKeys.deviceToken].
  Future<void> setPushToken(String? pushToken) async {
    final store = ref.read(secureStoreProvider);
    if (pushToken == null) {
      await store.delete(SecureKeys.pushToken);
    } else {
      await store.write(SecureKeys.pushToken, pushToken);
    }
    final current = state.value;
    if (current != null) state = AsyncData(current.withPushToken(pushToken));
  }

  /// «حذف بيانات جهازي»: the server answered, so the local identity starts over.
  Future<void> forget() async {
    final store = ref.read(secureStoreProvider);
    await store.delete(SecureKeys.deviceToken);
    await store.delete(SecureKeys.pushToken);
    await store.delete(SecureKeys.installId);
    await ref.read(appDatabaseProvider).writeSetting(SettingsKeys.deviceId, null);
    ref.invalidateSelf();
  }

  static String _newInstallId() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    // RFC 4122 version 4.
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    final hex = bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-'
        '${hex.substring(16, 20)}-${hex.substring(20)}';
  }
}
