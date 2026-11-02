import 'package:flutter/widgets.dart';

import '../../core/settings/app_settings.dart';

/// How times are shown app-wide (S15 «التوقيت»): the zone and the 12/24-hour choice.
///
/// [MadarApp] installs one from the device settings, so `StatusBlock`, `MatchRow` and the
/// match hero read one inherited value instead of every screen passing two arguments. A
/// widget built outside the app (a golden, a component test) falls back to the device zone
/// and 12-hour times, which is what those have always shown.
class MadarDisplayScope extends InheritedWidget {
  const MadarDisplayScope({
    super.key,
    required this.zone,
    required this.use24h,
    required super.child,
  });

  final MadarZone zone;
  final bool use24h;

  static MadarDisplayScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<MadarDisplayScope>();

  /// The zone in force here.
  static MadarZone zoneOf(BuildContext context) =>
      maybeOf(context)?.zone ?? const MadarZone.auto();

  static bool use24hOf(BuildContext context) => maybeOf(context)?.use24h ?? false;

  @override
  bool updateShouldNotify(MadarDisplayScope oldWidget) =>
      oldWidget.zone != zone || oldWidget.use24h != use24h;
}
