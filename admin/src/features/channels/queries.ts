import { useChannelFrequencyChanges, useListChannels, useListSatellites } from '../../api/generated/admin';
import type { ListChannelsParams } from '../../api/generated/admin.schemas';

// A8's data: the channel list, the satellites its filter and editor need, and the «سجل التردد» the
// editor draws for an existing carriage.

export function useChannels(params: ListChannelsParams) {
  return useListChannels(params);
}

export function useSatelliteOptions() {
  const query = useListSatellites();
  return query.data?.data ?? [];
}

/** The newest frequency changes of one carriage; nothing to ask until there is an id. */
export function useFrequencyChanges(channelId: number | null) {
  return useChannelFrequencyChanges(channelId ?? 0, { query: { enabled: channelId !== null } });
}
