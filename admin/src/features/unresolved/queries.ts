import { useListNames } from '../../api/generated/admin';
import type { ListNamesParams } from '../../api/generated/admin.schemas';

// A13's queue data: the names the importers couldn't match, by `last_seen_at`, with the board's count
// in `meta.open_count`. It refetches every 30 s while the page is visible, like the source cards.

export function useUnresolvedNames(params: ListNamesParams) {
  return useListNames(params, {
    query: { refetchInterval: 30_000, refetchIntervalInBackground: false },
  });
}
