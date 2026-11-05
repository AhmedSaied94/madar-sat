import { clsx } from 'clsx';
import { useState, type ReactElement } from 'react';

import { deleteRightsHolder, reorderRightsHolders } from '../../api/generated/admin';
import type { AdminRightsHolderRow } from '../../api/generated/admin.schemas';
import { ApiError, NETWORK_ERROR } from '../../api/http';
import { Button } from '../../components/Button/Button';
import { ConfirmDialog } from '../../components/ConfirmDialog/ConfirmDialog';
import { ConflictDialog, type ConflictChange } from '../../components/ConfirmDialog/ConflictDialog';
import { EmptyState } from '../../components/EmptyState/EmptyState';
import { Icon } from '../../components/Icon/Icon';
import { SortableList } from '../../components/SortableList/SortableList';
import { useToast } from '../../components/Toast/Toast';
import { focusRing } from '../../components/focus';
import { copyForErrorCode, ordering, rights as copy } from '../../i18n/ar';
import { conflictParty } from '../../lib/conflict';
import { useRefreshAdmin } from '../../lib/useRefreshAdmin';
import { useSession } from '../auth/session';
import { RightsHolderEditor } from './RightsHolderEditor';
import { useRightsHolders } from './queries';

// A9 (admin board "Rights"): every rights holder in the order the app shows them, with its
// competitions and satellites, and the editor beside the list. Dragging, or the handle's keyboard
// path, saves the whole order under the versions the list read (A-R1-1). Deleting is the admin's.

const COMPETITIONS_SHOWN = 3;

interface OrderConflict {
  changedBy: ReturnType<typeof conflictParty>;
  changes: ConflictChange[];
}

function competitionSummary(row: AdminRightsHolderRow): ReactElement {
  const shown = row.competitions.slice(0, COMPETITIONS_SHOWN);
  const rest = row.competitions.length - shown.length;
  if (shown.length === 0) return <span className="text-caption text-text-tertiary">—</span>;
  return (
    <span className="text-caption min-w-0 truncate text-text-tertiary">
      <bdi>{shown.join(' · ')}</bdi>
      {rest > 0 ? <span className="ms-1 tabular-nums">{copy.moreCompetitions(rest)}</span> : null}
    </span>
  );
}

export function RightsHoldersPage(): ReactElement {
  const { rows, isPending, isError, error, refetch } = useRightsHolders();
  const [query, setQuery] = useState('');
  const [editing, setEditing] = useState<number | null>(null);
  const [creating, setCreating] = useState(false);
  const [removing, setRemoving] = useState<AdminRightsHolderRow | null>(null);
  const [saving, setSaving] = useState(false);
  const [deleting, setDeleting] = useState(false);
  const [orderConflict, setOrderConflict] = useState<OrderConflict | null>(null);
  const toast = useToast();
  const refresh = useRefreshAdmin();
  const { session } = useSession();
  const isAdmin = session?.admin.role === 'admin';

  const needle = query.trim();
  const visible = needle === '' ? rows : rows.filter((row) => row.name.toLowerCase().includes(needle.toLowerCase()));

  async function saveOrder(keys: readonly string[]): Promise<void> {
    setSaving(true);
    try {
      const etags = new Map(rows.map((row) => [row.id, row.etag]));
      const items = keys.flatMap((key) => {
        const id = Number(key);
        const etag = etags.get(id);
        return etag === undefined ? [] : [{ id, if_match: etag }];
      });
      await reorderRightsHolders({ items });
      toast.show({ kind: 'success', title: ordering.saved });
      await refetch();
    } catch (failure) {
      const error = failure instanceof ApiError ? failure : new ApiError(NETWORK_ERROR, null);
      if (error.code === 'edit_conflict') {
        const stale = (error.meta as { stale_ids?: number[] }).stale_ids ?? [];
        setOrderConflict({
          changedBy: conflictParty(error.meta),
          changes: stale.map((id) => ({
            field: 'sort_order',
            label: ordering.conflictLabel,
            before: rows.find((row) => row.id === id)?.name ?? null,
            after: ordering.serverNewer,
          })),
        });
      } else {
        toast.show({ kind: 'error', title: ordering.saveFailed, description: copyForErrorCode(error.code) });
      }
      void refetch();
    } finally {
      setSaving(false);
    }
  }

  async function remove(row: AdminRightsHolderRow): Promise<void> {
    setDeleting(true);
    try {
      await deleteRightsHolder(row.id, { headers: { 'If-Match': row.etag } });
      toast.show({ kind: 'success', title: copy.deleted });
      setRemoving(null);
      refresh();
    } catch (failure) {
      const code = failure instanceof ApiError ? failure.code : NETWORK_ERROR;
      toast.show({ kind: 'error', title: copy.deleteFailed, description: copyForErrorCode(code) });
      setRemoving(null);
      refresh();
    } finally {
      setDeleting(false);
    }
  }

  return (
    <div className="flex min-w-0 flex-1 flex-col gap-4">
      <div className="flex flex-wrap items-end gap-3">
        <div className="min-w-0">
          <h1 className="heading-1 text-text-primary">{copy.title}</h1>
          <p className="text-caption text-text-secondary">{copy.subtitle(rows.length)}</p>
        </div>
        <span className="flex-1" />
        <Button onClick={() => setCreating(true)}>
          <Icon name="plus" size="sm" />
          {copy.add}
        </Button>
      </div>

      <div className="min-w-0 rounded-xl bg-surface-1 p-4 ring-1 ring-inset ring-divider">
        <div className="flex flex-wrap items-center gap-2">
          <h2 className="heading-2 text-text-primary">{copy.list}</h2>
          <span className="flex-1" />
          <input
            type="search"
            aria-label={copy.search}
            placeholder={copy.search}
            value={query}
            onChange={(event) => setQuery(event.target.value)}
            className={clsx('text-label h-12 rounded-md bg-surface-2 px-3 text-text-primary', focusRing)}
          />
        </div>

        <div className="mt-3">
          {isPending ? (
            <p className="text-label text-text-secondary">{copy.loading}</p>
          ) : isError ? (
            <EmptyState
              kind="error"
              title={copyForErrorCode(error?.code ?? NETWORK_ERROR)}
              body={copy.error}
              action={{ label: copy.title, onClick: () => void refetch() }}
            />
          ) : rows.length === 0 ? (
            <p className="text-label text-text-secondary">{copy.empty}</p>
          ) : visible.length === 0 ? (
            <p className="text-label text-text-secondary">{copy.noResults}</p>
          ) : (
            <SortableList
              label={ordering.conflictLabel}
              items={visible}
              itemKey={(row) => String(row.id)}
              itemName={(row) => row.name}
              disabled={saving || needle !== ''}
              selectedKey={editing === null ? null : String(editing)}
              onReorder={(keys) => void saveOrder(keys)}
              render={(row: AdminRightsHolderRow) => (
                <div data-testid={`rights-holder-${row.id}`} className="flex min-w-0 flex-1 items-center gap-3">
                  <span className="flex size-8 flex-none items-center justify-center rounded-md bg-surface-2 text-text-tertiary">
                    {row.logo ? (
                      <img src={row.logo} alt="" className="size-6 object-contain" />
                    ) : (
                      <Icon name="tv" size="md" />
                    )}
                  </span>
                  <bdi dir="ltr" className="text-label min-w-0 truncate font-semibold text-text-primary">
                    {row.name}
                  </bdi>
                  <span className="min-w-0 flex-1">{competitionSummary(row)}</span>
                  <bdi className="text-caption text-text-tertiary">{row.satellites.join(' · ')}</bdi>
                  <Button
                    variant="ghost"
                    size="xs"
                    iconOnly
                    aria-label={`${copy.edit} ${row.name}`}
                    onClick={() => setEditing(row.id)}
                  >
                    <Icon name="edit" size="md" />
                  </Button>
                  {isAdmin ? (
                    <Button
                      variant="ghost"
                      size="xs"
                      iconOnly
                      aria-label={`${copy.deleteConfirm} ${row.name}`}
                      onClick={() => setRemoving(row)}
                    >
                      <Icon name="trash" size="md" />
                    </Button>
                  ) : null}
                </div>
              )}
            />
          )}
        </div>
      </div>

      <RightsHolderEditor holderId={editing} open={editing !== null} onClose={() => setEditing(null)} />
      <RightsHolderEditor holderId={null} open={creating} onClose={() => setCreating(false)} />

      <ConflictDialog
        open={orderConflict !== null}
        subject={copy.title}
        changedBy={orderConflict?.changedBy ?? { kind: 'admin', name: '', at: '' }}
        changes={orderConflict?.changes ?? []}
        onReload={() => {
          setOrderConflict(null);
          void refetch();
        }}
        onDiscard={() => setOrderConflict(null)}
        onDismiss={() => setOrderConflict(null)}
      />

      <ConfirmDialog
        open={removing !== null}
        title={copy.deleteTitle}
        body={removing === null ? '' : copy.deleteBody(removing.name, removing.satellites.length)}
        confirmLabel={copy.deleteConfirm}
        destructive
        loading={deleting}
        onConfirm={() => {
          if (removing !== null) void remove(removing);
        }}
        onCancel={() => setRemoving(null)}
      />
    </div>
  );
}
