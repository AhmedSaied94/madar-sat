import 'package:dio/dio.dart';

import 'api_failure.dart';

/// Reads an [ApiFailure] out of a Dio error, and an `error.code` out of an envelope.
///
/// Its own file so `api_failure.dart` stays pure and the domain layer can name the failure
/// without importing Dio.
extension DioFailure on DioException {
  ApiFailure get asApiFailure {
    final transport = switch (type) {
      DioExceptionType.connectionError ||
      DioExceptionType.connectionTimeout ||
      DioExceptionType.sendTimeout ||
      DioExceptionType.receiveTimeout =>
        true,
      _ => false,
    };
    return ApiFailure(code: errorCodeOf(response?.data), isOffline: transport);
  }

  /// True for a `304 Not Modified`, which Dio reports as an error.
  bool get isNotModified => response?.statusCode == 304;
}

/// The envelope's `error.code`, or null when the body is not one.
String? errorCodeOf(Object? body) {
  if (body is! Map) return null;
  final error = body['error'];
  if (error is! Map) return null;
  final code = error['code'];
  return code is String ? code : null;
}
