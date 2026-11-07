import { useState, type ReactElement } from 'react';
import { Link, useSearchParams } from 'react-router-dom';

import type { AuditRow } from '../../api/generated/admin.schemas';
import { EmptyState } from '../../components/EmptyState/EmptyState';
import { Select } from '../../components/FormControls/FormControls';
import { DiffView } from '../../components/ConfirmDialog/DiffView';
import { NotPermitted } from '../../components/NotPermitted/NotPermitted';
import { Icon } from '../../components/Icon/Icon';
import { focusRing } from '../../components/focus';
import { formatCairoTime } from '../../lib/cairoTime';
import { copyForErrorCode, audit as copy, common, table as tableCopy } from '../../i18n/ar';
import { useSession } from '../auth/session';
import { useAdmins } from '../users/queries';
import { diffChanges } from './diff';
import { useAuditEntry, useAuditLog } from './queries';

// A17 (contract admin-screens "A17: audit", board "Audit"): the log on one side, the selected entry's
// diff on the other — قبل / بعد in columns, any other shape shown raw and never thrown on — with links
// to the entity and to the push it produced. Read-only: no restore action exists (FR-045).

const number = (value: number): string => new Intl.NumberFormat('en-US').format(value);

const ENTITY_OPTIONS = [
  { value: '', label: copy.filters.all },
  { value: 'channel', label: copy.entities['channel'] ?? 'channel' },
  { value: 'match', label: copy.entities['match'] ?? 'match' },
  { value: 'team', label: copy.entities['team'] ?? 'team' },
  { value: 'competition', label: copy.entities['competition'] ?? 'competition' },
  { value: 'satellite', label: copy.entities['satellite'] ?? 'satellite' },
  { value: 'commentator', label: copy.entities['commentator'] ?? 'commentator' },
  { value: 'rights_holder', label: copy.entities['rights_holder'] ?? 'rights_holder' },
  { value: 'admin_user', label: copy.entities['admin_user'] ?? 'admin_user' },
] as const;

const PERIOD_OPTIONS = [
  { value: '', label: copy.filters.all },
  { value: 'today', label: copy.filters.today },
  { value: '7', label: copy.filters.last7 },
  { value: '30', label: copy.filters.last30 },
] as const;

/** `YYYY-MM-DD`, `days` before today, from the browser's clock in UTC. */
function dayBefore(days: number): string {
  const date = new Date();
  date.setUTCDate(date.getUTCDate() - days);
  return date.toISOString().slice(0, 10);
}

function actorName(entry: AuditRow): string {
  const name = entry.actor.name;
  if (name !== null && name !== '') return name;
  return entry.actor.kind === 'system' ? copy.actor.system : copy.actor.importer;
}

export function AuditPage(): ReactElement {
  const { session } = useSession();
  const [params, setParams] = useSearchParams();
  const [selected, setSelected] = useState<number | null>(null);
  const [cursor, setCursor] = useState<string | null>(null);
  const [trail, setTrail] = useState<readonly (string | null)[]>([]);

  const admins = useAdmins();
  const entity = params.get('entity') ?? '';
  const userId = params.get('admin_user_id') ?? '';
  const from = params.get('from') ?? '';
  const to = params.get('to') ?? '';
  const period = params.get('period') ?? '';
  const isAdmin = session?.admin.role === 'admin';

  const log = useAuditLog(
    {
      entity: entity === '' ? null : entity,
      admin_user_id: userId === '' ? null : Number(userId),
      from: from === '' ? null : from,
      to: to === '' ? null : to,
      cursor,
      limit: 50,
    },
    isAdmin,
  );
  const rows = log.data?.data ?? [];
  const nextCursor = (log.data?.meta as { next_cursor?: string | null } | undefined)?.next_cursor ?? null;
  const entryId = selected ?? rows[0]?.id ?? null;
  const detail = useAuditEntry(isAdmin ? entryId : null);

  function put(key: string, value: string): void {
    const next = new URLSearchParams(params);
    if (value === '') next.delete(key);
    else next.set(key, value);
    setParams(next, { replace: true });
    setCursor(null);
    setTrail([]);
    setSelected(null);
  }

  function setPeriod(value: string): void {
    const next = new URLSearchParams(params);
    next.delete('period');
    next.delete('from');
    next.delete('to');
    if (value !== '') {
      next.set('period', value);
      next.set('from', dayBefore(value === 'today' ? 0 : Number(value)));
      next.set('to', dayBefore(0));
    }
    setParams(next, { replace: true });
    setCursor(null);
    setTrail([]);
    setSelected(null);
  }

  if (!isAdmin) return <NotPermitted />;

  const entry = detail.data?.data ?? null;
  const notification = entry?.notification ?? null;

  return (
    <div className="flex min-w-0 flex-1 flex-col gap-4">
      <div className="min-w-0">
        <h1 className="heading-1 text-text-primary">{copy.title}</h1>
        <p className="text-caption text-text-secondary">{copy.subtitle}</p>
      </div>

      <div className="flex flex-wrap items-end gap-3">
        <Select
          label={copy.filters.user}
          value={userId}
          options={[
            { value: '', label: copy.filters.all },
            ...(admins.data?.data ?? []).map((admin) => ({ value: String(admin.id), label: admin.name })),
          ]}
          onChange={(value) => put('admin_user_id', value)}
        />
        <Select label={copy.filters.entity} value={entity} options={ENTITY_OPTIONS} onChange={(value) => put('entity', value)} />
        <Select label={copy.filters.period} value={period} options={PERIOD_OPTIONS} onChange={setPeriod} />
      </div>

      <div className="flex min-w-0 flex-wrap items-start gap-4 xl:flex-nowrap">
        <section aria-label={copy.title} className="flex min-w-0 flex-1 flex-col gap-2 rounded-xl bg-surface-1 p-2 ring-1 ring-inset ring-divider">
          {log.isPending ? (
            <p className="text-label p-2 text-text-secondary">{tableCopy.loading}</p>
          ) : log.isError ? (
            <EmptyState
              kind="error"
              title={copyForErrorCode(log.error?.code ?? '')}
              body={copy.subtitle}
              action={{ label: common.retry, onClick: () => void log.refetch() }}
            />
          ) : rows.length === 0 ? (
            <EmptyState kind="empty" title={copy.empty.title} body={copy.empty.body} />
          ) : (
            <ul className="flex flex-col divide-y divide-divider">
              {rows.map((row) => (
                <li key={row.id}>
                  <button
                    type="button"
                    aria-current={row.id === entryId ? 'true' : undefined}
                    onClick={() => setSelected(row.id)}
                    className={`flex w-full items-start gap-3 p-3 text-start ${
                      row.id === entryId ? 'bg-accent-container' : 'hover:bg-surface-2'
                    } ${focusRing}`}
                  >
                    <span className="flex min-w-0 flex-1 flex-col gap-1">
                      <span className="text-label text-text-primary">
                        <b className="font-semibold">{actorName(row)}</b> {copy.entities[row.entity] ?? row.entity}
                      </span>
                      <span className="text-micro flex flex-wrap items-center gap-2 text-text-tertiary">
                        <bdi dir="ltr" className="rounded-xs bg-surface-2 px-2 py-1 font-mono">
                          {row.entity}
                        </bdi>
                        {formatCairoTime(row.created_at)}
                      </span>
                    </span>
                  </button>
                </li>
              ))}
            </ul>
          )}

          {nextCursor !== null ? (
            <button
              type="button"
              onClick={() => {
                setTrail((current) => [...current, cursor]);
                setCursor(nextCursor);
              }}
              className={`text-caption self-start p-2 font-semibold text-accent-text ${focusRing}`}
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
              className={`text-caption self-start p-2 font-semibold text-text-secondary ${focusRing}`}
            >
              {copy.previous}
            </button>
          ) : null}
        </section>

        <section
          data-testid="audit-detail"
          aria-label={copy.detailTitle}
          className="flex min-w-0 flex-1 flex-col gap-3 rounded-xl bg-surface-1 p-4 ring-1 ring-inset ring-divider"
        >
          {entry === null ? (
            <p className="text-label text-text-secondary">{copy.emptyDetail}</p>
          ) : (
            <>
              <div className="flex flex-wrap items-baseline gap-2">
                <h2 className="heading-2 flex-1 text-text-primary">{copy.detailTitle}</h2>
                <span className="text-caption text-text-tertiary">
                  {actorName(entry)} · {formatCairoTime(entry.created_at)}
                </span>
                <bdi dir="ltr" className="text-micro font-mono text-text-tertiary">
                  {`${entry.entity}/${entry.entity_id ?? '—'}`}
                </bdi>
              </div>

              <DiffView changes={diffChanges(entry.diff ?? {})} layout="columns" />

              <div className="flex flex-wrap items-center gap-3 rounded-md bg-bg px-3 py-2">
                {notification === null ? (
                  <span className="text-caption text-text-tertiary">{copy.readOnly}</span>
                ) : (
                  <>
                    <Icon name="bell" size="sm" className="text-accent-text" />
                    <span className="text-caption min-w-0 flex-1 text-text-secondary">
                      {copy.notificationLine(number(notification.sent), number(notification.sent + notification.failed))}
                    </span>
                    <Link to="/notifications" className={`text-caption font-semibold text-accent-text ${focusRing}`}>
                      {copy.outbox}
                    </Link>
                  </>
                )}
              </div>

              <div className="flex flex-wrap items-center gap-2">
                {entry.entity === 'channel' && entry.entity_id !== null ? (
                  <Link to={`/channels/${entry.entity_id}`} className={`text-caption font-semibold text-accent-text ${focusRing}`}>
                    {copy.openChannel}
                  </Link>
                ) : null}
                {entry.entity === 'match' && entry.entity_id !== null ? (
                  <Link to={`/matches/${entry.entity_id}`} className={`text-caption font-semibold text-accent-text ${focusRing}`}>
                    {copy.openMatch}
                  </Link>
                ) : null}
              </div>
            </>
          )}
        </section>
      </div>
    </div>
  );
}
