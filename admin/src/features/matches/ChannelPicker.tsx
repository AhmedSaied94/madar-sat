import { useMemo, useState, type ReactElement } from 'react';

import { useListChannels, useListSatellites } from '../../api/generated/admin';
import type { AdminChannelCategory, AdminSatellite, ChannelItem, Kind } from '../../api/generated/admin.schemas';
import { Button } from '../../components/Button/Button';
import { editor as copy } from '../../i18n/ar';

// A4's channel picker: search, then filter by category, satellite or platform, and add the channel to
// this match's links. The satellite and frequency are on every row: two channels can share a name
// across positions (A-R1-7).
interface ChannelPickerProps {
  onAdd: (channel: ChannelItem) => void;
}

export function ChannelPicker({ onAdd }: ChannelPickerProps): ReactElement {
  const [q, setQ] = useState('');
  const [category, setCategory] = useState<AdminChannelCategory | ''>('');
  const [satelliteId, setSatelliteId] = useState<string>('');
  const { data: satellites } = useListSatellites();
  const satelliteList: readonly AdminSatellite[] = useMemo(() => satellites?.data ?? [], [satellites]);

  // «منصات بلا قمر» is the platform filter: no satellite, no frequency.
  const platformOnly = satelliteId === 'platform';
  const kind: Kind | null = platformOnly ? 'platform' : null;

  const { data, isFetching } = useListChannels({
    q: q.trim() === '' ? null : q.trim(),
    category: category === '' ? null : category,
    kind,
    satellite_id: platformOnly || satelliteId === '' ? null : Number(satelliteId),
    limit: 20,
  });
  const channels: readonly ChannelItem[] = data?.data ?? [];

  return (
    <div className="flex min-w-0 flex-col gap-2">
      <div className="flex flex-wrap items-center gap-2">
        <input
          type="search"
          aria-label={copy.searchChannel}
          placeholder={copy.searchChannel}
          value={q}
          onChange={(event) => setQ(event.target.value)}
          className="text-label h-8 min-w-0 flex-1 rounded-md bg-bg px-3 text-text-primary ring-1 ring-inset ring-divider-strong"
        />
        <select
          aria-label={copy.category}
          value={category ?? ''}
          onChange={(event) => setCategory(event.target.value as AdminChannelCategory | '')}
          className="text-label h-8 rounded-md bg-bg px-2 text-text-primary ring-1 ring-inset ring-divider-strong"
        >
          <option value="">{`${copy.category}: ${copy.all}`}</option>
          <option value="sports">{copy.sports}</option>
          <option value="entertainment">{copy.entertainment}</option>
        </select>
        <select
          aria-label={copy.satellite}
          value={satelliteId}
          onChange={(event) => setSatelliteId(event.target.value)}
          className="text-label h-8 rounded-md bg-bg px-2 text-text-primary ring-1 ring-inset ring-divider-strong"
        >
          <option value="">{`${copy.satellite}: ${copy.all}`}</option>
          <option value="platform">{copy.noSatellite}</option>
          {satelliteList.map((satellite) => (
            <option key={satellite.id} value={satellite.id}>
              {satellite.name_ar} · {satellite.orbital_position === null ? '—' : `${satellite.orbital_position}°`}
            </option>
          ))}
        </select>
      </div>

      <ul className="flex flex-col divide-y divide-divider">
        {isFetching ? (
          <li className="text-caption py-3 text-text-tertiary">{copy.searching}</li>
        ) : channels.length === 0 ? (
          <li className="text-caption py-3 text-text-tertiary">{copy.noChannels}</li>
        ) : (
          channels.map((channel) => (
            <li key={channel.id} className="flex items-center gap-3 py-2">
              <span className="text-micro flex size-6 flex-none items-center justify-center rounded-xs bg-surface-2 font-mono text-text-tertiary">
                {channel.display_name?.slice(0, 3) ?? channel.name.slice(0, 3)}
              </span>
              <span className="flex min-w-0 flex-1 flex-col">
                <bdi className="text-label truncate text-text-primary">{channel.name}</bdi>
                <span className="text-micro flex items-center gap-2 text-text-tertiary">
                  {channel.frequency ? null : <span>{copy.platform}</span>}
                  {channel.frequency ? (
                    <span dir="ltr" className="font-mono">
                      {channel.frequency.mhz} {channel.frequency.pol}
                    </span>
                  ) : null}
                </span>
              </span>
              <Button size="xs" variant="outline" onClick={() => onAdd(channel)}>
                {copy.add}
              </Button>
            </li>
          ))
        )}
      </ul>
    </div>
  );
}
