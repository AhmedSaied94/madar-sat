import { useMemo, useState, type ReactElement } from 'react';
import { Link } from 'react-router-dom';

import type { AdminMatchRow, ListMatchesParams, Status } from '../../api/generated/admin.schemas';
import { EmptyState } from '../../components/EmptyState/EmptyState';
import { Icon } from '../../components/Icon/Icon';
import { SourceChip } from '../../components/StatusChip/StatusChip';
import { focusRing } from '../../components/focus';
import { useSession } from '../../features/auth/session';
import { cairoDay, cairoDayBounds, formatCairoClock, formatCairoDayLabel, shiftCairoDay } from '../../lib/cairoTime';
import { copyForErrorCode, matchStatus, matches as copy, toast as toastCopy } from '../../i18n/ar';
import { BulkBar } from './BulkBar';
import { useMatchLookups, useMatches } from './queries';

// A3 (admin board "Matches"): one Cairo day of matches, grouped by competition, filtered by the four
// controls the brief names, and editable in bulk. Rows never offer a delete: removing channels is the
// destructive action, and it lives in the bulk bar for admins only.

const API_STATUSES: readonly Status[] = [
  'scheduled',
  'live',
  'halftime',
  'extra_time',
  'penalties',
  'finished',
  'postponed',
  'cancelled',
  'abandoned',
];

const SOURCE_CODES: Readonly<Record<string, string>> = {
  ysscores: 'YSS',
  legacy: 'LST',
  kickoff: 'YK',
  satair_bridge: 'SEZ',
};

/** The board's short source codes; an unknown source keeps its own name as its badge. */
function SourceBadge({ name }: { name: string }): ReactElement {
  if (name === 'manual') return <SourceChip source="manual" />;
  return (
    <span
      dir="ltr"
      className="text-micro rounded-xs bg-surface-2 px-2 py-1 font-mono tracking-wide text-text-secondary ring-1 ring-inset ring-divider"
    >
      {SOURCE_CODES[name] ?? name.slice(0, 3).toUpperCase()}
    </span>
  );
}

function Crest({ logo, name }: { logo: string | null; name: string }): ReactElement {
  if (logo) {
    return <img src={logo} alt="" width={24} height={24} className="size-6 rounded-pill bg-surface-2 object-contain" />;
  }
  return (
    <span
      aria-hidden="true"
      className="text-micro flex size-6 flex-none items-center justify-center rounded-pill bg-surface-2 font-mono font-semibold text-text-secondary"
    >
      {name.slice(0, 1)}
    </span>
  );
}

function StatusCell({ row }: { row: AdminMatchRow }): ReactElement {
  if (row.status === 'live') {
    return (
      <span className="text-micro inline-flex items-center gap-1 rounded-xs bg-live-container px-2 py-1 font-semibold text-live">
        <span aria-hidden="true" className="size-1 rounded-pill bg-current" />
        {row.estimated ? `${matchStatus.live} · ${copy.statusHint}` : matchStatus.live}
      </span>
    );
  }
  return (
    <span data-status={row.status} className="text-micro rounded-xs bg-surface-2 px-2 py-1 text-text-secondary">
      {matchStatus[row.status]}
    </span>
  );
}

interface Group {
  key: string;
  name: string;
  stage: string | null;
  rows: AdminMatchRow[];
  missing: number;
}

function groupByCompetition(rows: readonly AdminMatchRow[]): Group[] {
  const groups = new Map<string, Group>();
  for (const row of rows) {
    const key = String(row.competition.id);
    const group = groups.get(key) ?? {
      key,
      name: row.competition.name,
      stage: row.competition.stage,
      rows: [],
      missing: 0,
    };
    group.rows.push(row);
    if (row.missing_channels) group.missing += 1;
    groups.set(key, group);
  }
  return [...groups.values()];
}

function Skeleton(): ReactElement {
  return (
    <div data-testid="matches-skeleton" className="flex flex-col gap-2 p-4">
      {[0, 1, 2, 3, 4].map((row) => (
        <div key={row} className="flex h-12 items-center gap-3">
          <span className="size-4 rounded-xs bg-surface-2" />
          <span className="h-3 w-12 rounded-xs bg-surface-2" />
          <span className="size-6 rounded-pill bg-surface-2" />
          <span className="h-3 w-12 rounded-xs bg-surface-2" />
        </div>
      ))}
    </div>
  );
}

export function MatchesPage(): ReactElement {
  const { session } = useSession();
  const today = cairoDay(new Date().toISOString());
  const [day, setDay] = useState(today);
  const [competitionId, setCompetitionId] = useState<number | null>(null);
  const [source, setSource] = useState<string | null>(null);
  const [status, setStatus] = useState<Status | null>(null);
  const [missingOnly, setMissingOnly] = useState(false);
  const [selected, setSelected] = useState<ReadonlySet<number>>(new Set());

  const bounds = cairoDayBounds(day);
  const params: ListMatchesParams = {
    from: bounds.from,
    to: bounds.to,
    competition_id: competitionId,
    source,
    status,
    missing_channels: missingOnly ? true : null,
  };
  const { data, isPending, isError, error, refetch } = useMatches(params);
  const { competitions, sources } = useMatchLookups();

  const rows = data?.data ?? [];
  const groups = useMemo(() => groupByCompetition(rows), [rows]);
  const missingCount = rows.filter((row) => row.missing_channels).length;
  const selectedRows = rows.filter((row) => selected.has(row.id));

  const tabs = [
    { id: 'yesterday', label: copy.yesterday, day: shiftCairoDay(today, -1) },
    { id: 'today', label: `${copy.today} · ${formatCairoDayLabel(today)}`, day: today },
    { id: 'tomorrow', label: copy.tomorrow, day: shiftCairoDay(today, 1) },
    { id: 'afterTomorrow', label: copy.afterTomorrow, day: shiftCairoDay(today, 2) },
  ];

  function toggle(id: number): void {
    setSelected((current) => {
      const next = new Set(current);
      if (next.has(id)) next.delete(id);
      else next.add(id);
      return next;
    });
  }

  return (
    <div className="flex min-w-0 flex-1 flex-col gap-4">
      <div className="flex flex-wrap items-end gap-3">
        <div className="min-w-0">
          <h1 className="heading-1 text-text-primary">{copy.title}</h1>
          <p className="text-caption text-text-secondary">
            {copy.summary(rows.length, groups.length, missingCount)}
          </p>
        </div>
        <span className="flex-1" />
        <Link
          to="/matches/new"
          className={`text-label inline-flex h-8 min-h-12 items-center gap-2 rounded-lg bg-accent px-3 font-semibold text-on-accent ${focusRing}`}
        >
          <Icon name="plus" size="sm" />
          {copy.add}
        </Link>
      </div>

      <div className="flex flex-wrap items-center gap-3">
        <nav aria-label={copy.dayLabel} className="flex items-center gap-1 rounded-lg bg-surface-1 p-1">
          {tabs.map((tab) => (
            <button
              key={tab.id}
              type="button"
              aria-pressed={day === tab.day}
              onClick={() => {
                setDay(tab.day);
                setSelected(new Set());
              }}
              className={`text-caption h-8 rounded-sm px-3 font-semibold ${
                day === tab.day ? 'bg-segmented-on text-text-primary' : 'text-text-secondary hover:bg-surface-2'
              } ${focusRing}`}
            >
              {tab.label}
            </button>
          ))}
          <input
            type="date"
            aria-label={copy.pickDate}
            value={day}
            onChange={(event) => event.target.value && setDay(event.target.value)}
            className="text-caption h-8 rounded-sm bg-transparent px-2 text-text-secondary"
          />
        </nav>

        <span className="flex-1" />

        <div className="flex flex-wrap items-center gap-2">
          <select
            aria-label={copy.competitionFilter}
            value={competitionId ?? ''}
            onChange={(event) => setCompetitionId(event.target.value === '' ? null : Number(event.target.value))}
            className="text-caption h-8 rounded-md bg-surface-1 px-2 text-text-primary ring-1 ring-inset ring-divider"
          >
            <option value="">{`${copy.competitionFilter}: ${copy.all}`}</option>
            {competitions.map((competition) => (
              <option key={competition.id} value={competition.id}>
                {competition.name}
              </option>
            ))}
          </select>

          <select
            aria-label={copy.sourceFilter}
            value={source ?? ''}
            onChange={(event) => setSource(event.target.value === '' ? null : event.target.value)}
            className="text-caption h-8 rounded-md bg-surface-1 px-2 text-text-primary ring-1 ring-inset ring-divider"
          >
            <option value="">{`${copy.sourceFilter}: ${copy.all}`}</option>
            {sources.map((item) => (
              <option key={item.name} value={item.name}>
                {item.name}
              </option>
            ))}
          </select>

          <select
            aria-label={copy.statusFilter}
            value={status ?? ''}
            onChange={(event) => setStatus((event.target.value || null) as Status | null)}
            className="text-caption h-8 rounded-md bg-surface-1 px-2 text-text-primary ring-1 ring-inset ring-divider"
          >
            <option value="">{`${copy.statusFilter}: ${copy.all}`}</option>
            {API_STATUSES.map((value) => (
              <option key={value} value={value}>
                {matchStatus[value]}
              </option>
            ))}
          </select>

          <button
            type="button"
            aria-pressed={missingOnly}
            onClick={() => setMissingOnly((current) => !current)}
            className={`text-caption inline-flex h-8 items-center gap-2 rounded-md px-2 font-semibold ring-1 ring-inset ${
              missingOnly ? 'bg-accent-container text-accent-text ring-accent' : 'bg-surface-1 text-text-secondary ring-divider'
            } ${focusRing}`}
          >
            <Icon name="check" size="sm" />
            {copy.missingOnly}
          </button>
        </div>
      </div>

      {selectedRows.length > 0 ? (
        <BulkBar
          selected={selectedRows}
          competitions={competitions}
          canRemoveChannels={session?.admin.role === 'admin'}
          onClear={() => setSelected(new Set())}
        />
      ) : null}

      <div className="min-w-0 overflow-x-auto rounded-xl bg-surface-1 ring-1 ring-inset ring-divider">
        {isPending ? (
          <Skeleton />
        ) : isError ? (
          <EmptyState
            kind="error"
            title={copyForErrorCode(error?.code ?? '')}
            body={copy.empty.body}
            action={{ label: toastCopy.retry, onClick: () => void refetch() }}
          />
        ) : rows.length === 0 ? (
          missingOnly ? (
            <EmptyState
              kind="allClear"
              title={copy.empty.allClearTitle}
              body={copy.empty.allClearBody}
              action={{ label: copy.empty.allClearAction, onClick: () => setMissingOnly(false) }}
            />
          ) : (
            <EmptyState kind="empty" title={copy.empty.title} body={copy.empty.body} />
          )
        ) : (
          <table className="w-full border-collapse text-start">
            <caption className="sr-only">{copy.title}</caption>
            <thead>
              <tr className="text-micro border-b border-divider text-start text-text-tertiary">
                <th scope="col" className="w-8 px-2 py-2">
                  <span className="sr-only">{copy.columns.match}</span>
                </th>
                <th scope="col" className="px-2 py-2 text-start">{copy.columns.time}</th>
                <th scope="col" className="px-2 py-2 text-start">{copy.columns.match}</th>
                <th scope="col" className="px-2 py-2 text-start">{copy.columns.status}</th>
                <th scope="col" className="px-2 py-2 text-start">{copy.columns.channels}</th>
                <th scope="col" className="px-2 py-2 text-start">{copy.columns.commentator}</th>
                <th scope="col" className="px-2 py-2 text-start">{copy.columns.source}</th>
                <th scope="col" className="px-2 py-2 text-start">
                  <span className="sr-only">{copy.columns.locked}</span>
                  <Icon name="lock" size="sm" />
                </th>
                <th scope="col" className="px-2 py-2" />
              </tr>
            </thead>
            {groups.map((group) => (
              <tbody key={group.key}>
                <tr className="bg-surface-2">
                  <th colSpan={9} scope="colgroup" className="text-caption px-3 py-2 text-start font-semibold text-text-primary">
                    <span className="flex items-center gap-2">
                      <span dir="auto">{group.stage ? `${group.name} · ${group.stage}` : group.name}</span>
                      <span className="text-micro rounded-xs bg-surface-3 px-2 text-text-secondary">
                        {copy.groupCount(group.rows.length)}
                      </span>
                      {group.missing > 0 ? (
                        <span className="text-micro text-postponed">{copy.groupMissing(group.missing)}</span>
                      ) : null}
                    </span>
                  </th>
                </tr>
                {group.rows.map((row) => (
                  <tr key={row.id} data-testid={`match-row-${row.id}`} className="border-b border-divider last:border-0 hover:bg-surface-2">
                    <td className="px-2 py-2">
                      <input
                        type="checkbox"
                        aria-label={copy.columns.match}
                        checked={selected.has(row.id)}
                        onChange={() => toggle(row.id)}
                        className="size-4 accent-accent"
                      />
                    </td>
                    <td className="px-2 py-2">
                      {row.time_tbd || !row.kickoff_at ? (
                        <span className="text-caption text-text-tertiary">—</span>
                      ) : (
                        <span className="text-label font-semibold text-text-primary">
                          <time dateTime={row.kickoff_at}>{formatCairoClock(row.kickoff_at).time}</time>{' '}
                          <span className="text-micro text-text-tertiary">{formatCairoClock(row.kickoff_at).period}</span>
                        </span>
                      )}
                    </td>
                    <td className="px-2 py-2">
                      <span className="flex items-center gap-2">
                        <Crest logo={row.home.logo} name={row.home.name} />
                        <bdi className="text-label text-text-primary">{row.home.name}</bdi>
                        <span aria-hidden="true" className="text-text-tertiary">×</span>
                        <bdi className="text-label text-text-primary">{row.away.name}</bdi>
                        <Crest logo={row.away.logo} name={row.away.name} />
                      </span>
                    </td>
                    <td className="px-2 py-2">
                      <StatusCell row={row} />
                    </td>
                    <td className="px-2 py-2">
                      {row.channel_count === 0 ? (
                        <span className="text-micro inline-flex items-center gap-1 rounded-xs bg-postponed-container px-2 py-1 font-semibold text-postponed">
                          <Icon name="alert" size="sm" />0
                        </span>
                      ) : (
                        <span className="text-label tabular text-text-primary">{row.channel_count}</span>
                      )}
                    </td>
                    <td className="px-2 py-2">
                      {row.commentator ? (
                        <bdi className="text-label text-text-secondary">{row.commentator.name}</bdi>
                      ) : (
                        <span className="text-caption text-text-tertiary">—</span>
                      )}
                    </td>
                    <td className="px-2 py-2">
                      <span className="flex flex-wrap items-center gap-1">
                        {row.sources.map((name) => (
                          <SourceBadge key={name} name={name} />
                        ))}
                      </span>
                    </td>
                    <td className="px-2 py-2">
                      {row.locked ? (
                        <span className="inline-flex text-postponed" title={copy.columns.locked}>
                          <Icon name="lock" size="sm" label={copy.columns.locked} />
                        </span>
                      ) : null}
                    </td>
                    <td className="px-2 py-2">
                      <Link
                        to={`/matches/${row.id}`}
                        aria-label={`${copy.columns.edit} ${row.home.name} × ${row.away.name}`}
                        className={`inline-flex size-8 items-center justify-center rounded-sm text-text-secondary hover:bg-surface-3 ${focusRing}`}
                      >
                        <Icon name="edit" size="sm" />
                      </Link>
                    </td>
                  </tr>
                ))}
              </tbody>
            ))}
          </table>
        )}
      </div>
    </div>
  );
}
