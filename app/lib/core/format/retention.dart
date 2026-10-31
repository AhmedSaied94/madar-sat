/// How long the local cache keeps what it holds (research R25).
///
/// A neutral core constant set: the drift schema prunes to it, and the screens derive the
/// days they page through from it, so neither has to reach into the other.
abstract final class Retention {
  /// Local days kept behind today.
  static const int daysBack = 1;

  /// Local days kept ahead of today.
  static const int daysAhead = 6;

  /// A cached document nobody has revalidated for this long is dropped on start, so
  /// match-detail copies of long-gone matches do not pile up.
  static const Duration documents = Duration(days: 14);
}
