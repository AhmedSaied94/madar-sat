import 'package:flutter_test/flutter_test.dart';
import 'package:madar_sat/core/network/generated/models/channel_detail.dart';
import 'package:madar_sat/core/network/swr_repository.dart';

import '../../fixtures/document_swr_cases.dart';
import '../../fixtures/sample_details.dart';

/// S6's reader: `GET /v1/channels/{id}` cached under `channel:<id>` (T080, T082).
void main() {
  final detail = sampleChannelDetail();
  final payload = channelDetailJson(detail);

  documentReaderCases<ChannelDetail>(
    path: '/v1/channels/${detail.id}',
    key: DocumentKeys.channel(detail.id),
    watch: (repository) => repository.watchChannelDetail(detail.id),
    payload: payload,
    decode: (json) => ChannelDetail.fromJson((json! as Map).cast<String, Object?>()),
  );

  test('the key is channel:<id>', () {
    expect(DocumentKeys.channel(5512), 'channel:5512');
    expect(DocumentKeys.channel(1), isNot(DocumentKeys.channel(2)));
  });
}
