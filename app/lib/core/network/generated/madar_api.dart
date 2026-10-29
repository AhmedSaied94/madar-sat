// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:dio/dio.dart';

import 'madar_api/madar_api_client.dart';

/// Madar Sat Public API `v1.0.0`.
///
/// Read-only /v1 endpoints for the Madar Sat app.
class MadarApi {
  MadarApi(
    Dio dio, {
    String? baseUrl,
  })  : _dio = dio,
        _baseUrl = baseUrl;

  final Dio _dio;
  final String? _baseUrl;

  static String get version => '1.0.0';

  MadarApiClient? _madarApi;

  MadarApiClient get madarApi => _madarApi ??= MadarApiClient(_dio, baseUrl: _baseUrl);
}
