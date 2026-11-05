import { useListRightsHolders } from '../../api/generated/admin';

// A9's data: the rights holders in their display order. A write touches competitions too, so the
// shared refresh after a save reloads this list and everyone else's.

export function useRightsHolders() {
  const query = useListRightsHolders();
  return {
    rows: query.data?.data ?? [],
    isPending: query.isPending,
    isError: query.isError,
    error: query.error,
    refetch: query.refetch,
  };
}
