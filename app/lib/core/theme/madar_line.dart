/// Line widths the token set has no step for.
///
/// The design package draws every hairline as 1px (`.dv` dividers, the dashed outline on
/// estimated-live pills, the logo edges), but `tokens.json` has no width or stroke group, so
/// the value lives here — the theme layer, where raw visual values belong — and never in
/// widget code (FR-042, SC-008). When the design package gains a stroke group, move it into
/// `tokens.json`, regenerate, and re-copy `madar_tokens.dart`.
abstract final class MadarLine {
  /// A one-pixel hairline: dividers, painted outlines, dashed pill borders.
  static const double hairline = 1;
}
