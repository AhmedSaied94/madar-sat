import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../settings/zone_holder.dart';
import 'app_database.dart';

part 'database_provider.g.dart';

/// The app's one drift database. Tests override it with an in-memory `AppDatabase`.
///
/// The zone the local days are grouped in comes from [zoneHolderProvider]: the settings
/// provider is built on this database, so a provider dependency here would be a cycle.
@Riverpod(keepAlive: true)
AppDatabase appDatabase(Ref ref) {
  final holder = ref.read(zoneHolderProvider);
  final database = AppDatabase.open(
    offsetAt: (local) => holder.zone.offsetAt(local),
  );
  ref.onDispose(database.close);
  return database;
}
