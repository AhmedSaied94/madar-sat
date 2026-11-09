import 'package:flutter/material.dart';

import '../../../../core/theme/madar_tokens.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/lineup_layout.dart';

/// A player's mark in words, for a screen reader.
String lineupMarkLabel(AppLocalizations l, LineupMark mark) => switch (mark) {
      LineupMark.goal => l.lineupGoalMark,
      LineupMark.redCard => l.lineupRedMark,
    };

/// A goal or red-card mark. A red card uses `error`: `live` red is only for live matches.
class LineupMarkIcon extends StatelessWidget {
  const LineupMarkIcon({super.key, required this.mark});

  final LineupMark mark;

  @override
  Widget build(BuildContext context) {
    final colors = context.madarColors;
    return Icon(
      switch (mark) {
        LineupMark.goal => Icons.sports_soccer,
        LineupMark.redCard => Icons.rectangle,
      },
      size: MadarText.textCaption.fontSize,
      color: switch (mark) {
        LineupMark.goal => colors.accentText,
        LineupMark.redCard => colors.error,
      },
    );
  }
}
