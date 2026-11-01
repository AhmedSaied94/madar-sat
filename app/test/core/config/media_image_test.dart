import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madar_sat/core/config/media_image.dart';

/// D2's security follow-up (research R28, US2 scenario 12): an image is loaded only from
/// the active media host over https; anything else is the component's placeholder.
void main() {
  const host = 'https://media.madarsat.test';

  test('a logo on the media host becomes a provider', () {
    final provider = mediaImageFor('$host/logos/team.png', mediaBaseUrl: host);
    expect(provider, isA<CachedNetworkImageProvider>());
    expect((provider! as CachedNetworkImageProvider).url, '$host/logos/team.png');
  });

  test('another host, cleartext, userinfo or a relative path is no image at all', () {
    for (final raw in [
      'https://evil.test/team.png',
      'http://media.madarsat.test/team.png',
      'https://user:pass@media.madarsat.test/team.png',
      '/logos/team.png',
      'javascript:alert(1)',
      null,
      '',
    ]) {
      expect(
        mediaImageFor(raw, mediaBaseUrl: host),
        isNull,
        reason: '$raw must not load',
      );
    }
  });

  test('an unconfigured media host loads nothing', () {
    expect(mediaImageFor('https://media.madarsat.test/x.png', mediaBaseUrl: ''), isNull);
  });
}
