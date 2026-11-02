import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'app_settings.dart';

part 'zone_holder.g.dart';

/// The zone the drift layer groups local days in, as a plain mutable value.
///
/// The database is built before anyone has read the settings, and the settings provider is
/// built *on* the database, so the database cannot depend on it: this holder breaks that
/// cycle. `AppSettings` writes it after every read and write; before the first read lands
/// the device's own zone stands, which is the default choice anyway.
class ZoneHolder {
  MadarZone zone = const MadarZone.auto();
}

/// The one holder (keepAlive: the database reads it for its whole life).
@Riverpod(keepAlive: true)
ZoneHolder zoneHolder(Ref ref) => ZoneHolder();
