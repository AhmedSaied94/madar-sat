import { useQueryClient } from '@tanstack/react-query';

/** Refreshes every admin query after a write: one record touches lists, details and counts. */
export function useRefreshAdmin(): () => void {
  const queryClient = useQueryClient();
  return () => {
    void queryClient.invalidateQueries();
  };
}
