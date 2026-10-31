import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../db/database_provider.dart';
import 'dio_provider.dart';
import 'swr_repository.dart';

part 'swr_providers.g.dart';

/// The stale-while-revalidate repository every D2 screen reads through (research R25).
/// Tests override it, or `appDatabaseProvider` and `dioProvider` underneath it.
@Riverpod(keepAlive: true)
SwrRepository swrRepository(Ref ref) => SwrRepository(
      dio: ref.watch(dioProvider),
      database: ref.watch(appDatabaseProvider),
    );
