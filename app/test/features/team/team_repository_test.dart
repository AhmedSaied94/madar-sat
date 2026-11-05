import 'package:flutter_test/flutter_test.dart';
import 'package:madar_sat/core/network/generated/models/team_detail.dart';
import 'package:madar_sat/core/network/swr_repository.dart';

import '../../fixtures/document_swr_cases.dart';
import '../../fixtures/sample_details.dart';

/// S7's reader: `GET /v1/teams/{id}` cached under `team:<id>` (T080, T082). S9 reads the same
/// document, so the two screens share one cached copy and one ETag.
void main() {
  final detail = sampleTeamDetail();
  final payload = teamDetailJson(detail);

  documentReaderCases<TeamDetail>(
    path: '/v1/teams/${detail.id}',
    key: DocumentKeys.team(detail.id),
    watch: (repository) => repository.watchTeamDetail(detail.id),
    payload: payload,
    decode: (json) => TeamDetail.fromJson((json! as Map).cast<String, Object?>()),
  );

  test('the key is team:<id>, the one S9 already reads', () {
    expect(DocumentKeys.team(1), 'team:1');
  });
}
