import 'package:dio/dio.dart';

import 'api_failure.dart';
import 'generated/models/error_envelope.dart';

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
    final body = response?.data;
    final meta = body is Map<String, Object?> ? body['meta'] : null;
    int? metaInt(String key) => meta is Map && meta[key] is num ? (meta[key] as num).toInt() : null;
    return ApiFailure(
      code: errorCodeOf(body),
      isOffline: transport,
      statusCode: response?.statusCode,
      // The numbers the Arabic copy uses (`rate_limited`'s `retry_after_s`,
      // `too_many_follows`'s `max`), read from the envelope's `meta` (public-devices).
      retryAfterS: metaInt('retry_after_s'),
      maxFollows: metaInt('max'),
    );
  }

  /// True for a `304 Not Modified`, which Dio reports as an error.
  bool get isNotModified => response?.statusCode == 304;
}

/// The envelope's `error.code`, or null when the body is not one.
///
/// The body is read by the generated `ErrorEnvelope`, so a contract change breaks the build
/// here instead of silently mapping every code to the generic copy (research R25, M-R2-4).
/// A proxy page, a transport body or a body the model cannot read is not an envelope, and
/// carries no code.
String? errorCodeOf(Object? body) {
  if (body is! Map<String, Object?>) return null;
  try {
    return ErrorEnvelope.fromJson(body).error.code;
  } on Object {
    return null;
  }
}
