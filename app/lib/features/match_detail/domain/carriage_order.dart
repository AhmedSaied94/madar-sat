import '../../../core/network/generated/models/access.dart';
import '../../../core/network/generated/models/carriage_entry.dart';
import '../../../core/network/generated/models/platform_group.dart';
import '../../../core/network/generated/models/satellite_ref.dart';
import '../../my_satellites/data/my_satellites_provider.dart';

/// The carriages on one satellite that is not mine, in S3's order.
class SatelliteGroup {
  const SatelliteGroup({required this.satellite, required this.carriages});

  final SatelliteRef satellite;
  final List<CarriageEntry> carriages;
}

/// The three parts of "where to watch" (FR-042, FR-043), each already in display order.
class WhereToWatch {
  const WhereToWatch({
    this.mine = const [],
    this.otherSatellites = const [],
    this.withoutSatellite = const [],
    this.platforms = const [],
  });

  /// 1 · on my satellites.
  final List<CarriageEntry> mine;

  /// 2 · one group per other satellite.
  final List<SatelliteGroup> otherSatellites;

  /// 3 · links with no satellite (terrestrial), listed with the platforms.
  final List<CarriageEntry> withoutSatellite;

  /// 3 · streaming platforms, by region as the server grouped them.
  final List<PlatformGroup> platforms;

  int get satelliteCarriageCount =>
      mine.length + otherSatellites.fold(0, (sum, group) => sum + group.carriages.length);

  int get carriageCount => satelliteCarriageCount + withoutSatellite.length;

  int get platformCount => platforms.fold(0, (sum, group) => sum + group.items.length);

  /// Every way to watch: the number the toolbar shows.
  int get total => carriageCount + platformCount;

  bool get isEmpty => total == 0;
}

/// Puts a match's carriages into S3's three parts.
///
/// * my satellites first ([isMine]; the O10 default, Nilesat 7.0W and Badr, until D3),
///   then each other satellite, then the links with no satellite and the [platforms];
/// * inside a group a free link comes before an encrypted one, then the order the server
///   sent. The API sends no `sort_order`, but it already sorts a match's links by it and
///   then by `id`, so the list position stands for both and no `id` tie-break is left to
///   make;
/// * the other satellites are ordered by where each first appears in the server's list,
///   which is the server's satellite priority.
///
/// The API never sends a hidden link, and nothing is added, merged or dropped here.
WhereToWatch orderCarriages({
  required List<CarriageEntry> carriages,
  required List<PlatformGroup> platforms,
  bool Function(SatelliteRef? satellite) isMine = MySatellites.isMine,
}) {
  final mine = <_Listed>[];
  final withoutSatellite = <_Listed>[];
  final bySatellite = <int, List<_Listed>>{};
  final satellites = <int, SatelliteRef>{};

  for (var index = 0; index < carriages.length; index++) {
    final listed = _Listed(index, carriages[index]);
    final satellite = listed.entry.satellite;
    if (satellite == null) {
      withoutSatellite.add(listed);
    } else if (isMine(satellite)) {
      mine.add(listed);
    } else {
      satellites[satellite.id] = satellite;
      (bySatellite[satellite.id] ??= []).add(listed);
    }
  }

  return WhereToWatch(
    mine: _sorted(mine),
    otherSatellites: [
      for (final entry in bySatellite.entries)
        SatelliteGroup(satellite: satellites[entry.key]!, carriages: _sorted(entry.value)),
    ],
    withoutSatellite: _sorted(withoutSatellite),
    platforms: [
      for (final group in platforms)
        if (group.items.isNotEmpty) group,
    ],
  );
}

/// [source] narrowed by the toolbar: [freeOnly] keeps free carriages (a platform's access is
/// unknown, so platforms go), and a [query] keeps what matches a channel or satellite name,
/// or the digits of a frequency. Groups left empty disappear; with no filter [source] itself
/// comes back.
WhereToWatch filterWhereToWatch(
  WhereToWatch source, {
  bool freeOnly = false,
  String query = '',
}) {
  final needle = query.trim().toLowerCase();
  if (!freeOnly && needle.isEmpty) return source;

  bool keep(CarriageEntry entry) =>
      (!freeOnly || entry.access == Access.free) && (needle.isEmpty || _matches(entry, needle));

  return WhereToWatch(
    mine: source.mine.where(keep).toList(growable: false),
    otherSatellites: [
      for (final group in source.otherSatellites)
        if (group.carriages.any(keep))
          SatelliteGroup(
            satellite: group.satellite,
            carriages: group.carriages.where(keep).toList(growable: false),
          ),
    ],
    withoutSatellite: source.withoutSatellite.where(keep).toList(growable: false),
    platforms: freeOnly
        ? const []
        : [
            for (final group in source.platforms)
              if (group.items.any((item) => _anyContains(needle, [item.name, ?item.country])))
                group.copyWith(
                  items: [
                    for (final item in group.items)
                      if (_anyContains(needle, [item.name, ?item.country])) item,
                  ],
                ),
          ],
  );
}

bool _matches(CarriageEntry entry, String needle) => _anyContains(needle, [
      entry.name,
      ?entry.displayName,
      ?entry.satellite?.nameAr,
      ?entry.satellite?.nameEn,
      if (entry.frequency != null) '${entry.frequency!.mhz}',
    ]);

/// True when [needle] (already lower-cased) is in any of [fields].
bool _anyContains(String needle, List<String> fields) {
  if (needle.isEmpty) return true;
  return fields.any((field) => field.toLowerCase().contains(needle));
}

/// A carriage with the position the server listed it at.
class _Listed {
  const _Listed(this.index, this.entry);

  final int index;
  final CarriageEntry entry;
}

List<CarriageEntry> _sorted(List<_Listed> items) {
  final copy = [...items]..sort((a, b) {
      final byAccess = _accessRank(a.entry).compareTo(_accessRank(b.entry));
      return byAccess != 0 ? byAccess : a.index.compareTo(b.index);
    });
  return [for (final item in copy) item.entry];
}

/// Free first; encrypted and unknown access after it.
int _accessRank(CarriageEntry entry) => entry.access == Access.free ? 0 : 1;
