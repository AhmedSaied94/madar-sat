import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madar_sat/core/l10n/error_copy.dart';
import 'package:madar_sat/core/network/api_failure.dart';
import 'package:madar_sat/l10n/app_localizations.dart';

void main() {
  late AppLocalizations l;

  setUp(() async {
    l = await AppLocalizations.delegate.load(const Locale('ar'));
  });

  test('every not-found code reads as «لم نجد ما تبحث عنه»', () {
    for (final code in [
      'not_found',
      'match_not_found',
      'channel_not_found',
      'satellite_not_found',
      'competition_not_found',
      'team_not_found',
      'rights_holder_not_found',
      'commentator_not_found',
    ]) {
      expect(l.errorCopy(code), 'لم نجد ما تبحث عنه', reason: code);
    }
  });

  test('an unknown code or none reads as a connection problem, never the server message', () {
    expect(l.errorCopy('something_new'), l.errorNetwork);
    expect(l.errorCopy(null), l.errorNetwork);
  });

  group('a failed call', () {
    test('offline has its own title and body', () {
      const failure = ApiFailure(isOffline: true);

      expect(l.failureTitle(failure), 'لا يوجد اتصال بالإنترنت');
      expect(l.failureCopy(failure), 'تأكد من اتصالك بالإنترنت وحاول مرة أخرى');
    });

    test('anything else uses the load-failed title and the code copy', () {
      const failure = ApiFailure(code: 'match_not_found');

      expect(l.failureTitle(failure), 'تعذّر تحميل البيانات');
      expect(l.failureCopy(failure), 'لم نجد ما تبحث عنه');
    });
  });
  group('D3\'s refusals (M-R1-8)', () {
    test('each code reads as its own sentence, never the connection one', () {
      expect(l.errorCopy('unknown_satellite'), isNot(l.errorNetwork));
      expect(l.errorCopy('unknown_follow_target'), isNot(l.errorNetwork));
      expect(l.errorCopy('too_many_follows', maxFollows: 500), contains('500'));
      expect(l.errorCopy('rate_limited', retryAfterS: 12), contains('12'));
    });

    test('a rate-limited answer without meta still names a wait', () {
      expect(l.errorCopy('rate_limited'), contains('60'));
    });

    test('the numbers come from the failure the screen holds', () {
      const failure = ApiFailure(code: 'too_many_follows', maxFollows: 500);
      expect(l.failureCopy(failure), contains('500'));
      const limited = ApiFailure(code: 'rate_limited', retryAfterS: 5);
      expect(l.failureCopy(limited), contains('5'));
    });
  });

}
