import '../../l10n/app_localizations.dart';
import '../network/api_failure.dart';

/// Stable API `error.code` → Arabic copy (constitution III). `error.message` is never shown.
extension ErrorCopy on AppLocalizations {
  String errorCopy(String? code) => switch (code) {
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
        _ => errorNetwork,
      };

  /// The title of an error state: offline has its own, everything else is one sentence.
  String failureTitle(ApiFailure failure) => failure.isOffline ? noConnectionTitle : loadFailedTitle;

  /// The body of an error state: the words for being offline, or the API's `error.code`.
  String failureCopy(ApiFailure failure) =>
      failure.isOffline ? noConnectionBody : errorCopy(failure.code);
}
