import { useQueryClient } from '@tanstack/react-query';

import type { ListNotificationsParams } from '../../api/generated/admin.schemas';
import { useGetReach, useGetTestDevice, useListNotifications } from '../../api/generated/admin';

// A15's data: the outbox with its cursor, the audience's reach, and the caller's saved test device.

/** The outbox, newest first. Producers don't bump a dataset per row, so the 15 s version bucket and
 *  this 30 s read are what bring a new row to the screen (contract admin-api "GET notifications"). */
export function useOutbox(params: ListNotificationsParams) {
  return useListNotifications(params, {
    query: { refetchInterval: 30_000, refetchIntervalInBackground: false },
  });
}

/** How many devices an audience reaches. Nothing to ask until the audience carries its id. */
export function useReach(kind: string | null, id: number | null) {
  const params = kind === null ? undefined : id === null ? { kind } : { kind, id };
  return useGetReach(params, {
    query: { enabled: kind !== null && (kind === 'all' || id !== null), staleTime: 0 },
  });
}

const TEST_POLL_MS = 2_000;
const TEST_POLL_TRIES = 30;
const IN_FLIGHT: readonly string[] = ['pending', 'sending'];

/**
 * A test send's outbox row, read back from the log until it is sent or failed (A-R1-8): the POST
 * answers with the row still queued, so that answer alone is never reported as delivered. The log
 * has no per-row read, so this polls the newest page and stops on a final status or after
 * `TEST_POLL_TRIES` reads (`gaveUp`).
 */
export function useTestOutcome(id: number | null) {
  const query = useListNotifications(
    { limit: 20 },
    {
      query: {
        enabled: id !== null,
        refetchInterval: (current) => {
          const row = current.state.data?.data?.find((candidate) => candidate.id === id);
          if (row !== undefined && !IN_FLIGHT.includes(row.status)) return false;
          return current.state.dataUpdateCount >= TEST_POLL_TRIES ? false : TEST_POLL_MS;
        },
      },
    },
  );
  const client = useQueryClient();
  const row = id === null ? null : (query.data?.data?.find((candidate) => candidate.id === id) ?? null);
  const settled = row !== null && !IN_FLIGHT.includes(row.status);
  const reads = client.getQueryState(query.queryKey)?.dataUpdateCount ?? 0;
  return { row, settled, gaveUp: id !== null && !settled && reads >= TEST_POLL_TRIES };
}

/** The account's own test device; `data: null` until one is saved. */
export function useTestDevice() {
  return useGetTestDevice();
}
