import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madar_sat/core/network/dio_failure.dart';

/// `error.code` is read with the generated `ErrorEnvelope` (research R25 as amended by
/// M-R1-3, constitution VI): a contract change breaks the build here, and a body that is not
/// an envelope carries no code (M-R2-4).
void main() {
  Map<String, Object?> envelope({String code = 'match_not_found'}) => {
        'success': false,
        'data': null,
        'error': {'code': code, 'message': 'for logs only'},
        'meta': <String, Object?>{},
      };

  test('reads the code of a body the generated model parses', () {
    expect(errorCodeOf(envelope()), 'match_not_found');
  });

  test('a body that is not an envelope carries no code', () {
    // A proxy's HTML page, a transport body, and a partial envelope all read as null.
    expect(errorCodeOf('<html>502 Bad Gateway</html>'), isNull);
    expect(errorCodeOf(const <String, Object?>{'message': 'gone'}), isNull);
    expect(errorCodeOf(const <String, Object?>{'error': 'not an object'}), isNull);
    expect(errorCodeOf(null), isNull);
  });

  test('a Dio error carries the envelope code and whether it was transport', () {
    final options = RequestOptions(path: '/v1/matches');
    final api = DioException(
      requestOptions: options,
      type: DioExceptionType.badResponse,
      response: Response<Object?>(requestOptions: options, statusCode: 404, data: envelope()),
    );
    final offline = DioException(
      requestOptions: options,
      type: DioExceptionType.connectionError,
      response: Response<Object?>(requestOptions: options, statusCode: 500, data: envelope()),
    );

    expect(api.asApiFailure.code, 'match_not_found');
    expect(api.asApiFailure.isOffline, isFalse);
    expect(offline.asApiFailure.isOffline, isTrue);
  });
}
