/// A failed API call, carrying the stable `error.code` where the server sent one, and the
/// numbers the code's Arabic copy uses.
///
/// Screens map [code] to Arabic copy (`ErrorCopy.errorCopy`); `error.message` is never
/// shown. [isOffline] is a transport failure: no connection, a timeout, or no answer.
///
/// Pure, so the domain layer may name it without reaching into Dio; the Dio mapping lives
/// in `dio_failure.dart`.
class ApiFailure implements Exception {
  const ApiFailure({
    this.code,
    this.isOffline = false,
    this.statusCode,
    this.retryAfterS,
    this.maxFollows,
    this.unknownTargets = const {},
    this.unknownSatellites = const [],
  });

  /// `error.code` from the envelope, or null for a transport or parse failure.
  final String? code;

  final bool isOffline;

  /// The HTTP status the server answered, when there was one: `401` is what makes the
  /// device layer register again.
  final int? statusCode;

  /// `meta.retry_after_s` of a `rate_limited` answer, in seconds.
  final int? retryAfterS;

  /// `meta.max` of a `too_many_follows` answer: the follow limit the server enforces.
  final int? maxFollows;

  /// `meta.unknown` of an `unknown_follow_target` answer: the ids the server does not
  /// know, keyed by the wire's kind (`teams`, `competitions`, …); only kinds with some.
  final Map<String, List<int>> unknownTargets;

  /// `meta.unknown` of an `unknown_satellite` answer: the satellite ids the server does
  /// not know.
  final List<int> unknownSatellites;

  @override
  String toString() => 'ApiFailure(code: $code, isOffline: $isOffline, '
      'statusCode: $statusCode, retryAfterS: $retryAfterS, maxFollows: $maxFollows)';
}
