import { useState, type ReactElement } from 'react';
import { Link, useSearchParams } from 'react-router-dom';

import { useListSources } from '../../api/generated/admin';

import type { AuditRow, SourceHealth } from '../../api/generated/admin.schemas';
import { EmptyState } from '../../components/EmptyState/EmptyState';
import { Select } from '../../components/FormControls/FormControls';
import { DiffView } from '../../components/ConfirmDialog/DiffView';
import { NotPermitted } from '../../components/NotPermitted/NotPermitted';
import { Icon } from '../../components/Icon/Icon';
import { focusRing } from '../../components/focus';
import { cairoDay, cairoDayBounds, formatCairoTime } from '../../lib/cairoTime';
import { copyForErrorCode, audit as copy, common, table as tableCopy } from '../../i18n/ar';
import { useSession } from '../auth/session';
import { ChannelEditor } from '../channels/ChannelEditor';
import { useAdmins } from '../users/queries';
import { diffChanges } from './diff';
import { useAuditEntry, useAuditLog } from './queries';

// A17 (contract admin-screens "A17: audit", board "Audit"): the log on one side, the selected entry's
// diff on the other — قبل / بعد in columns, any other shape shown raw and never thrown on — with links
// to the entity and to the push it produced. Read-only: no restore action exists (FR-045).

const number = (value: number): string => new Intl.NumberFormat('en-US').format(value);

/**
 * The entity names the server writes: each B1 service's `ENTITY` constant
 * (`backend/app/services/admin/*.py`). The API filters by equality, so these are sent verbatim.
 */
const ENTITIES = [
  'channels',
  'matches',
  'teams',
  'competitions',
  'satellites',
  'commentators',
  'rights_holder',
  'admin_users',
] as const;

const ENTITY_OPTIONS = [
  { value: '', label: copy.filters.all },
  ...ENTITIES.map((entity) => ({ value: entity, label: copy.entities[entity] ?? entity })),
];

const PERIOD_OPTIONS = [
  { value: '', label: copy.filters.all },
  { value: 'today', label: copy.filters.today },
  { value: '7', label: copy.filters.last7 },
  { value: '30', label: copy.filters.last30 },
] as const;

/** `YYYY-MM-DD`, `days` calendar days before `day`. */
function daysBefore(day: string, days: number): string {
  return new Date(Date.parse(`${day}T00:00:00Z`) - days * 86_400_000).toISOString().slice(0, 10);
}

/**
 * A period as UTC instants of Cairo days (admin/CLAUDE.md "Times"): from the start of the first day
 * to the end of today, so «اليوم» and the longer periods include everything up to now. «آخر 7 أيام»
 * is today and the six days before it.
 */
export function periodBounds(period: string, now: Date = new Date()): { from: string; to: string } | null {
  const days = period === 'today' ? 1 : Number(period);
  if (!Number.isInteger(days) || days < 1) return null;
  const today = cairoDay(now.toISOString());
  return { from: cairoDayBounds(daysBefore(today, days - 1)).from, to: cairoDayBounds(today).to };
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
  const [channelId, setChannelId] = useState<number | null>(null);

  const admins = useAdmins();
  const entity = params.get('entity') ?? '';
  const userId = params.get('admin_user_id') ?? '';
  const source = params.get('source') ?? '';
  const period = params.get('period') ?? '';
  const isAdmin = session?.admin.role === 'admin';
  const sources = useListSources({ query: { enabled: isAdmin } });
  // A named period is resolved against today's Cairo day on every read; explicit bounds in the URL
  // (a shared link) are sent as they are.
  const bounds = periodBounds(period);
  const from = bounds?.from ?? params.get('from') ?? '';
  const to = bounds?.to ?? params.get('to') ?? '';

  const log = useAuditLog(
    {
      entity: entity === '' ? null : entity,
      admin_user_id: userId === '' ? null : Number(userId),
      source: source === '' ? null : source,
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

  /** Sets one filter; `clears` are the filters it replaces (a user and an importer are one actor). */
  function put(key: string, value: string, clears: readonly string[] = []): void {
    const next = new URLSearchParams(params);
    for (const other of clears) next.delete(other);
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
    if (value !== '') next.set('period', value);
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
          onChange={(value) => put('admin_user_id', value, ['source'])}
        />
        <Select
          label={copy.filters.importer}
          value={source}
          options={[
            { value: '', label: copy.filters.all },
            ...importerNames(sources.data?.data ?? [], source).map((name) => ({ value: name, label: name })),
          ]}
          onChange={(value) => put('source', value, ['admin_user_id'])}
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
                {entry.entity === 'channels' && entry.entity_id !== null ? (
                  <button
                    type="button"
                    onClick={() => setChannelId(entry.entity_id)}
                    className={`text-caption font-semibold text-accent-text ${focusRing}`}
                  >
                    {copy.openChannel}
                  </button>
                ) : null}
                {entry.entity === 'matches' && entry.entity_id !== null ? (
                  <Link to={`/matches/${entry.entity_id}`} className={`text-caption font-semibold text-accent-text ${focusRing}`}>
                    {copy.openMatch}
                  </Link>
                ) : null}
              </div>
            </>
          )}
        </section>
      </div>

      {/* «فتح القناة» opens the channel's own editor in place: channels have no route of their own. */}
      <ChannelEditor channelId={channelId} open={channelId !== null} onClose={() => setChannelId(null)} />
    </div>
  );
}

/** The importers to offer: every source the server lists, plus one already in the URL. */
function importerNames(rows: readonly SourceHealth[], current: string): string[] {
  const names = rows.map((row) => row.name);
  return current !== '' && !names.includes(current) ? [current, ...names] : names;
}
