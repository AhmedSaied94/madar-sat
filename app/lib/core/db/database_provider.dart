import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_database.dart';

/// The app's one drift database. Tests override it with an in-memory `AppDatabase`.
final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final database = AppDatabase.open();
  ref.onDispose(database.close);
  return database;
});
