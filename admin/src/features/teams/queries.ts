import { useListCompetitions, useListTeams } from '../../api/generated/admin';
import type { ListTeamsParams } from '../../api/generated/admin.schemas';

// A5's data: the team list, the competitions its filters and editor need, and one way to refresh
// every query after a write (a team touches the list, its detail and the match rows that name it).

export function useTeams(params: ListTeamsParams) {
  return useListTeams(params);
}

export function useCompetitionOptions() {
  const query = useListCompetitions();
  return query.data?.data ?? [];
}
