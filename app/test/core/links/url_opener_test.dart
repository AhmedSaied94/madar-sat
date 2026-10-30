import 'package:flutter_test/flutter_test.dart';
import 'package:madar_sat/core/links/url_opener.dart';

/// Editorial links (the reception video) come from the admin, so the app opens only an
/// absolute `https` address and treats anything else as no link at all.
void main() {
  group('httpsUri', () {
    test('keeps an absolute https link', () {
      expect(
        httpsUri('https://www.youtube.com/watch?v=abc'),
        Uri.parse('https://www.youtube.com/watch?v=abc'),
      );
    });

    test('trims the whitespace an admin may paste around it', () {
      expect(httpsUri('  https://example.com/video \n'), Uri.parse('https://example.com/video'));
    });

    test('is null for cleartext, other schemes, relative paths, empty text and null', () {
      for (final raw in [
        'http://example.com/video',
        'javascript:alert(1)',
        'intent://scan/#Intent;scheme=zxing;end',
        'file:///etc/passwd',
        '/video',
        'https://',
        'not a link',
        '',
        '   ',
        null,
      ]) {
        expect(httpsUri(raw), isNull, reason: '$raw');
      }
    });
  });

  group('httpsUri refuses addresses that are built to mislead or to fail', () {
    test('userinfo, which can make a link read as another host', () {
      expect(httpsUri('https://trusted.com@evil.com/'), isNull);
      expect(httpsUri('https://user:pass@example.com/'), isNull);
    });

    test('a port outside 1-65535', () {
      expect(httpsUri('https://example.com:99999/video'), isNull);
      expect(httpsUri('https://example.com:0/video'), isNull);
      expect(httpsUri('https://example.com:8443/video'), Uri.parse('https://example.com:8443/video'));
    });

    test('an address over 2048 characters', () {
      final long = 'https://example.com/${'a' * 2048}';

      expect(httpsUri(long), isNull);
      expect(httpsUri('https://example.com/${'a' * 100}'), isNotNull);
    });
  });

  group('UrlLauncherOpener', () {
    test('is the platform opener the app uses by default', () {
      expect(const UrlLauncherOpener(), isA<UrlOpener>());
    });

    test('opens nothing that is not https, whoever calls it', () async {
      const opener = UrlLauncherOpener();

      expect(await opener.open(Uri.parse('http://example.com/video')), isFalse);
      expect(await opener.open(Uri.parse('file:///etc/passwd')), isFalse);
      expect(await opener.open(Uri.parse('intent://scan/#Intent;scheme=zxing;end')), isFalse);
    });
  });
}
