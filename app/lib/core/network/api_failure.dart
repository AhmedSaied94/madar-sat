import 'package:dio/dio.dart';

/// A failed API call, carrying the stable `error.code` where the server sent one.
///
/// Screens map [code] to Arabic copy (`ErrorCopy.errorCopy`); `error.message` is never
/// shown. [isOffline] is a transport failure: no connection, a timeout, or no answer.
class ApiFailure implements Exception {
  const ApiFailure({this.code, this.isOffline = false});

  /// `error.code` from the envelope, or null for a transport or parse failure.
  final String? code;

  final bool isOffline;

  /// Reads the failure out of a Dio error.
  factory ApiFailure.fromDio(DioException error) {
    final transport = switch (error.type) {
      DioExceptionType.connectionError ||
      DioExceptionType.connectionTimeout ||
      DioExceptionType.sendTimeout ||
      DioExceptionType.receiveTimeout =>
        true,
      _ => false,
    };
    return ApiFailure(code: _codeOf(error.response?.data), isOffline: transport);
  }

  static String? _codeOf(Object? data) {
    if (data is! Map<String, Object?>) return null;
    final body = data['error'];
    if (body is! Map<String, Object?>) return null;
    final code = body['code'];
    return code is String ? code : null;
  }

  @override
  String toString() => 'ApiFailure(code: $code, isOffline: $isOffline)';
}
