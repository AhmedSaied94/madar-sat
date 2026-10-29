import 'package:dio/dio.dart';

import '../../../core/format/time.dart';
import '../../../core/network/generated/export.dart';

/// A failed matches call, carrying the stable API `error.code` where there is one.
class MatchesFailure implements Exception {
  const MatchesFailure(this.code);

  /// `error.code` from the envelope, or null for a transport failure.
  final String? code;

  @override
  String toString() => 'MatchesFailure($code)';
}

/// Wraps the generated client for the matches route and computes the device's local day
/// as UTC bounds (FR-048).
///
/// D1 deviation (plan.md Complexity Tracking): this reads `/v1/matches` directly; the
/// stale-while-revalidate repository from drift arrives on D2.
class MatchesApi {
  const MatchesApi(this._client);

  final MadarApiClient _client;

  Future<List<MatchSummary>> day({DateTime? now, DayWindow? window}) async {
    final day = window ?? MadarTime.dayWindow(now ?? DateTime.now());
    try {
      final envelope = await _client.listMatchesV1MatchesGet(
        from: day.from,
        to: day.to,
      );
      if (!envelope.success || envelope.data == null) {
        throw MatchesFailure(envelope.error?.code);
      }
      return envelope.data!;
    } on DioException catch (error) {
      throw MatchesFailure(_codeOf(error));
    }
  }

  static String? _codeOf(DioException error) {
    final data = error.response?.data;
    if (data is Map<String, Object?>) {
      final body = data['error'];
      if (body is Map<String, Object?>) {
        final code = body['code'];
        if (code is String) return code;
      }
    }
    return null;
  }
}
