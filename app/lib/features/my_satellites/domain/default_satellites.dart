import '../../../core/network/generated/models/satellite_ref.dart';

/// "My satellites" until D3 stores the user's choice (O10, FR-043): Nilesat 7.0W and Badr,
/// found by slug because ids are assigned by the database.
///
/// Domain, not data: organising a match's carriages by "mine" is a product rule, and the
/// data layer only resolves these slugs to ids.
abstract final class MySatellites {
  static const Set<String> defaultSlugs = {'nilesat-7-0w', 'badr-26-0e'};

  /// True when [satellite] is one of my satellites; a carriage without one is not.
  static bool isMine(SatelliteRef? satellite) =>
      satellite != null && defaultSlugs.contains(satellite.slug);
}
