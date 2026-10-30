import '../../../core/format/digits.dart';

/// How a satellite's orbital position reads: `7.0W`, `26.0E`.
///
/// The API sends degrees east as a signed number (system design §6: east positive), so
/// Nilesat at 7.0°W is `-7`. The text is Latin and always shown in an LTR island.
abstract final class OrbitalPosition {
  /// `7.0W`, or null when the satellite has no position (a platform, a terrestrial list).
  static String? label(num? position) =>
      position == null ? null : '${MadarDigits.decimal(position.abs())}${_side(position)}';

  /// `7.0°W`, the form the satellite header uses.
  static String? degrees(num? position) => position == null
      ? null
      : '${MadarDigits.decimal(position.abs())}$_degreeSign${_side(position)}';

  static const String _degreeSign = '°';

  static String _side(num position) => position < 0 ? 'W' : 'E';
}
