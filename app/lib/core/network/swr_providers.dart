import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../db/database_provider.dart';
import 'dio_provider.dart';
import 'swr_repository.dart';

/// The stale-while-revalidate repository every D2 screen reads through (research R25).
/// Tests override it, or `appDatabaseProvider` and `dioProvider` underneath it.
final swrRepositoryProvider = Provider<SwrRepository>(
  (ref) => SwrRepository(
    dio: ref.watch(dioProvider),
    database: ref.watch(appDatabaseProvider),
  ),
);
