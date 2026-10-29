import 'digits.dart';

/// A local day expressed as the UTC window the API expects (FR-048).
class DayWindow {
  const DayWindow({required this.from, required this.to});

  /// Inclusive start, UTC.
  final DateTime from;

  /// Exclusive end, UTC.
  final DateTime to;

  Duration get length => to.difference(from);
}

/// Kickoff times and local-day windows (research R19).
///
/// All times are stored UTC. The app groups by the device's local day and sends that
/// window as UTC instants, so a DST day is 23 or 25 hours and never a duplicated hour.
abstract final class MadarTime {
  /// A kickoff in the device's local time, in 12 h with [am]/[pm] markers or in 24 h.
  /// Returns null when the kickoff is unknown (`time_tbd`).
  static String? kickoff(
    DateTime? kickoffUtc, {
    bool use24h = false,
    required String am,
    required String pm,
  }) {
    if (kickoffUtc == null) return null;
    final local = kickoffUtc.toLocal();
    final hour24 = local.hour;
    if (use24h) {
      return '${MadarDigits.two(hour24)}:${MadarDigits.two(local.minute)}';
    }
    final hour12 = hour24 % 12 == 0 ? 12 : hour24 % 12;
    final marker = hour24 < 12 ? am : pm;
    return '${MadarDigits.plain(hour12)}:${MadarDigits.two(local.minute)} $marker';
  }

  /// Whole minutes from [now] to [kickoffUtc]; negative once it has passed.
  static int minutesUntil(DateTime kickoffUtc, {DateTime? now}) =>
      kickoffUtc.difference(now ?? DateTime.now().toUtc()).inMinutes;

  /// True when the kickoff is within the next hour (the `بعد 25 د` variant).
  static bool isImminent(DateTime kickoffUtc, {DateTime? now}) {
    final minutes = minutesUntil(kickoffUtc, now: now);
    return minutes > 0 && minutes <= 60;
  }

  /// The local day containing [localNow], converted to UTC.
  ///
  /// [offsetAt] is the zone offset at a local wall-clock instant; it defaults to the
  /// platform zone. It is injectable so the DST path is testable without changing the
  /// process zone: the two local midnights can carry different offsets.
  static DayWindow dayWindow(
    DateTime localNow, {
    Duration Function(DateTime local)? offsetAt,
  }) {
    final zone = offsetAt ?? _localOffset;
    final startLocal = DateTime(localNow.year, localNow.month, localNow.day);
    final endLocal = DateTime(localNow.year, localNow.month, localNow.day + 1);
    return DayWindow(
      from: _wallClockToUtc(startLocal, zone(startLocal)),
      to: _wallClockToUtc(endLocal, zone(endLocal)),
    );
  }

  static Duration _localOffset(DateTime local) => local.timeZoneOffset;

  static DateTime _wallClockToUtc(DateTime wallClock, Duration offset) =>
      DateTime.utc(
        wallClock.year,
        wallClock.month,
        wallClock.day,
        wallClock.hour,
        wallClock.minute,
      ).subtract(offset);
}
