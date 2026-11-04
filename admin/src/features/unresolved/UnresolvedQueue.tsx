import { clsx } from 'clsx';
import { useState, type ReactElement } from 'react';

import { ignoreName, mapName } from '../../api/generated/admin';
import type { UnresolvedNameRow, UnresolvedSuggestion } from '../../api/generated/admin.schemas';
import { ApiError, NETWORK_ERROR } from '../../api/http';
import { Button } from '../../components/Button/Button';
import { DataTable, type DataTableColumn } from '../../components/DataTable/DataTable';
import { Modal, useDialogHeadingId } from '../../components/ConfirmDialog/Modal';
import { Icon } from '../../components/Icon/Icon';
import { useToast } from '../../components/Toast/Toast';
import { focusRing } from '../../components/focus';
import { common, copyForErrorCode, unresolved as copy } from '../../i18n/ar';
import { useRefreshAdmin } from '../../lib/useRefreshAdmin';
import { CreateFromName } from './CreateFromName';
import { useUnresolvedNames } from './queries';

// A13's queue (admin board "Sources", lower half): the names the importers couldn't match, each with
// its kind, its source, the match it came from and at most three suggestions. An editor clears one by
// mapping it to an entity, by creating that entity, or by ignoring it. Nothing is written before the
// save, and every write goes out under the version the row was read with (A-R1-1).

/** The row's suggestion chip, or the picker when several candidates are exact. */
function exactCandidates(row: UnresolvedNameRow): UnresolvedSuggestion[] {
  return row.suggestions.filter((suggestion) => suggestion.exact);
}

function suggestionCell(row: UnresolvedNameRow): ReactElement {
  const exact = exactCandidates(row);
  const [first] = row.suggestions;
  if (first === undefined) return <span className="text-caption text-text-tertiary">{copy.noSuggestions}</span>;
  if (exact.length > 1) {
    return (
      <span className="text-caption font-semibold text-postponed">{copy.candidates(exact.length)}</span>
    );
  }
  return (
    <span className="text-micro inline-flex items-center gap-1 rounded-xs bg-accent px-2 py-1 font-semibold text-on-accent">
      <bdi>{first.name}</bdi>
      <small className="text-micro font-semibold">{copy.confidence(first.confidence)}</small>
    </span>
  );
}

function contextCell(row: UnresolvedNameRow): ReactElement {
  const { home, away, competition } = row.context;
  const parts = [home, away].filter((part): part is string => typeof part === 'string' && part !== '');
  const line = parts.length === 2 ? `${parts[0]} × ${parts[1]}` : (competition ?? '');
  if (line === '') return <span className="text-caption text-text-tertiary">{copy.noContext}</span>;
  return (
    <span className="text-caption text-text-secondary">
      {line}
      {competition && parts.length === 2 ? ` · ${competition}` : null}
    </span>
  );
}

interface MapDialogProps {
  row: UnresolvedNameRow | null;
  onClose: () => void;
  /** Called after the write lands, so the list and its count follow. */
  onMapped: () => void;
}

/** Picks the target for one queued name. The choice is only sent on save. */
function MapDialog({ row, onClose, onMapped }: MapDialogProps): ReactElement | null {
  const toast = useToast();
  const headingId = useDialogHeadingId();
  const exact = row === null ? [] : exactCandidates(row);
  const shared = exact.length > 1;
  const [targetId, setTargetId] = useState<number | null>(() => row?.suggestions[0]?.id ?? null);
  const [scope, setScope] = useState(shared);
  const [saving, setSaving] = useState(false);
  const [failure, setFailure] = useState<string | null>(null);

  if (row === null) return null;

  async function save(): Promise<void> {
    if (row === null || targetId === null) return;
    setSaving(true);
    setFailure(null);
    try {
      await mapName(
        row.id,
        { target_id: targetId, scope_to_competition: scope, created: false },
        { headers: { 'If-Match': row.etag } },
      );
      toast.show({ kind: 'success', title: copy.mapped });
      onMapped();
      onClose();
    } catch (error) {
      const code = error instanceof ApiError ? error.code : NETWORK_ERROR;
      setFailure(copyForErrorCode(code));
    } finally {
      setSaving(false);
    }
  }

  return (
    <Modal open onClose={onClose} role="dialog" labelledBy={headingId}>
      <div className="flex flex-col gap-4 p-5">
        <h2 id={headingId} className="heading-2 text-text-primary">
          {copy.mapTitle(row.name)}
        </h2>
        <p className="text-caption text-text-secondary">{copy.mapHint}</p>

        {row.suggestions.length === 0 ? (
          <p className="text-label text-text-tertiary">{copy.noSuggestions}</p>
        ) : (
          <fieldset className="flex flex-col gap-2">
            <legend className="text-caption font-semibold text-text-secondary">{copy.target}</legend>
            {row.suggestions.map((suggestion) => (
              <label
                key={suggestion.id}
                className={clsx(
                  'flex items-center gap-3 rounded-md bg-surface-2 px-3 py-2',
                  focusRing,
                )}
              >
                <input
                  type="radio"
                  name="unresolved-target"
                  checked={targetId === suggestion.id}
                  onChange={() => setTargetId(suggestion.id)}
                  className="size-4 accent-accent"
                />
                <bdi className="text-label min-w-0 flex-1 text-text-primary">{suggestion.name}</bdi>
                {suggestion.detail === null ? null : (
                  <span className="text-caption text-text-tertiary">{suggestion.detail}</span>
                )}
                <span className="text-caption tabular-nums text-text-secondary">
                  {copy.confidence(suggestion.confidence)}
                </span>
              </label>
            ))}
          </fieldset>
        )}

        {row.kind === 'team' ? (
          <label className="flex items-start gap-2">
            <input
              type="checkbox"
              checked={scope}
              disabled={shared}
              aria-label={copy.scopeToCompetition}
              onChange={(event) => setScope(event.target.checked)}
              className="mt-1 size-4 accent-accent"
            />
            <span className="flex flex-col gap-1">
              <span className="text-caption font-semibold text-text-primary">{copy.scopeToCompetition}</span>
              <span className="text-caption text-text-tertiary">{copy.scopeHint}</span>
            </span>
          </label>
        ) : null}

        {failure === null ? null : (
          <p role="alert" className="text-label font-semibold text-error">
            {failure}
          </p>
        )}

        <div className="flex items-center justify-end gap-2">
          <Button variant="outline" onClick={onClose}>
            {common.cancel}
          </Button>
          <Button onClick={() => void save()} loading={saving} disabled={targetId === null}>
            {common.save}
          </Button>
        </div>
      </div>
    </Modal>
  );
}

export function UnresolvedQueue(): ReactElement {
  const [source, setSource] = useState<string>('');
  const [cursor, setCursor] = useState<string | null>(null);
  const [mapping, setMapping] = useState<UnresolvedNameRow | null>(null);
  const [creating, setCreating] = useState<UnresolvedNameRow | null>(null);
  const [busy, setBusy] = useState<number | null>(null);
  const toast = useToast();
  const refresh = useRefreshAdmin();

  const { data, isPending, isError, error, refetch } = useUnresolvedNames({
    state: 'open',
    source: source === '' ? null : source,
    cursor,
    limit: 50,
  });
  const rows = data?.data ?? [];
  const openCount = (data?.meta as { open_count?: number } | undefined)?.open_count ?? rows.length;

  const sources = [...new Set(rows.map((row) => row.source))].sort();

  async function ignore(row: UnresolvedNameRow): Promise<void> {
    setBusy(row.id);
    try {
      await ignoreName(row.id, { headers: { 'If-Match': row.etag } });
      toast.show({ kind: 'success', title: copy.ignored });
      refresh();
    } catch (failure) {
      const code = failure instanceof ApiError ? failure.code : NETWORK_ERROR;
      toast.show({ kind: 'error', title: copy.ignoreFailed, description: copyForErrorCode(code) });
      refresh();
    } finally {
      setBusy(null);
    }
  }

  const columns: readonly DataTableColumn<UnresolvedNameRow>[] = [
    {
      id: 'name',
      header: copy.columns.name,
      cell: (row) => (
        <bdi dir="ltr" className="text-label font-mono font-semibold text-text-primary">
          {row.name}
        </bdi>
      ),
    },
    { id: 'kind', header: copy.columns.kind, cell: (row) => copy.kinds[row.kind] ?? row.kind },
    {
      id: 'source',
      header: copy.columns.source,
      cell: (row) => (
        <bdi dir="ltr" className="text-micro font-mono text-text-secondary">
          {row.source}
        </bdi>
      ),
    },
    { id: 'context', header: copy.columns.context, cell: contextCell },
    { id: 'suggestion', header: copy.columns.suggestion, cell: suggestionCell },
  ];

  function actions(row: UnresolvedNameRow): ReactElement {
    const exact = exactCandidates(row);
    return (
      <span className="flex items-center gap-1">
        {row.suggestions.length > 0 ? (
          <Button size="xs" variant="primary" onClick={() => setMapping(row)}>
            <Icon name="link" size="sm" />
            {exact.length > 1 ? copy.pick : copy.link}
          </Button>
        ) : null}
        <Button size="xs" variant="secondary" onClick={() => setCreating(row)}>
          {copy.create}
        </Button>
        <Button
          size="xs"
          variant="ghost"
          loading={busy === row.id}
          onClick={() => void ignore(row)}
        >
          {copy.ignore}
        </Button>
      </span>
    );
  }

  return (
    <section className="flex min-w-0 flex-col gap-3 rounded-xl bg-surface-1 p-4 ring-1 ring-inset ring-divider">
      <div className="flex flex-wrap items-center gap-2">
        <h2 className="heading-2 text-text-primary">{copy.title}</h2>
        <span
          data-testid="unresolved-count"
          className="text-micro rounded-pill bg-accent-container px-2 py-1 font-semibold tabular-nums text-accent-text"
        >
          {copy.count(openCount)}
        </span>
        <span className="text-caption text-text-tertiary">{copy.hint}</span>
        <span className="flex-1" />
        <label className="flex items-center gap-2">
          <span className="text-caption text-text-secondary">{copy.sourceFilter}</span>
          <select
            value={source}
            onChange={(event) => {
              setSource(event.target.value);
              setCursor(null);
            }}
            className={clsx(
              'text-caption h-8 rounded-md bg-surface-2 px-2 text-text-primary',
              focusRing,
            )}
          >
            <option value="">{copy.allSources}</option>
            {sources.map((name) => (
              <option key={name} value={name}>
                {name}
              </option>
            ))}
          </select>
        </label>
      </div>

      {isPending ? (
        <p className="text-label text-text-secondary">{copy.loading}</p>
      ) : isError ? (
        <p role="alert" className="text-label font-semibold text-error">
          {copyForErrorCode(error?.code ?? NETWORK_ERROR)}
        </p>
      ) : (
        <DataTable
          label={copy.title}
          columns={columns}
          rows={rows}
          rowKey={(row) => String(row.id)}
          rowTestId={(row) => `unresolved-${row.id}`}
          rowActions={actions}
          emptyMessage={copy.empty}
        />
      )}

      <MapDialog
        key={mapping === null ? 'none' : mapping.id}
        row={mapping}
        onClose={() => setMapping(null)}
        onMapped={() => void refetch()}
      />
      <CreateFromName
        row={creating}
        onClose={() => setCreating(null)}
        onMapped={() => void refetch()}
      />
    </section>
  );
}
