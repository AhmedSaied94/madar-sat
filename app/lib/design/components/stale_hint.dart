import 'package:flutter/material.dart';

import '../../core/format/digits.dart';
import '../../core/theme/madar_tokens.dart';
import '../../l10n/app_localizations.dart';

/// A small clock and the age of the data it sits next to: «آخر تحديث منذ 7 د».
///
/// A screen shows it once a copy is past its freshness target (`Freshness` in
/// `swr_repository.dart`), never on fresh data.
class StaleHint extends StatelessWidget {
  const StaleHint({super.key, required this.age});

  final Duration age;

  /// The age in compact Arabic with Western digits: الآن, منذ 5 د, منذ 3 س, منذ 2 يوم.
  static String ageText(AppLocalizations l, Duration age) {
    if (age < const Duration(minutes: 1)) return l.ageJustNow;
    if (age < const Duration(hours: 1)) return l.ageMinutes(MadarDigits.plain(age.inMinutes));
    if (age < const Duration(days: 1)) return l.ageHours(MadarDigits.plain(age.inHours));
    return l.ageDays(MadarDigits.plain(age.inDays));
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final colors = context.madarColors;
    final text = l.staleHint(ageText(l, age));
    return Semantics(
      container: true,
      label: text,
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.schedule, size: MadarText.textCaption.fontSize, color: colors.textTertiary),
          const SizedBox(width: MadarSpace.s1),
          Flexible(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: MadarText.textCaption.copyWith(color: colors.textTertiary),
            ),
          ),
        ],
      ),
    );
  }
}
