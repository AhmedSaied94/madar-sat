/// A failed API call, carrying the stable `error.code` where the server sent one.
///
/// Screens map [code] to Arabic copy (`ErrorCopy.errorCopy`); `error.message` is never
/// shown. [isOffline] is a transport failure: no connection, a timeout, or no answer.
///
/// Pure, so the domain layer may name it without reaching into Dio; the Dio mapping lives
/// in `dio_failure.dart`.
class ApiFailure implements Exception {
  const ApiFailure({this.code, this.isOffline = false});

  /// `error.code` from the envelope, or null for a transport or parse failure.
  final String? code;

  final bool isOffline;

  @override
  String toString() => 'ApiFailure(code: $code, isOffline: $isOffline)';
}
