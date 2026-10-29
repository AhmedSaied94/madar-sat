import 'package:dio/dio.dart';
import 'package:madar_sat/core/network/generated/export.dart';

/// A spec-true fake of the generated client: only the matches call is implemented.
class FakeApiClient implements MadarApiClient {
  FakeApiClient({this.rows = const [], this.errorCode});

  final List<MatchSummary> rows;
  final String? errorCode;

  DateTime? lastFrom;
  DateTime? lastTo;

  @override
  Future<EnvelopeListMatchSummary> listMatchesV1MatchesGet({
    required DateTime from,
    required DateTime to,
    Sport? sport,
    int? competitionId,
    int? teamId,
    String? satelliteIds,
    String? mySatelliteIds,
    Status? status,
  }) async {
    lastFrom = from;
    lastTo = to;
    final code = errorCode;
    if (code != null) {
      final options = RequestOptions(path: '/v1/matches');
      throw DioException(
        requestOptions: options,
        response: Response<dynamic>(
          requestOptions: options,
          statusCode: 404,
          data: {
            'success': false,
            'data': null,
            'error': {'code': code, 'message': 'for logs only'},
            'meta': <String, Object?>{},
          },
        ),
      );
    }
    return EnvelopeListMatchSummary(
      data: rows,
      error: null,
      meta: const <String, Object?>{},
      success: true,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError(
        'FakeApiClient only implements listMatchesV1MatchesGet',
      );
}
