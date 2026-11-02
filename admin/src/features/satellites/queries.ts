import { useListSatellites } from '../../api/generated/admin';

// A7's read: the satellites in the order the server keeps. Ordering writes go through the shared
// PUT /satellites/order (T101).

export function useSatellites() {
  const query = useListSatellites();
  return { rows: query.data?.data ?? [], isPending: query.isPending, isError: query.isError, refetch: query.refetch };
}
