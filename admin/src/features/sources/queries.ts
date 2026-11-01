import { useGetImportRun, useListSources, useListSourceRuns } from '../../api/generated/admin';

// A13's data: the source health (refetched every 30 s while the page is visible), one source's run
// history with its cursor, and one run's detail.

export function useSources() {
  return useListSources({
    query: { refetchInterval: 30_000, refetchIntervalInBackground: false },
  });
}

export function useSourceRuns(name: string | null, cursor: string | null) {
  return useListSourceRuns(name ?? '', { cursor, limit: 20 }, { query: { enabled: name !== null } });
}

export function useImportRun(runId: number | null) {
  return useGetImportRun(runId ?? 0, { query: { enabled: runId !== null, structuralSharing: false } });
}
