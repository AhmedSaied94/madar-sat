import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:retrofit/retrofit.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/config/build_info.dart';
import '../../../core/network/api_failure.dart';
import '../../../core/network/dio_failure.dart';
import '../../../core/network/dio_provider.dart';
import '../../../core/network/generated/export.dart';
import 'device_identity_provider.dart';

part 'device_repository.g.dart';

/// Registration, `PUT /v1/devices/me`, the follow sync and the server-side delete
/// (research R27, FR-041, contracts/public-devices.md).
///
/// Every call goes through the generated client, so a renamed path or field breaks the build.
/// The identity and the token writer are injected rather than read from Riverpod: the tests
/// drive this without a container, and `DeviceSync` owns when a call happens.
class DeviceRepository {
  const DeviceRepository({
    required this.client,
    required this.identityReader,
    required this.tokenWriter,
  });

  final MadarApiClient client;
  final Future<DeviceIdentity> Function() identityReader;
  final Future<void> Function(String? token) tokenWriter;

  /// `POST /v1/devices` once per install: it answers the device id and a token, which is
  /// kept in secure storage for `Authorization: Device`. A known install id rotates the
  /// token and keeps the follows and settings (public-devices).
  Future<void> ensureRegistered() async {
    final identity = await identityReader();
    if (identity.token != null) return;
    final response = await _call(
      () => client.registerDeviceV1DevicesPost(
        body: DeviceRegister(
          installId: identity.installId,
          platform: currentDevicePlatform(),
        ),
      ),
    );
    _requireSuccess(response.data.success, response.data.error);
    final registered = response.data.data;
    if (registered == null) throw const ApiFailure();
    await tokenWriter(registered.deviceToken);
  }

  /// `PUT /v1/devices/me`: the fields set on [body] change, the ones left null are not sent
  /// at all (a `null` in the body *clears* a field on the server).
  Future<void> update(DeviceUpdate body) async {
    final response = await _call(() => client.updateDeviceV1DevicesMePut(body: body));
    _requireSuccess(response.data.success, response.data.error);
  }

  /// `PUT /v1/devices/me/follows`: the whole set, atomically.
  Future<void> replaceFollows(FollowSet body) async {
    final response = await _call(() => client.replaceFollowsV1DevicesMeFollowsPut(body: body));
    _requireSuccess(response.data.success, response.data.error);
  }

  /// `DELETE /v1/devices/me`: the device row and its follows go; the token stops working.
  Future<void> deleteDevice() async {
    final response = await _call(client.deleteDeviceV1DevicesMeDelete);
    final status = response.response.statusCode ?? 0;
    if (status < 200 || status >= 300) throw const ApiFailure();
  }

  /// The device's own identity, right now.
  Future<DeviceIdentity> identity() => identityReader();

  /// One call, with Dio's error turned into the envelope's [ApiFailure]: a caller only ever
  /// catches `ApiFailure`, whatever went wrong.
  static Future<HttpResponse<T>> _call<T>(Future<HttpResponse<T>> Function() send) async {
    try {
      return await send();
    } on DioException catch (error) {
      throw error.asApiFailure;
    }
  }

  static void _requireSuccess(bool success, ErrorBody? error) {
    if (!success) throw ApiFailure(code: error?.code);
  }
}

/// The platform `POST /v1/devices` registers, from the build in force.
DeviceRegisterPlatform currentDevicePlatform() {
  if (kIsWeb) return DeviceRegisterPlatform.web;
  return defaultTargetPlatform == TargetPlatform.iOS
      ? DeviceRegisterPlatform.ios
      : DeviceRegisterPlatform.android;
}

/// `app_version` (≤ 32): the version and build number this build reports on S16/S0.
String currentAppVersion() => '${BuildInfo.version}+${BuildInfo.buildNumber}';

/// The IANA zone name, or null when the platform only knows an abbreviation.
///
/// The contract takes a valid IANA name and the fixed stack has no time-zone plugin, so a
/// value that does not look like one (an abbreviation, or the fixed GMT choice of S15) is
/// left out: an omitted `tz` is "unchanged", while an invalid one is a `422`.
String? ianaTimeZoneName([DateTime? now]) {
  final name = (now ?? DateTime.now()).timeZoneName;
  final looksIana = RegExp(r'^[A-Za-z][A-Za-z_]+/[A-Za-z_+\-0-9]+$').hasMatch(name);
  return looksIana ? name : null;
}

/// The repository, wired to the app's client and identity.
@Riverpod(keepAlive: true)
DeviceRepository deviceRepository(Ref ref) => DeviceRepository(
      client: ref.watch(madarApiClientProvider),
      identityReader: () => ref.read(deviceIdentityControllerProvider.future),
      tokenWriter: (token) =>
          ref.read(deviceIdentityControllerProvider.notifier).setToken(token),
    );
