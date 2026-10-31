import 'package:dio/dio.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../config/app_config.dart';
import 'etag_interceptor.dart';
import 'generated/export.dart';

part 'dio_provider.g.dart';

/// One Dio for the app: base URL from the bundled flavor config, timeouts, and the
/// ETag interceptor (research R17).
@Riverpod(keepAlive: true)
Dio dio(Ref ref) {
  AppConfig.ensureConfigured();
  return Dio(
    BaseOptions(
      baseUrl: AppConfig.apiBaseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 20),
      headers: const {'Accept': 'application/json'},
    ),
  )..interceptors.add(EtagInterceptor());
}

/// The generated client (swagger_parser, never hand-edited).
@Riverpod(keepAlive: true)
MadarApi madarApi(Ref ref) => MadarApi(ref.watch(dioProvider));

@Riverpod(keepAlive: true)
MadarApiClient madarApiClient(Ref ref) => ref.watch(madarApiProvider).madarApi;
