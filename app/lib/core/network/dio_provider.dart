import 'package:dio/dio.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../features/devices/data/device_identity_provider.dart';
import '../../features/system/data/connectivity.dart';
import '../config/remote_config.dart';
import 'dev_ca.dart';
import 'device_auth_interceptor.dart';
import 'etag_interceptor.dart';
import 'generated/export.dart';

part 'dio_provider.g.dart';

/// One Dio for the app: base URL from Remote Config (the flavor's bundled value until the
/// fetch answers), timeouts, and the ETag interceptor (research R17, R28).
@Riverpod(keepAlive: true)
Dio dio(Ref ref) {
  final baseUrl = ref.watch(apiBaseUrlProvider);
  if (baseUrl.isEmpty) {
    throw StateError(
      'API_BASE_URL must be passed with --dart-define-from-file=env/<flavor>.json',
    );
  }
  final dio = Dio(
    BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 20),
      headers: const {'Accept': 'application/json'},
    ),
  );
  // A debug native build can trust the dev Caddy's own root (M-T045-1); release and web
  // builds get null here and keep Dio's default adapter.
  final devCa = devCaPath();
  if (devCa != null) {
    final adapter = devCaAdapter(devCa);
    if (adapter != null) dio.httpClientAdapter = adapter;
  }
  return dio..interceptors.addAll([
    EtagInterceptor(),
    // Every `/v1` request carries the device token once one exists, so the API's limits
    // count each phone separately (R11, R27). The media host never goes through this Dio.
    DeviceAuthInterceptor(
      token: () => ref.read(deviceIdentityControllerProvider).value?.token,
      baseUrl: baseUrl,
    ),
    // R29: no new connectivity plugin; a transport failure is "offline", the next answer
    // is "online".
    ConnectivityInterceptor(
      onOnline: () => ref.read(connectivityStatusProvider.notifier).markOnline(),
      onOffline: () => ref.read(connectivityStatusProvider.notifier).markOffline(),
    ),
  ]);
}

/// The generated client (swagger_parser, never hand-edited).
@Riverpod(keepAlive: true)
MadarApi madarApi(Ref ref) => MadarApi(ref.watch(dioProvider));

@Riverpod(keepAlive: true)
MadarApiClient madarApiClient(Ref ref) => ref.watch(madarApiProvider).madarApi;
