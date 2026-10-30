import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/links/url_opener.dart';
import '../../../l10n/app_localizations.dart';

/// Opens a satellite's reception video, and says so when nothing could (no browser, no
/// network handler): the tap is never silently lost.
Future<void> openReception(BuildContext context, WidgetRef ref, Uri url) async {
  final message = AppLocalizations.of(context).s5ReceptionOpenFailed;
  final messenger = ScaffoldMessenger.maybeOf(context);
  var opened = false;
  try {
    opened = await ref.read(urlOpenerProvider).open(url);
  } catch (_) {
    // The platform refused (no handler for the link); the snack bar below tells the user.
    opened = false;
  }
  if (!opened) messenger?.showSnackBar(SnackBar(content: Text(message)));
}
