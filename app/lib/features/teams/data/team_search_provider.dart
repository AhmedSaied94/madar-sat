import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/network/api_failure.dart';
import '../../../core/network/dio_provider.dart';
import '../../../core/network/generated/models/team_search_item.dart';
import '../../frequencies/domain/search_normalize.dart';

part 'team_search_provider.g.dart';

/// `GET /v1/teams?q=` for S1.2's picker (D1's search).
///
/// The query goes through [normalizeSearch], the app's copy of the server's `ar_normalize`,
/// so «الأهلي» and «الاهلي» ask the same question and get the same teams; two characters
/// are the minimum, because one letter matches half the database.
@riverpod
Future<List<TeamSearchItem>> teamSearch(Ref ref, String query) async {
  final normalized = normalizeSearch(query);
  if (normalized.length < 2) return const [];
  final client = ref.watch(madarApiClientProvider);
  final response = await client.searchTeamsV1TeamsGet(q: normalized, limit: 30);
  final envelope = response.data;
  final teams = envelope.data;
  if (!envelope.success || teams == null) throw ApiFailure(code: envelope.error?.code);
  return teams;
}
