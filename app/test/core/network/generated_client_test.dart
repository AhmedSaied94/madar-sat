import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The app issues every `/v1` request through the generated client (constitution VI,
/// research R25): a renamed operation breaks the build, not the app at run time.
///
/// The paths are pinned here so a contract change has to be acknowledged: if B1 renames or
/// moves one, this test fails until the app's callers and this list are updated together.
void main() {
  final client = File(
    'lib/core/network/generated/madar_api/madar_api_client.dart',
  ).readAsStringSync();

  test('the operations the app calls exist at the contract paths, unwrapped', () {
    const operations = {
      "@GET('/v1/matches')",
      "@GET('/v1/matches/{match_id}')",
      "@GET('/v1/satellites')",
      "@GET('/v1/satellites/{satellite_id}/channels')",
      "@GET('/v1/live')",
    };
    for (final operation in operations) {
      expect(client, contains(operation), reason: '$operation moved or was renamed');
    }
    // `original_http_response: true`: the repository reads the status and the ETag.
    expect(client, contains('Future<HttpResponse<EnvelopeListMatchSummary>>'));
    expect(client, contains('Future<HttpResponse<EnvelopeMatchDetail>>'));
  });

  test('no hand-written API path or raw Dio call outside the generated client', () {
    final rawCall = RegExp(r'\b\w*[dD]io\.(get|post|put|patch|delete)\s*(<|\()');
    final offenders = <String>[];

    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      if (entity.path.contains('/generated/')) continue;
      final source = entity.readAsStringSync();
      if (source.contains("'/v1")) offenders.add('${entity.path}: a literal /v1 path');
      if (rawCall.hasMatch(source)) offenders.add('${entity.path}: a raw Dio call');
    }

    expect(
      offenders,
      isEmpty,
      reason: 'requests go through MadarApiClient, so the paths never drift from the contract',
    );
  });
}
