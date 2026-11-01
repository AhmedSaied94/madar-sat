import { useListChannels, useListSatellites } from '../../api/generated/admin';
import type { ListChannelsParams } from '../../api/generated/admin.schemas';

// A8's data: the channel list, and the satellites its filter and editor need.

export function useChannels(params: ListChannelsParams) {
  return useListChannels(params);
}

export function useSatelliteOptions() {
  const query = useListSatellites();
  return query.data?.data ?? [];
}
