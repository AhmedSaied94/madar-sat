import { useState, type ReactElement } from 'react';

import { getEntityEtag } from '../../api/http';
import type { AdminCompetition, AdminMatchRow } from '../../api/generated/admin.schemas';
import { Button } from '../../components/Button/Button';
import { ConfirmDialog } from '../../components/ConfirmDialog/ConfirmDialog';
import { useToast } from '../../components/Toast/Toast';
import { copyForErrorCode, matches as copy, toast as toastCopy } from '../../i18n/ar';
import { useBulkMatches } from './queries';

// A3's bulk bar (Matches.html): everything applies to the selection in one all-or-nothing request.
// Removing channels is an admin action and needs the typed confirmation; an editor never sees it.

interface BulkBarProps {
  selected: readonly AdminMatchRow[];
  competitions: readonly AdminCompetition[];
  canRemoveChannels: boolean;
  onClear: () => void;
}

export function BulkBar({ selected, competitions, canRemoveChannels, onClear }: BulkBarProps): ReactElement {
  const bulk = useBulkMatches();
  const toast = useToast();
  const [mode, setMode] = useState<'idle' | 'competition' | 'remove'>('idle');
  const [competitionId, setCompetitionId] = useState<number | ''>('');

  const count = selected.length;

  /** Bulk items carry the version the editor saw: each match's own ETag, read just before the write. */
  async function items(): Promise<{ id: number; etag: string }[]> {
    return Promise.all(
      selected.map(async (row) => ({ id: row.id, etag: await getEntityEtag(`/admin/api/matches/${row.id}`) })),
    );
  }

  function fail(error: unknown): void {
    const code = typeof error === 'object' && error !== null && 'code' in error ? String(error.code) : '';
    toast.show({ kind: 'error', title: toastCopy.saveFailed, description: copyForErrorCode(code) });
  }

  async function changeCompetition(): Promise<void> {
    if (competitionId === '') return;
    try {
      await bulk.mutateAsync({
        data: { action: 'change_competition', items: await items(), competition_id: competitionId, competition_stage: null },
      });
      toast.show({ kind: 'success', title: toastCopy.saved });
      setMode('idle');
      onClear();
    } catch (error) {
      fail(error);
    }
  }

  async function removeChannels(): Promise<void> {
    try {
      await bulk.mutateAsync({ data: { action: 'remove_channels', items: await items(), channel_ids: null } });
      toast.show({ kind: 'success', title: toastCopy.saved });
      setMode('idle');
      onClear();
    } catch (error) {
      fail(error);
    }
  }

  return (
    <>
      <div
        role="toolbar"
        aria-label={copy.bulkToolbar}
        className="flex flex-wrap items-center gap-2 rounded-lg bg-surface-1 px-4 py-2 ring-1 ring-inset ring-divider"
      >
        <span className="text-label font-semibold text-text-primary">{copy.selected(count)}</span>
        <span className="flex-1" />
        <Button size="sm" variant="secondary" onClick={() => setMode('competition')}>
          {copy.bulk.changeCompetition}
        </Button>
        {canRemoveChannels ? (
          <Button size="sm" variant="danger" onClick={() => setMode('remove')}>
            {copy.bulk.removeChannels}
          </Button>
        ) : null}
        <Button size="sm" variant="ghost" onClick={onClear}>
          {copy.bulk.cancel}
        </Button>
      </div>

      <ConfirmDialog
        open={mode === 'competition'}
        title={copy.bulk.competitionTitle}
        body={copy.bulk.competitionBody}
        confirmLabel={copy.bulk.confirm}
        loading={bulk.isPending}
        onConfirm={() => void changeCompetition()}
        onCancel={() => setMode('idle')}
      >
        <label className="flex flex-col gap-2">
          <span className="text-caption font-semibold text-text-secondary">{copy.competitionFilter}</span>
          <select
            aria-label={copy.competitionFilter}
            value={competitionId}
            onChange={(event) => setCompetitionId(event.target.value === '' ? '' : Number(event.target.value))}
            className="text-body h-12 rounded-md bg-bg px-3 text-text-primary ring-1 ring-inset ring-divider-strong"
          >
            <option value="">—</option>
            {competitions.map((competition) => (
              <option key={competition.id} value={competition.id}>
                {competition.name}
              </option>
            ))}
          </select>
        </label>
      </ConfirmDialog>

      <ConfirmDialog
        open={mode === 'remove'}
        title={copy.bulk.removeTitle(count)}
        body={copy.bulk.removeBody}
        phrase={copy.bulk.removePhrase(count)}
        confirmLabel={copy.bulk.removeChannels}
        destructive
        loading={bulk.isPending}
        onConfirm={() => void removeChannels()}
        onCancel={() => setMode('idle')}
      />
    </>
  );
}
