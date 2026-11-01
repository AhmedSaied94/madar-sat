import { useGetDashboard } from '../../api/generated/admin';
import { cairoDay, cairoDayBounds } from '../../lib/cairoTime';

// A2's data: today's dashboard, refetched every 60 s while the page is visible (R24). The window is
// the Cairo day, sent as the UTC bounds the admin API expects.

export function useDashboard(now: string = new Date().toISOString()) {
  const bounds = cairoDayBounds(cairoDay(now));
  return useGetDashboard(
    { from: bounds.from, to: bounds.to },
    { query: { refetchInterval: 60_000, refetchIntervalInBackground: false } },
  );
}
