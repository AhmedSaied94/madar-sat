import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/app_config.dart';
import 'etag_interceptor.dart';
import 'generated/export.dart';

/// One Dio for the app: base URL from the bundled flavor config, timeouts, and the
/// ETag interceptor (research R17).
final dioProvider = Provider<Dio>((ref) {
  AppConfig.ensureConfigured();
  return Dio(
    BaseOptions(
      baseUrl: AppConfig.apiBaseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 20),
      headers: const {'Accept': 'application/json'},
    ),
  )..interceptors.add(EtagInterceptor());
});

/// The generated client (swagger_parser, never hand-edited).
final madarApiProvider = Provider<MadarApi>(
  (ref) => MadarApi(ref.watch(dioProvider)),
);

final madarApiClientProvider = Provider<MadarApiClient>(
  (ref) => ref.watch(madarApiProvider).madarApi,
);
