import '../../l10n/app_localizations.dart';
import '../network/api_failure.dart';

/// Stable API `error.code` → Arabic copy (constitution III). `error.message` is never shown.
///
/// The two codes whose words carry a number read it from the envelope's `meta`
/// ([ApiFailure.retryAfterS], [ApiFailure.maxFollows]); when the server sent no meta the
/// documented limit stands in, so the sentence still reads.
extension ErrorCopy on AppLocalizations {
  String errorCopy(String? code, {int? retryAfterS, int? maxFollows}) => switch (code) {
        'not_found' ||
        'match_not_found' ||
        'channel_not_found' ||
        'satellite_not_found' ||
        'competition_not_found' ||
        'team_not_found' ||
        'rights_holder_not_found' ||
        'commentator_not_found' =>
          errorNotFound,
        'validation_error' => errorValidation,
        'not_implemented' => errorNotImplemented,
        'internal_error' => errorInternal,
        // D3's own refusals: a throttled call, a follow set with an id the server no longer
        // has, a set over the limit, and a satellite choice it does not know (public-devices).
        'rate_limited' => errorRateLimited(retryAfterS ?? 60),
        'unknown_follow_target' => errorUnknownFollowTarget,
        'too_many_follows' => errorTooManyFollows(maxFollows ?? 500),
        'unknown_satellite' => errorUnknownSatellite,
        _ => errorNetwork,
      };

  /// The title of an error state: offline has its own, everything else is one sentence.
  String failureTitle(ApiFailure failure) => failure.isOffline ? noConnectionTitle : loadFailedTitle;

  /// The body of an error state: the words for being offline, or the API's `error.code`.
  String failureCopy(ApiFailure failure) => failure.isOffline
      ? noConnectionBody
      : errorCopy(
          failure.code,
          retryAfterS: failure.retryAfterS,
          maxFollows: failure.maxFollows,
        );
}
