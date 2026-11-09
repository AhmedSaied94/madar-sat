import { useState, type ReactElement } from 'react';
import { useSearchParams } from 'react-router-dom';

import { cancelNotification } from '../../api/generated/admin';
import type { NotificationRow } from '../../api/generated/admin.schemas';
import { ApiError, INVALID_RESPONSE } from '../../api/http';
import { Button } from '../../components/Button/Button';
import { ConfirmDialog } from '../../components/ConfirmDialog/ConfirmDialog';
import { ConflictDialog } from '../../components/ConfirmDialog/ConflictDialog';
import { EmptyState } from '../../components/EmptyState/EmptyState';
import { Select } from '../../components/FormControls/FormControls';
import { useToast } from '../../components/Toast/Toast';
import { focusRing } from '../../components/focus';
import { formatCairoTime } from '../../lib/cairoTime';
import { conflictParty } from '../../lib/conflict';
import { useRefreshAdmin } from '../../lib/useRefreshAdmin';
import { common, copyForErrorCode, notifications as copy, table } from '../../i18n/ar';
import { useSession } from '../auth/session';
import { Composer } from './Composer';
import { useOutbox } from './queries';

// A15 (contract admin-screens "A15: the log", board "Notifications"): the outbox with its type, target,
// counts, time and status — the status carrying the reason in Arabic, or the push service's own text
// raw — filtered by type and status through the URL, paged by cursor, read by editors while only
// admins get the composer. A pending announcement can be cancelled, under its `If-Match`.

const TYPE_OPTIONS = [
  { value: '', label: copy.filters.all },
  { value: 'goal', label: 'goal' },
  { value: 'kickoff_reminder', label: 'kickoff_reminder' },
  { value: 'final_score', label: 'final_score' },
  { value: 'channels_updated', label: 'channels_updated' },
  { value: 'frequency_changed', label: 'frequency_changed' },
  { value: 'announcement', label: 'announcement' },
] as const;

const STATUS_OPTIONS = [
  { value: '', label: copy.filters.all },
  { value: 'pending', label: copy.status.pending },
  { value: 'sent', label: copy.status.sent },
  { value: 'failed', label: copy.status.failed },
  { value: 'cancelled', label: copy.status.cancelled },
] as const;

const number = (value: number): string => new Intl.NumberFormat('en-US').format(value);

/** The row's `error` in Arabic, or the push service's text as it came (contract admin-api). */
function reasonText(reason: string): string {
  return copy.reason[reason] ?? reason;
}

function StatusCell({ row }: { row: NotificationRow }): ReactElement {
  const label = copy.status[row.status] ?? row.status;
  const tone =
    row.status === 'failed'
      ? 'bg-error-container text-error'
      : row.status === 'sent'
        ? 'bg-free-container text-free'
        : 'bg-surface-2 text-text-secondary';
  const raw = row.error !== null && copy.reason[row.error] === undefined;
  return (
    <span data-status={row.status} className={`text-micro inline-flex flex-wrap items-center gap-1 rounded-xs px-2 py-1 ${tone}`}>
      <span>{label}</span>
      {row.error === null ? null : (
        <>
          {' · '}
          {raw ? (
            <bdi dir="ltr" className="font-mono">
              {row.error}
            </bdi>
          ) : (
            <span>{reasonText(row.error)}</span>
          )}
        </>
      )}
    </span>
  );
}

export function NotificationsPage(): ReactElement {
  const { session } = useSession();
  const [params, setParams] = useSearchParams();
  const [cursor, setCursor] = useState<string | null>(null);
  const [trail, setTrail] = useState<readonly (string | null)[]>([]);
  const [cancelling, setCancelling] = useState<NotificationRow | null>(null);
  const [conflict, setConflict] = useState<NotificationRow | null>(null);
  const [busy, setBusy] = useState(false);
  const toast = useToast();
  const refresh = useRefreshAdmin();

  const type = params.get('type') ?? '';
  const status = params.get('status') ?? '';

  const outbox = useOutbox({
    type: type === '' ? null : type,
    status: status === '' ? null : status,
    cursor,
    limit: 50,
  });
  const rows = outbox.data?.data ?? [];
  const nextCursor = (outbox.data?.meta as { next_cursor?: string | null } | undefined)?.next_cursor ?? null;

  function setFilter(key: 'type' | 'status', value: string): void {
    const next = new URLSearchParams(params);
    if (value === '') next.delete(key);
    else next.set(key, value);
    setParams(next, { replace: true });
    setCursor(null);
    setTrail([]);
  }

  async function cancelRow(): Promise<void> {
    if (cancelling === null) return;
    const row = cancelling;
    setBusy(true);
    try {
      // The row's own version: the list's dataset ETag never matches it (A-R1-1).
      await cancelNotification(row.id, { headers: { 'If-Match': row.etag } });
      toast.show({ kind: 'success', title: copy.cancelDone });
      setCancelling(null);
      refresh();
    } catch (error) {
      const code = error instanceof ApiError ? error.code : INVALID_RESPONSE;
      setCancelling(null);
      if (code === 'edit_conflict') {
        setConflict(row);
      } else {
        toast.show({ kind: 'error', title: copyForErrorCode(code) });
      }
      refresh();
    } finally {
      setBusy(false);
    }
  }

  return (
    <div className="flex min-w-0 flex-1 flex-col gap-4">
      <div className="flex flex-wrap items-end gap-3">
        <div className="min-w-0">
          <h1 className="heading-1 text-text-primary">{copy.title}</h1>
          <p className="text-caption text-text-secondary">{copy.subtitle}</p>
        </div>
      </div>

      {session?.admin.role === 'admin' ? <Composer /> : null}

      <section className="flex min-w-0 flex-col gap-3 rounded-xl bg-surface-1 p-4 ring-1 ring-inset ring-divider">
        <div className="flex flex-wrap items-end gap-3">
          <h2 className="heading-2 ms-0 flex-1 text-text-primary">{copy.logTitle}</h2>
          <Select label={copy.filters.type} value={type} options={TYPE_OPTIONS} onChange={(value) => setFilter('type', value)} />
          <Select label={copy.filters.status} value={status} options={STATUS_OPTIONS} onChange={(value) => setFilter('status', value)} />
        </div>

        {outbox.isPending ? (
          <p className="text-label text-text-secondary">{table.loading}</p>
        ) : outbox.isError ? (
          <EmptyState
            kind="error"
            title={copyForErrorCode(outbox.error?.code ?? '')}
            body={copy.subtitle}
            action={{ label: common.retry, onClick: () => void outbox.refetch() }}
          />
        ) : rows.length === 0 ? (
          <EmptyState kind="empty" title={copy.empty.title} body={copy.empty.body} />
        ) : (
          <table className="w-full border-collapse text-start">
            <caption className="sr-only">{copy.logTitle}</caption>
            <thead>
              <tr className="text-micro border-b border-divider text-start text-text-tertiary">
                <th scope="col" className="p-2 text-start">{copy.columns.type}</th>
                <th scope="col" className="p-2 text-start">{copy.columns.target}</th>
                <th scope="col" className="p-2 text-end">{copy.columns.recipients}</th>
                <th scope="col" className="p-2 text-end">{copy.columns.sent}</th>
                <th scope="col" className="p-2 text-end">{copy.columns.failed}</th>
                <th scope="col" className="p-2 text-start">{copy.columns.time}</th>
                <th scope="col" className="p-2 text-start">{copy.columns.status}</th>
              </tr>
            </thead>
            <tbody>
              {rows.map((row) => {
                const canCancel = row.status === 'pending' && !row.is_test && row.type === 'announcement';
                return (
                  <tr key={row.id} data-testid={`outbox-${row.id}`} className="border-b border-divider last:border-0">
                    <td className="text-caption p-2">
                      {row.is_correction ? (
                        <span className="text-micro rounded-xs bg-accent-container px-2 py-1 text-accent-text">{copy.correction}</span>
                      ) : row.is_test ? (
                        <span className="text-micro rounded-xs bg-postponed-container px-2 py-1 text-postponed">{copy.test}</span>
                      ) : (
                        <bdi dir="ltr" className="text-micro rounded-xs bg-surface-2 px-2 py-1 font-mono text-text-secondary">
                          {row.type}
                        </bdi>
                      )}
                    </td>
                    <td className="text-caption p-2 text-text-primary">
                      {row.target?.label === null || row.target === null ? copy.allDevices : row.target.label}
                    </td>
                    <td className="text-caption p-2 text-end tabular-nums text-text-primary">{number(row.recipients)}</td>
                    <td className="text-caption p-2 text-end tabular-nums text-text-primary">{number(row.sent)}</td>
                    <td className="text-caption p-2 text-end tabular-nums text-text-primary">{number(row.failed)}</td>
                    <td className="text-caption p-2 text-text-secondary">
                      {formatCairoTime(row.sent_at ?? row.due_at)}
                    </td>
                    <td className="text-caption p-2">
                      <span className="flex flex-wrap items-center gap-2">
                        <StatusCell row={row} />
                        {canCancel ? (
                          <Button size="xs" variant="ghost" onClick={() => setCancelling(row)}>
                            {copy.cancel}
                          </Button>
                        ) : null}
                      </span>
                    </td>
                  </tr>
                );
              })}
            </tbody>
          </table>
        )}

        {nextCursor !== null ? (
          <button
            type="button"
            onClick={() => {
              setTrail((current) => [...current, cursor]);
              setCursor(nextCursor);
            }}
            className={`text-caption self-start font-semibold text-accent-text ${focusRing}`}
          >
            {copy.loadMore}
          </button>
        ) : null}
        {trail.length > 0 ? (
          <button
            type="button"
            onClick={() => {
              const previous = [...trail];
              const back = previous.pop() ?? null;
              setTrail(previous);
              setCursor(back);
            }}
            className={`text-caption self-start font-semibold text-text-secondary ${focusRing}`}
          >
            {copy.previous}
          </button>
        ) : null}
      </section>

      <ConfirmDialog
        open={cancelling !== null}
        title={copy.cancelTitle}
        body={copy.cancelBody}
        confirmLabel={copy.cancelConfirm}
        destructive
        loading={busy}
        onConfirm={() => void cancelRow()}
        onCancel={() => setCancelling(null)}
      />

      {conflict !== null ? (
        <ConflictDialog
          open
          subject={conflict.target?.label ?? copy.allDevices}
          changedBy={conflictParty({})}
          changes={[]}
          onReload={() => {
            setConflict(null);
            void outbox.refetch();
          }}
          onDiscard={() => setConflict(null)}
          onDismiss={() => setConflict(null)}
        />
      ) : null}
    </div>
  );
}
