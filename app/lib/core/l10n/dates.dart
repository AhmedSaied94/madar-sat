import '../../l10n/app_localizations.dart';
import '../format/digits.dart';

/// Arabic weekday and month names from the ARB file (never the `ar` locale's digits).
abstract final class MadarDates {
  static String weekdayShort(AppLocalizations l, DateTime date) => switch (date.weekday) {
        DateTime.monday => l.weekdayShortMon,
        DateTime.tuesday => l.weekdayShortTue,
        DateTime.wednesday => l.weekdayShortWed,
        DateTime.thursday => l.weekdayShortThu,
        DateTime.friday => l.weekdayShortFri,
        DateTime.saturday => l.weekdayShortSat,
        _ => l.weekdayShortSun,
      };

  static String weekday(AppLocalizations l, DateTime date) => switch (date.weekday) {
        DateTime.monday => l.weekdayMon,
        DateTime.tuesday => l.weekdayTue,
        DateTime.wednesday => l.weekdayWed,
        DateTime.thursday => l.weekdayThu,
        DateTime.friday => l.weekdayFri,
        DateTime.saturday => l.weekdaySat,
        _ => l.weekdaySun,
      };

  static String month(AppLocalizations l, int month) => switch (month) {
        1 => l.month1,
        2 => l.month2,
        3 => l.month3,
        4 => l.month4,
        5 => l.month5,
        6 => l.month6,
        7 => l.month7,
        8 => l.month8,
        9 => l.month9,
        10 => l.month10,
        11 => l.month11,
        _ => l.month12,
      };

  /// `الأربعاء 28 أكتوبر`, the words under the date strip.
  static String full(AppLocalizations l, DateTime local) => l.fullDate(
        MadarDigits.plain(local.day),
        month(l, local.month),
        weekday(l, local),
      );

  /// `20 أكتوبر`, used by the changed-frequency badge.
  static String dayMonth(AppLocalizations l, DateTime local) =>
      '${MadarDigits.plain(local.day)} ${month(l, local.month)}';
}
