import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/platform/secure_store.dart';

part 'device_identity_provider.g.dart';

/// This install's identity (research R1, R27): a random install id generated once and kept
/// in secure storage, and the device token the server issued for it.
@immutable
class DeviceIdentity {
  const DeviceIdentity({required this.installId, this.token});

  /// A UUIDv4 generated on the first launch and never regenerated, so a `401` re-registers
  /// the same install instead of creating a second device.
  final String installId;

  /// The `Authorization: Device` token, or null before the first registration.
  final String? token;

  DeviceIdentity withToken(String? token) => DeviceIdentity(installId: installId, token: token);
}

/// The identity in force, read from secure storage on start.
///
/// Registration itself (`POST /v1/devices`) is T133's, against B1's regenerated client; this
/// holds the state it writes and the interceptor reads.
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
    );
  }

  /// The token right now, without awaiting the first read: the interceptor runs on every
  /// request and cannot wait.
  String? get token => state.value?.token;

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

  /// «حذف بيانات جهازي»: the server answered, so the local identity starts over.
  Future<void> forget() async {
    final store = ref.read(secureStoreProvider);
    await store.delete(SecureKeys.deviceToken);
    await store.delete(SecureKeys.installId);
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
