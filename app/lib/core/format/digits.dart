import 'package:intl/intl.dart';

/// Western (0–9) tabular digits for every number the user sees (research R19).
/// Never let the `ar` locale pick Arabic-Indic digits.
abstract final class MadarDigits {
  static final NumberFormat _grouped = NumberFormat('#,##0', 'en');
  static final NumberFormat _plain = NumberFormat('0', 'en');

  /// Grouped integer, e.g. `1,513`.
  static String of(int value) => _grouped.format(value);

  /// Ungrouped integer, e.g. a year or a score.
  static String plain(int value) => _plain.format(value);

  /// Zero-padded to two digits, e.g. `04`.
  static String two(int value) => value.toString().padLeft(2, '0');

  /// A decimal with a Latin point, e.g. `16.0`.
  static String decimal(num value, {int digits = 1}) =>
      value.toStringAsFixed(digits);
}
