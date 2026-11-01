import { clsx } from 'clsx';
import { useState, type ReactElement } from 'react';

import type { Access, Category, ChannelItem, ListChannelsParams } from '../../api/generated/admin.schemas';
import { DataTable, type DataTableColumn } from '../../components/DataTable/DataTable';
import { Icon } from '../../components/Icon/Icon';
import { focusRing } from '../../components/focus';
import { channels as copy, copyForErrorCode } from '../../i18n/ar';
import { ChannelEditor, draftOnAnotherSatellite, type ChannelDraft } from './ChannelEditor';
import { useChannels, useSatelliteOptions } from './queries';

// A8 (admin board "Channels", light): the channel list with its filters, the record drawer, and the
// placeholder an importer leaves behind until an editor completes it.

const ALL = '';

type EditorState = { mode: 'create'; seed: ChannelDraft | null } | { mode: 'edit'; id: number };

export function ChannelsPage(): ReactElement {
  const [query, setQuery] = useState('');
  const [satelliteId, setSatelliteId] = useState(ALL);
  const [category, setCategory] = useState(ALL);
  const [access, setAccess] = useState(ALL);
  const [missingLogo, setMissingLogo] = useState(false);
  const [platformOnly, setPlatformOnly] = useState(false);
  const [shownInMatch, setShownInMatch] = useState(false);
  const [placeholders, setPlaceholders] = useState(false);
  const [editor, setEditor] = useState<EditorState | null>(null);

  const params: ListChannelsParams = {
    q: query.trim() === '' ? null : query.trim(),
    satellite_id: satelliteId === ALL ? null : Number(satelliteId),
    category: category === ALL ? null : (category as Category),
    access: access === ALL ? null : (access as Access),
    missing_logo: missingLogo ? true : null,
    kind: platformOnly ? 'platform' : null,
    show_in_match: shownInMatch ? true : null,
    placeholder: placeholders ? true : null,
    limit: 100,
  };
  const { data, isPending, isError, error } = useChannels(params);
  const satellites = useSatelliteOptions();
  const rows = data?.data ?? [];

  const onPlatforms = rows.filter((row) => row.kind === 'platform').length;

  const columns: readonly DataTableColumn<ChannelItem>[] = [
    {
      id: 'channel',
      header: copy.columns.channel,
      cell: (row) => (
        <span className="flex min-w-0 items-center gap-2">
          <span className="flex size-8 flex-none items-center justify-center rounded-md bg-surface-2 text-text-tertiary">
            {row.logo ? <img src={row.logo} alt="" className="size-6 object-contain" /> : <Icon name="tv" size="sm" />}
          </span>
          <span className="flex min-w-0 flex-col">
            <bdi dir="ltr" className="text-label truncate text-start font-semibold text-text-primary">
              {row.name}
            </bdi>
            {row.display_name ? (
              <bdi dir="ltr" className="text-micro truncate text-start text-text-tertiary">
                {row.display_name}
              </bdi>
            ) : null}
          </span>
          {row.placeholder_source ? (
            <span className="text-micro flex-none rounded-xs bg-postponed-container px-2 py-1 font-semibold text-postponed">
              {copy.needsCompletion}
            </span>
          ) : null}
        </span>
      ),
      sortValue: (row) => row.name,
    },
    {
      id: 'frequency',
      header: copy.columns.frequency,
      cell: (row) =>
        row.frequency ? (
          <span
            dir="ltr"
            className="text-micro inline-flex items-center gap-1 rounded-xs bg-text-primary px-2 py-1 font-mono tabular-nums text-text-on-inverse"
          >
            <span>{row.frequency.mhz}</span>
            <span aria-hidden="true" className="rounded-xs bg-surface-3 px-1 text-text-secondary">
              {row.frequency.pol}
            </span>
            <span>{row.frequency.sr}</span>
          </span>
        ) : (
          <span className="text-caption text-text-tertiary">{copy.noFrequency}</span>
        ),
    },
    {
      id: 'access',
      header: copy.columns.access,
      cell: (row) =>
        row.access === 'encrypted' ? (
          <span className="text-micro inline-flex items-center gap-1 rounded-xs bg-surface-2 px-2 py-1 text-text-secondary">
            <Icon name="lock" size="sm" />
            <bdi dir="ltr">{row.provider ?? copy.encrypted}</bdi>
          </span>
        ) : (
          <span className="text-micro inline-flex items-center gap-1 rounded-xs bg-free-container px-2 py-1 text-free">
            <Icon name="unlock" size="sm" />
            {copy.free}
          </span>
        ),
    },
    {
      id: 'category',
      header: copy.columns.category,
      cell: (row) => (
        <span className="text-caption text-text-secondary">
          {row.category === 'entertainment' ? copy.entertainment : row.category === 'sports' ? copy.sports : '—'}
        </span>
      ),
    },
    {
      id: 'inMatch',
      header: copy.columns.inMatch,
      cell: (row) =>
        row.show_in_match ? (
          <span className="inline-flex size-5 items-center justify-center rounded-pill bg-free-container text-free">
            <Icon name="check" size="sm" label={copy.columns.inMatch} />
          </span>
        ) : (
          <span className="text-caption text-text-tertiary">—</span>
        ),
    },
  ];

  function toggle(setter: (value: boolean) => void, current: boolean): void {
    setter(!current);
  }

  return (
    <div className="flex min-w-0 flex-1 flex-col gap-4">
      <div className="flex flex-wrap items-end gap-3">
        <div className="min-w-0">
          <h1 className="heading-1 text-text-primary">{copy.title}</h1>
          <p className="text-caption text-text-secondary">
            {copy.subtitle(rows.length, rows.length - onPlatforms, onPlatforms)}
          </p>
        </div>
        <span className="flex-1" />
        <button
          type="button"
          onClick={() => setEditor({ mode: 'create', seed: null })}
          className={clsx(
            'text-label inline-flex h-12 items-center gap-2 rounded-lg bg-accent px-3 font-semibold text-on-accent',
            focusRing,
          )}
        >
          <Icon name="plus" size="sm" />
          {copy.add}
        </button>
      </div>

      <div className="flex flex-wrap items-center gap-2">
        <label className="flex h-8 min-w-0 items-center gap-2 rounded-lg bg-surface-1 px-3 ring-1 ring-inset ring-divider">
          <Icon name="search" size="md" className="text-text-tertiary" />
          <input
            type="search"
            aria-label={copy.search}
            placeholder={copy.search}
            value={query}
            onChange={(event) => setQuery(event.target.value)}
            className="text-caption min-w-0 flex-1 bg-transparent text-text-primary outline-none placeholder:text-text-tertiary"
          />
        </label>

        <select
          aria-label={copy.satelliteFilter}
          value={satelliteId}
          onChange={(event) => setSatelliteId(event.target.value)}
          className="text-caption h-8 rounded-md bg-surface-1 px-2 text-text-primary ring-1 ring-inset ring-divider"
        >
          <option value={ALL}>{`${copy.satelliteFilter}: ${copy.all}`}</option>
          {satellites.map((satellite) => (
            <option key={satellite.id} value={satellite.id}>
              {satellite.name_ar}
            </option>
          ))}
        </select>

        <select
          aria-label={copy.categoryFilter}
          value={category}
          onChange={(event) => setCategory(event.target.value)}
          className="text-caption h-8 rounded-md bg-surface-1 px-2 text-text-primary ring-1 ring-inset ring-divider"
        >
          <option value={ALL}>{`${copy.categoryFilter}: ${copy.all}`}</option>
          <option value="sports">{copy.sports}</option>
          <option value="entertainment">{copy.entertainment}</option>
        </select>

        <select
          aria-label={copy.accessFilter}
          value={access}
          onChange={(event) => setAccess(event.target.value)}
          className="text-caption h-8 rounded-md bg-surface-1 px-2 text-text-primary ring-1 ring-inset ring-divider"
        >
          <option value={ALL}>{`${copy.accessFilter}: ${copy.all}`}</option>
          <option value="free">{copy.free}</option>
          <option value="encrypted">{copy.encrypted}</option>
        </select>

        {(
          [
            { label: copy.missingLogoOnly, icon: 'image', value: missingLogo, set: () => toggle(setMissingLogo, missingLogo) },
            { label: copy.platformOnly, icon: 'globe', value: platformOnly, set: () => toggle(setPlatformOnly, platformOnly) },
            { label: copy.shownInMatch, icon: 'eye', value: shownInMatch, set: () => toggle(setShownInMatch, shownInMatch) },
            { label: copy.placeholderOnly, icon: 'alert', value: placeholders, set: () => toggle(setPlaceholders, placeholders) },
          ] as const
        ).map((filter) => (
          <button
            key={filter.label}
            type="button"
            aria-pressed={filter.value}
            onClick={filter.set}
            className={clsx(
              'text-caption inline-flex h-8 items-center gap-2 rounded-md px-3 font-semibold ring-1 ring-inset',
              filter.value ? 'bg-accent-container text-accent-text ring-accent' : 'bg-surface-1 text-text-secondary ring-divider',
              focusRing,
            )}
          >
            <Icon name={filter.icon} size="sm" />
            {filter.label}
          </button>
        ))}
      </div>

      <div className="min-w-0 overflow-x-auto rounded-xl bg-surface-1 ring-1 ring-inset ring-divider">
        <DataTable
          label={copy.title}
          columns={columns}
          rows={rows}
          rowKey={(row) => String(row.id)}
          rowState={(row) => (row.placeholder_source ? { warning: copy.needsCompletion } : {})}
          rowActions={(row) => (
            <>
              <button
                type="button"
                aria-label={copy.editNamed(row.name)}
                onClick={() => setEditor({ mode: 'edit', id: row.id })}
                className={`inline-flex size-8 items-center justify-center rounded-sm text-text-secondary hover:bg-surface-3 ${focusRing}`}
              >
                <Icon name="edit" size="sm" />
              </button>
              <button
                type="button"
                aria-label={copy.addOnAnotherNamed(row.name)}
                onClick={() => setEditor({ mode: 'create', seed: draftOnAnotherSatellite(row) })}
                className={`inline-flex size-8 items-center justify-center rounded-sm text-text-secondary hover:bg-surface-3 ${focusRing}`}
              >
                <Icon name="upload" size="sm" />
              </button>
            </>
          )}
          onEdit={(row) => setEditor({ mode: 'edit', id: row.id })}
          loading={isPending}
          emptyMessage={isError ? copyForErrorCode(error?.code ?? '') : copy.editor.empty}
        />
      </div>

      <ChannelEditor
        channelId={editor?.mode === 'edit' ? editor.id : null}
        open={editor?.mode === 'edit'}
        onClose={() => setEditor(null)}
      />
      <ChannelEditor
        channelId={null}
        seed={editor?.mode === 'create' ? editor.seed : null}
        open={editor?.mode === 'create'}
        onClose={() => setEditor(null)}
      />
    </div>
  );
}
