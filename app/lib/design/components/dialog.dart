import 'package:flutter/material.dart';

import '../../core/theme/madar_tokens.dart';
import '../../l10n/app_localizations.dart';
import 'button.dart';

/// The design system's confirmation dialog: a title, one or two lines of consequence, and
/// two actions — a ghost cancel and the verb itself (Dialog README).
///
/// Only irreversible actions use it, and the action repeats the verb («حذف»), never «نعم».
class MadarDialog extends StatelessWidget {
  const MadarDialog({
    super.key,
    required this.title,
    required this.body,
    required this.confirmLabel,
    this.cancelLabel,
    this.danger = true,
  });

  final String title;
  final String body;
  final String confirmLabel;
  final String? cancelLabel;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final colors = context.madarColors;
    return AlertDialog(
      backgroundColor: colors.elevated,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(MadarRadii.xxl)),
      title: Text(title, style: MadarText.heading2.copyWith(color: colors.textPrimary)),
      content: Text(body, style: MadarText.textBody.copyWith(color: colors.textSecondary)),
      actions: [
        MadarButton(
          label: cancelLabel ?? l.cancel,
          variant: MadarButtonVariant.ghost,
          size: MadarButtonSize.small,
          onPressed: () => Navigator.of(context).pop(false),
        ),
        MadarButton(
          label: confirmLabel,
          variant: danger ? MadarButtonVariant.danger : MadarButtonVariant.primary,
          size: MadarButtonSize.small,
          onPressed: () => Navigator.of(context).pop(true),
        ),
      ],
    );
  }
}

/// Shows [MadarDialog] and answers true when its action was chosen. Back and the scrim
/// cancel, and focus returns to the trigger when it closes.
Future<bool> showMadarDialog(
  BuildContext context, {
  required String title,
  required String body,
  required String confirmLabel,
  String? cancelLabel,
  bool danger = true,
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => MadarDialog(
      title: title,
      body: body,
      confirmLabel: confirmLabel,
      cancelLabel: cancelLabel,
      danger: danger,
    ),
  );
  return confirmed ?? false;
}
