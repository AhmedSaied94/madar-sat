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

/** The account's own test device; `data: null` until one is saved. */
export function useTestDevice() {
  return useGetTestDevice();
}
