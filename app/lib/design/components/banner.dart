import 'package:flutter/material.dart';

import '../../core/theme/madar_line.dart';
import '../../core/theme/madar_tokens.dart';
import '../../l10n/app_localizations.dart';
import 'stale_hint.dart';

/// The slim offline banner: «أنت غير متصل — آخر تحديث منذ 12 دقيقة» (Banner README, R29).
///
/// It pushes the content down rather than covering it, and it is the only banner D3 shows:
/// the soft-update one waits for D8.
class OfflineBanner extends StatelessWidget {
  const OfflineBanner({super.key, required this.age});

  /// The age of the newest cached copy, or null when nothing is cached yet.
  final Duration? age;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final colors = context.madarColors;
    final text = l.s0OfflineBanner(
      age == null ? l.ageJustNow : StaleHint.ageText(l, age!),
    );
    return Semantics(
      container: true,
      liveRegion: true,
      label: text,
      excludeSemantics: true,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsetsDirectional.symmetric(
          horizontal: MadarSpace.s4,
          vertical: MadarSpace.s1,
        ),
        color: colors.surface2,
        child: Row(
          children: [
            Icon(
              Icons.wifi_off,
              size: MadarText.textBody.fontSize,
              color: colors.textSecondary,
            ),
            const SizedBox(width: MadarSpace.s2),
            Flexible(
              child: Text(
                text,
                style: MadarText.textCaption.copyWith(color: colors.textSecondary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The app's snackbar: inverted, one line, an optional action in `snackbar-action`
/// (Banner README). Used for undoable actions and short confirmations.
abstract final class MadarSnackbar {
  static void show(
    BuildContext context,
    String message, {
    String? actionLabel,
    VoidCallback? onAction,
    Duration duration = const Duration(seconds: 4),
  }) {
    final colors = context.madarColors;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Text(
            message,
            style: MadarText.textBody.copyWith(color: colors.textOnInverse),
          ),
          backgroundColor: colors.textPrimary,
          behavior: SnackBarBehavior.floating,
          duration: duration,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(MadarRadii.lg)),
          action: actionLabel == null || onAction == null
              ? null
              : SnackBarAction(
                  label: actionLabel,
                  textColor: colors.snackbarAction,
                  onPressed: onAction,
                ),
        ),
      );
  }
}

/// The Android exit snackbar of S0: «اضغط رجوع مرة أخرى للخروج» (contract app-screens).
class ExitSnackbar extends StatelessWidget {
  const ExitSnackbar({super.key});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final colors = context.madarColors;
    return Container(
      margin: const EdgeInsetsDirectional.symmetric(horizontal: MadarSpace.s3),
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: MadarSpace.s4,
        vertical: MadarSpace.s3,
      ),
      decoration: BoxDecoration(
        color: colors.textPrimary,
        borderRadius: BorderRadius.circular(MadarRadii.lg),
        border: Border.all(color: colors.divider, width: MadarLine.hairline),
      ),
      child: Text(
        l.s0ExitToClose,
        style: MadarText.textLabel.copyWith(color: colors.textOnInverse),
      ),
    );
  }
}
