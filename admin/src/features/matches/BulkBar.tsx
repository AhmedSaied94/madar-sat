import { useState, type ReactElement, type ReactNode } from 'react';

import type { AdminCompetition, AdminMatchRow } from '../../api/generated/admin.schemas';
import { ApiError } from '../../api/http';
import { Button } from '../../components/Button/Button';
import { ConfirmDialog } from '../../components/ConfirmDialog/ConfirmDialog';
import { useToast } from '../../components/Toast/Toast';
import { copyForErrorCode, matches as copy, toast as toastCopy } from '../../i18n/ar';
import { useBulkMatches } from './queries';

// A3's bulk actions, rendered inside the shared DataTable's bulk bar (A-F2). Everything applies to the
// selection in one all-or-nothing request; each item sends the version the list showed, so a stale
// selection is refused, never overwritten (A-R1-3). Removing channels is an admin action only.

interface BulkActionsProps {
  selected: readonly AdminMatchRow[];
  competitions: readonly AdminCompetition[];
  canRemoveChannels: boolean;
  /** Clears the table's selection once the change stuck. */
  onDone: () => void;
}

export function BulkActions({ selected, competitions, canRemoveChannels, onDone }: BulkActionsProps): ReactElement {
  const bulk = useBulkMatches();
  const toast = useToast();
  const [mode, setMode] = useState<'idle' | 'competition' | 'remove'>('idle');
  const [competitionId, setCompetitionId] = useState<number | ''>('');
  const [failure, setFailure] = useState<ReactNode>(null);

  const count = selected.length;
  const items = selected.map((row) => ({ id: row.id, etag: row.etag }));

  function fail(error: unknown): void {
    const code = error instanceof ApiError ? error.code : 'network_error';
    // A `409` names the rows whose version moved since the list was drawn, by their teams, not by id.
    const stale = error instanceof ApiError ? (error.meta as { stale_ids?: number[] }).stale_ids : undefined;
    const staleRows = Array.isArray(stale) ? selected.filter((row) => stale.includes(row.id)) : [];
    const named: ReactNode =
      staleRows.length > 0 ? (
        <>
          {copy.bulk.staleBefore}
          {staleRows.map((row, index) => (
            <span key={row.id}>
              {index > 0 ? '، ' : null}
              {/* Each name stays its own direction island (A-R1-18). */}
              <bdi>{row.home.name}</bdi> × <bdi>{row.away.name}</bdi>
            </span>
          ))}
          {copy.bulk.staleAfter}
        </>
      ) : null;
    setFailure(named ?? copyForErrorCode(code));
    toast.show({
      kind: 'error',
      title: toastCopy.saveFailed,
      description:
        staleRows.length > 0
          ? `${copy.bulk.staleBefore}${staleRows.map((row) => `${row.home.name} × ${row.away.name}`).join('، ')}${copy.bulk.staleAfter}`
          : copyForErrorCode(code),
    });
  }

  async function changeCompetition(): Promise<void> {
    if (competitionId === '') return;
    setFailure(null);
    try {
      await bulk.mutateAsync({
        data: { action: 'change_competition', items, competition_id: competitionId, competition_stage: null },
      });
      toast.show({ kind: 'success', title: toastCopy.saved });
      setMode('idle');
      onDone();
    } catch (error) {
      fail(error);
    }
  }

  async function removeChannels(): Promise<void> {
    setFailure(null);
    try {
      await bulk.mutateAsync({ data: { action: 'remove_channels', items, channel_ids: null } });
      toast.show({ kind: 'success', title: toastCopy.saved });
      setMode('idle');
      onDone();
    } catch (error) {
      fail(error);
    }
  }

  return (
    <>
      {failure ? (
        <span role="alert" className="text-caption font-semibold text-error">
          {failure}
        </span>
      ) : null}
      <Button size="sm" variant="secondary" onClick={() => setMode('competition')}>
        {copy.bulk.changeCompetition}
      </Button>
      {canRemoveChannels ? (
        <Button size="sm" variant="danger" onClick={() => setMode('remove')}>
          {copy.bulk.removeChannels}
        </Button>
      ) : null}
      <Button size="sm" variant="ghost" onClick={onDone}>
        {copy.bulk.cancel}
      </Button>

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
