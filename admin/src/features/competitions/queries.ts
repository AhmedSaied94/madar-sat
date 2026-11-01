import { useListCompetitions } from '../../api/generated/admin';

// A6's read: the competitions in the order the server keeps. Ordering writes go through the shared
// PUT /competitions/order (T101).

export function useCompetitions() {
  const query = useListCompetitions();
  return { rows: query.data?.data ?? [], isPending: query.isPending, isError: query.isError, refetch: query.refetch };
}
