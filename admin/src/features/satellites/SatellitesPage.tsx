import { clsx } from 'clsx';
import { useState, type ReactElement } from 'react';

import { getSatellite, orderSatellites } from '../../api/generated/admin';
import type { AdminSatellite } from '../../api/generated/admin.schemas';
import { ApiError, etagOf } from '../../api/http';
import { ConflictDialog, type ConflictChange } from '../../components/ConfirmDialog/ConflictDialog';
import { Icon } from '../../components/Icon/Icon';
import { SortableList } from '../../components/SortableList/SortableList';
import { useToast } from '../../components/Toast/Toast';
import { focusRing } from '../../components/focus';
import { copyForErrorCode, ordering, satellites as copy } from '../../i18n/ar';
import { conflictParty } from '../../lib/conflict';
import { SatelliteEditor, formatPosition } from './SatelliteEditor';
import { useSatellites } from './queries';

// A7 (admin board "Satellites"): the orbital order as one sortable list, with the satellite's readout
// and the editor beside it. The order saves as one request, each row under its version (T101).

interface ConflictState {
  changedBy: ReturnType<typeof conflictParty>;
  changes: ConflictChange[];
}

export function SatellitesPage(): ReactElement {
  const { rows, isPending, isError, refetch } = useSatellites();
  const [editing, setEditing] = useState<number | null>(null);
  const [creating, setCreating] = useState(false);
  const [saving, setSaving] = useState(false);
  const [conflict, setConflict] = useState<ConflictState | null>(null);
  const toast = useToast();

  async function saveOrder(keys: readonly string[]): Promise<void> {
    setSaving(true);
    try {
      // The rows carry no version yet (the same recorded gap as A6), so each moved row's version comes
      // from its detail; the server refuses a stale item and one stale item rejects the whole order.
      const items = await Promise.all(
        keys.map(async (key) => {
          const id = Number(key);
          const detail = await getSatellite(id);
          return { id, if_match: etagOf(detail) };
        }),
      );
      await orderSatellites({ items });
      toast.show({ kind: 'success', title: ordering.saved });
      void refetch();
    } catch (error) {
      const failure = error instanceof ApiError ? error : new ApiError('network_error', null);
      if (failure.code === 'edit_conflict') {
        const stale = (failure.meta as { stale_ids?: number[] }).stale_ids ?? [];
        setConflict({
          changedBy: conflictParty(failure.meta),
          changes: stale.map((id) => ({
            field: 'priority',
            label: ordering.conflictLabel,
            before: rows.find((row) => row.id === id)?.name_ar ?? null,
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
            itemName={(row) => row.name_ar}
            hint={copy.hint}
            disabled={saving}
            selectedKey={editing === null ? null : String(editing)}
            onReorder={(keys) => void saveOrder(keys)}
            render={(row: AdminSatellite) => (
              <>
                <span
                  dir="ltr"
                  className="text-micro flex h-6 min-w-12 flex-none items-center justify-center rounded-xs bg-text-primary px-2 font-mono font-semibold text-text-on-inverse"
                >
                  {formatPosition(row.orbital_position) ?? '—'}
                </span>
                <span className="flex min-w-0 flex-1 flex-col">
                  <bdi className="text-label truncate font-semibold text-text-primary">{row.name_ar}</bdi>
                  <bdi dir="ltr" className="text-micro truncate text-text-tertiary">
                    {row.name_en}
                  </bdi>
                </span>
                {row.best_frequency === null && row.worst_frequency === null ? (
                  <span className="text-micro rounded-xs bg-postponed-container px-2 py-1 font-semibold text-postponed">
                    {copy.noFrequencies}
                  </span>
                ) : null}
                <button
                  type="button"
                  aria-label={copy.editNamed(row.name_ar)}
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

      <SatelliteEditor satelliteId={editing} open={editing !== null} onClose={() => setEditing(null)} />
      <SatelliteEditor satelliteId={null} open={creating} onClose={() => setCreating(false)} />

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
