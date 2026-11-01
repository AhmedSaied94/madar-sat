import { useQueryClient } from '@tanstack/react-query';

import { useListCompetitions, useListSatellites } from '../../api/generated/admin';

// A6 and A7's reads. Ordering writes arrive with the contract's order endpoints (T101); the lists
// already read the order the server keeps.

export function useCompetitions() {
  const query = useListCompetitions();
  return { rows: query.data?.data ?? [], isPending: query.isPending, isError: query.isError, refetch: query.refetch };
}

export function useSatellites() {
  const query = useListSatellites();
  return { rows: query.data?.data ?? [], isPending: query.isPending, isError: query.isError, refetch: query.refetch };
}

export function useRefreshAdmin(): () => void {
  const queryClient = useQueryClient();
  return () => {
    void queryClient.invalidateQueries();
  };
}
