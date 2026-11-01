import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'secure_store.g.dart';

/// The OS keychain/keystore (research R27): the device token and the install id live here,
/// never in drift and never in the repo.
///
/// Feature code asks this interface, so a test answers without a platform channel and an
/// architecture test can keep `flutter_secure_storage` inside `core/platform/`.
abstract interface class SecureStore {
  Future<String?> read(String key);

  Future<void> write(String key, String value);

  Future<void> delete(String key);
}

/// The keys stored here. One place, so the device layer and the tests agree.
abstract final class SecureKeys {
  /// The server-issued `Authorization: Device` token (one per install).
  static const String deviceToken = 'device.token';

  /// The random install id, generated once and sent to `POST /v1/devices`.
  static const String installId = 'device.install_id';

  /// The push id (FCM's registered installation id). **Not** the device token: this one
  /// travels only in the body of `PUT /v1/devices/me` as `push_token` (M-R1-2).
  static const String pushToken = 'device.push_token';
}

class FlutterSecureStore implements SecureStore {
  const FlutterSecureStore();

  static const FlutterSecureStorage _storage = FlutterSecureStorage();

  @override
  Future<String?> read(String key) => _storage.read(key: key);

  @override
  Future<void> write(String key, String value) => _storage.write(key: key, value: value);

  @override
  Future<void> delete(String key) => _storage.delete(key: key);
}

@Riverpod(keepAlive: true)
SecureStore secureStore(Ref ref) => const FlutterSecureStore();
