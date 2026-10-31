import '../../../core/network/generated/models/satellite.dart';
import 'orbital_position.dart';
import 'search_normalize.dart';

/// The satellites that match [query] by Arabic name, English name or position (`26`, `7.0`),
/// in the server's order (admin priority). A blank query keeps them all.
List<Satellite> filterSatellites(List<Satellite> satellites, String query) {
  final needle = normalizeSearch(query);
  if (needle.isEmpty) return satellites;
  bool matches(Satellite satellite) =>
      normalizeSearch(satellite.nameAr).contains(needle) ||
      normalizeSearch(satellite.nameEn).contains(needle) ||
      normalizeSearch(OrbitalPosition.label(satellite.orbitalPosition)).contains(needle);
  return [
    for (final satellite in satellites)
      if (matches(satellite)) satellite,
  ];
}

/// My satellites, pinned first, and the rest; each keeps the server's order.
({List<Satellite> mine, List<Satellite> others}) partitionSatellites(
  List<Satellite> satellites, {
  required bool Function(Satellite satellite) isMine,
}) {
  final mine = <Satellite>[];
  final others = <Satellite>[];
  for (final satellite in satellites) {
    (isMine(satellite) ? mine : others).add(satellite);
  }
  return (mine: mine, others: others);
}
