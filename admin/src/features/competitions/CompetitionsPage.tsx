import { clsx } from 'clsx';
import { useState, type ReactElement } from 'react';

import { orderCompetitions } from '../../api/generated/admin';
import type { AdminCompetition } from '../../api/generated/admin.schemas';
import { ApiError } from '../../api/http';
import { ConflictDialog, type ConflictChange } from '../../components/ConfirmDialog/ConflictDialog';
import { Icon } from '../../components/Icon/Icon';
import { SortableList } from '../../components/SortableList/SortableList';
import { useToast } from '../../components/Toast/Toast';
import { focusRing } from '../../components/focus';
import { competitions as copy, copyForErrorCode, ordering } from '../../i18n/ar';
import { conflictParty } from '../../lib/conflict';
import { CompetitionEditor } from './CompetitionEditor';
import { useCompetitions } from './queries';

// A6 (admin board "Competitions"): the priority order as one sortable list, and the editor beside it.
// Dragging or the keyboard path saves the whole new order in one request, each row under its version;
// a stale row rejects the whole change and opens the conflict dialog (T101).

interface ConflictState {
  changedBy: ReturnType<typeof conflictParty>;
  changes: ConflictChange[];
}

export function CompetitionsPage(): ReactElement {
  const { rows, isPending, isError, refetch } = useCompetitions();
  const [editing, setEditing] = useState<number | null>(null);
  const [creating, setCreating] = useState(false);
  const [saving, setSaving] = useState(false);
  const [conflict, setConflict] = useState<ConflictState | null>(null);
  const toast = useToast();

  async function saveOrder(keys: readonly string[]): Promise<void> {
    setSaving(true);
    try {
      // Each row goes under the `etag` it was rendered with, not one read now: a list older than the
      // server gets 409 and the conflict dialog instead of overwriting the other editor's order (A-R1-1).
      const etags = new Map(rows.map((row) => [row.id, row.etag]));
      const items = keys.flatMap((key) => {
        const id = Number(key);
        const etag = etags.get(id);
        return etag === undefined ? [] : [{ id, if_match: etag }];
      });
      await orderCompetitions({ items });
      toast.show({ kind: 'success', title: ordering.saved });
      // Wait for the new versions: the list stays locked until its rows carry them, so a quick second
      // drag never goes out under the versions this save has just replaced.
      await refetch();
    } catch (error) {
      const failure = error instanceof ApiError ? error : new ApiError('network_error', null);
      if (failure.code === 'edit_conflict') {
        const stale = (failure.meta as { stale_ids?: number[] }).stale_ids ?? [];
        setConflict({
          changedBy: conflictParty(failure.meta),
          changes: stale.map((id) => ({
            field: 'priority',
            label: ordering.conflictLabel,
            before: rows.find((row) => row.id === id)?.name ?? null,
            after: ordering.serverNewer,
          })),
        });
      } else {
        toast.show({ kind: 'error', title: ordering.saveFailed, description: copyForErrorCode(failure.code) });
      }
      void refetch();
    } finally {
      setSaving(false);
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
        <button
          type="button"
          onClick={() => setCreating(true)}
          className={clsx(
            'text-label inline-flex h-12 items-center gap-2 rounded-lg bg-accent px-3 font-semibold text-on-accent',
            focusRing,
          )}
        >
          <Icon name="plus" size="sm" />
          {copy.add}
        </button>
      </div>

      <div className="min-w-0 rounded-xl bg-surface-1 p-4 ring-1 ring-inset ring-divider">
        {isPending ? (
          <p className="text-label text-text-secondary">{copy.editor.emptyBody}</p>
        ) : isError ? (
          <p className="text-label font-semibold text-error">{copyForErrorCode('network_error')}</p>
        ) : rows.length === 0 ? (
          <p className="text-label text-text-secondary">{copy.editor.empty}</p>
        ) : (
          <SortableList
            label={ordering.conflictLabel}
            items={rows}
            itemKey={(row) => String(row.id)}
            itemName={(row) => row.name}
            hint={copy.hint}
            disabled={saving}
            selectedKey={editing === null ? null : String(editing)}
            onReorder={(keys) => void saveOrder(keys)}
            render={(row: AdminCompetition) => (
              <>
                <span className="flex size-6 flex-none items-center justify-center rounded-md bg-surface-2 text-text-tertiary">
                  {row.logo ? (
                    <img src={row.logo} alt="" className="size-5 object-contain" />
                  ) : (
                    <Icon name="trophy" size="md" />
                  )}
                </span>
                <bdi className="text-label min-w-0 flex-1 truncate text-text-primary">{row.name}</bdi>
                <span className="text-caption text-text-tertiary">
                  {row.sport === 'football' ? null : row.sport}
                </span>
                <button
                  type="button"
                  aria-label={`${copy.columns.edit} ${row.name}`}
                  onClick={() => setEditing(row.id)}
                  className={`inline-flex size-12 flex-none items-center justify-center rounded-md text-text-secondary hover:bg-surface-3 ${focusRing}`}
                >
                  <Icon name="edit" size="md" />
                </button>
              </>
            )}
          />
        )}
      </div>

      <CompetitionEditor competitionId={editing} open={editing !== null} onClose={() => setEditing(null)} />
      <CompetitionEditor competitionId={null} open={creating} onClose={() => setCreating(false)} />

      <ConflictDialog
        open={conflict !== null}
        subject={copy.title}
        changedBy={conflict?.changedBy ?? { kind: 'admin', name: '', at: '' }}
        changes={conflict?.changes ?? []}
        onReload={() => {
          setConflict(null);
          void refetch();
        }}
        onDiscard={() => setConflict(null)}
        onDismiss={() => setConflict(null)}
      />
    </div>
  );
}
