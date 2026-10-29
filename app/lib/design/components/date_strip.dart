import 'package:flutter/material.dart';

import '../../core/format/digits.dart';
import '../../core/l10n/dates.dart';
import '../../core/theme/madar_tokens.dart';
import '../../l10n/app_localizations.dart';

/// The horizontal day picker at the top of Matches.
///
/// Days run right to left, the selected day is filled with `accent`, and today carries a
/// dot marker and the word «اليوم» instead of its weekday.
class DateStrip extends StatelessWidget {
  const DateStrip({
    super.key,
    required this.days,
    required this.selected,
    required this.onSelect,
    this.today,
  });

  final List<DateTime> days;
  final DateTime selected;
  final ValueChanged<DateTime> onSelect;
  final DateTime? today;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final now = today ?? DateTime.now();
    return Semantics(
      container: true,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          for (final day in days)
            _DayCell(
              day: day,
              isToday: _sameDay(day, now),
              isSelected: _sameDay(day, selected),
              weekday: MadarDates.weekdayShort(l, day),
              todayLabel: l.today,
              dayLabel: MadarDigits.plain(day.day),
              onTap: () => onSelect(day),
            ),
        ],
      ),
    );
  }

  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.day,
    required this.isToday,
    required this.isSelected,
    required this.weekday,
    required this.todayLabel,
    required this.dayLabel,
    required this.onTap,
  });

  final DateTime day;
  final bool isToday;
  final bool isSelected;
  final String weekday;
  final String todayLabel;
  final String dayLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.madarColors;
    final foreground = isSelected ? colors.onAccent : colors.textSecondary;
    return Semantics(
      selected: isSelected,
      button: true,
      label: isToday ? todayLabel : '$weekday $dayLabel',
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(MadarRadii.lg),
        child: Container(
          width: MadarSpace.s12 - MadarSpace.s1,
          constraints: const BoxConstraints(minHeight: MadarSpace.s12 + MadarSpace.s2),
          padding: const EdgeInsetsDirectional.symmetric(vertical: MadarSpace.s1),
          decoration: BoxDecoration(
            color: isSelected ? colors.accent : null,
            borderRadius: BorderRadius.circular(MadarRadii.lg),
            border: isToday && !isSelected
                ? Border.all(color: colors.accentText)
                : null,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                isToday ? todayLabel : weekday,
                style: MadarText.textMicro.copyWith(color: foreground),
                maxLines: 1,
              ),
              const SizedBox(height: MadarSpace.s1),
              Text(
                dayLabel,
                style: MadarText.textStrong.copyWith(
                  color: isSelected ? colors.onAccent : colors.textPrimary,
                ),
              ),
              if (isToday) ...[
                const SizedBox(height: MadarSpace.s1),
                Container(
                  width: MadarSpace.s1,
                  height: MadarSpace.s1,
                  decoration: BoxDecoration(
                    color: isSelected ? colors.onAccent : colors.accent,
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
