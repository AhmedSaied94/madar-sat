import 'package:flutter_test/flutter_test.dart';
import 'package:madar_sat/core/network/generated/models/competition_detail.dart';
import 'package:madar_sat/core/network/swr_repository.dart';

import '../../fixtures/document_swr_cases.dart';
import '../../fixtures/sample_details.dart';

/// S8's reader: `GET /v1/competitions/{id}` cached under `competition:<id>` (T080).
///
/// The page itself waits for B1's T017 contract, which adds the competition's matches and its
/// rights holders' satellites; the reader and its cache key do not.
void main() {
  final detail = sampleCompetitionDetail();
  final payload = competitionDetailJson(detail);

  documentReaderCases<CompetitionDetail>(
    path: '/v1/competitions/${detail.id}',
    key: DocumentKeys.competition(detail.id),
    watch: (repository) => repository.watchCompetitionDetail(detail.id),
    payload: payload,
    decode: (json) => CompetitionDetail.fromJson((json! as Map).cast<String, Object?>()),
  );

  test('the key is competition:<id>', () {
    expect(DocumentKeys.competition(12), 'competition:12');
  });
}
