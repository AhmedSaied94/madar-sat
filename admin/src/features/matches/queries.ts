import { useQueryClient } from '@tanstack/react-query';

import { useBulk, useListCompetitions, useListMatches, useListSources } from '../../api/generated/admin';
import type { AdminCompetition, ListMatchesParams, SourceItem } from '../../api/generated/admin.schemas';

// A3's data: the day's rows and the two lists its filters and bulk bar need, all over the Orval
// client. A bulk write refreshes every query: a match touches the day list and its own detail.

export function useMatches(params: ListMatchesParams) {
  return useListMatches(params);
}

export function useMatchLookups(): {
  competitions: readonly AdminCompetition[];
  sources: readonly SourceItem[];
} {
  const competitions = useListCompetitions();
  const sources = useListSources();
  return { competitions: competitions.data?.data ?? [], sources: sources.data?.data ?? [] };
}

export function useBulkMatches() {
  const queryClient = useQueryClient();
  return useBulk({
    mutation: {
      onSuccess: () => {
        void queryClient.invalidateQueries();
      },
    },
  });
}
