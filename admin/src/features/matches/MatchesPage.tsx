import { clsx } from 'clsx';
import { useMemo, useState, type ReactElement } from 'react';
import { Link, useNavigate } from 'react-router-dom';

import type { AdminMatchRow, ListMatchesParams, Status } from '../../api/generated/admin.schemas';
import { DataTable, type DataTableColumn } from '../../components/DataTable/DataTable';
import { EmptyState } from '../../components/EmptyState/EmptyState';
import { Icon } from '../../components/Icon/Icon';
import { SourceChip, type SourceCode } from '../../components/StatusChip/StatusChip';
import { focusRing } from '../../components/focus';
import { useSession } from '../../features/auth/session';
import { cairoDay, cairoDayBounds, formatCairoClock, formatCairoDayLabel, shiftCairoDay } from '../../lib/cairoTime';
import { copyForErrorCode, matchStatus, matches as copy, toast as toastCopy } from '../../i18n/ar';
import { BulkActions } from './BulkBar';
import { useMatchLookups, useMatches } from './queries';

// A3 (admin board "Matches"): one Cairo day of matches on the shared DataTable — grouping by
// competition, the bulk bar, J/K/X/E keys and the skeleton come from the component (A-F2). Rows never
// offer a delete: removing channels is the destructive action, and it lives in the bulk bar for
// admins only.

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

/** The board's short codes for the sources that have one (A-R1-13). */
const SOURCE_CODES: Readonly<Record<string, SourceCode>> = {
  ysscores: 'YSS',
  livesoccertv: 'LST',
  sporteventz: 'SEZ',
  yallakora: 'YK',
  api_football: 'API',
  manual: 'manual',
};

/** A known source goes through the shared `SourceChip`; an unknown one keeps its own name. */
function SourceBadge({ name }: { name: string }): ReactElement {
  const code = SOURCE_CODES[name];
  if (code) return <SourceChip source={code} />;
  return (
    <span
      dir="ltr"
      className="text-micro rounded-xs bg-surface-2 px-2 py-1 font-mono tracking-wide text-text-secondary ring-1 ring-inset ring-divider"
    >
      {name}
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

const groupLabel = (row: AdminMatchRow): string =>
  row.competition.stage ? `${row.competition.name} · ${row.competition.stage}` : row.competition.name;

export function MatchesPage(): ReactElement {
  const { session } = useSession();
  const navigate = useNavigate();
  const today = cairoDay(new Date().toISOString());
  const [day, setDay] = useState(today);
  const [competitionId, setCompetitionId] = useState<number | null>(null);
  const [source, setSource] = useState<string | null>(null);
  const [status, setStatus] = useState<Status | null>(null);
  const [missingOnly, setMissingOnly] = useState(false);
  const [selectionResetKey, setSelectionResetKey] = useState(0);

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
  const missingCount = rows.filter((row) => row.missing_channels).length;
  const competitionCount = useMemo(() => new Set(rows.map((row) => row.competition.id)).size, [rows]);

  const tabs = [
    { id: 'yesterday', label: copy.yesterday, day: shiftCairoDay(today, -1) },
    { id: 'today', label: `${copy.today} · ${formatCairoDayLabel(today)}`, day: today },
    { id: 'tomorrow', label: copy.tomorrow, day: shiftCairoDay(today, 1) },
    { id: 'afterTomorrow', label: copy.afterTomorrow, day: shiftCairoDay(today, 2) },
  ];

  const columns: readonly DataTableColumn<AdminMatchRow>[] = [
    {
      id: 'time',
      header: copy.columns.time,
      cell: (row) =>
        row.time_tbd || !row.kickoff_at ? (
          <span className="text-caption text-text-tertiary">{copy.timeUnknown}</span>
        ) : (
          <span className="text-label font-semibold text-text-primary">
            <time dateTime={row.kickoff_at}>{formatCairoClock(row.kickoff_at).time}</time>{' '}
            <span className="text-micro text-text-tertiary">{formatCairoClock(row.kickoff_at).period}</span>
          </span>
        ),
    },
    {
      id: 'match',
      header: copy.columns.match,
      cell: (row) => (
        <span id={`match-teams-${row.id}`} className="flex items-center gap-2">
          <Crest logo={row.home.logo} name={row.home.name} />
          <bdi className="text-label text-text-primary">{row.home.name}</bdi>
          <span aria-hidden="true" className="text-text-tertiary">
            ×
          </span>
          <bdi className="text-label text-text-primary">{row.away.name}</bdi>
          <Crest logo={row.away.logo} name={row.away.name} />
        </span>
      ),
    },
    { id: 'status', header: copy.columns.status, cell: (row) => <StatusCell row={row} /> },
    {
      id: 'channels',
      header: copy.columns.channels,
      numeric: true,
      cell: (row) =>
        row.channel_count === 0 ? (
          <span className="text-micro inline-flex items-center gap-1 rounded-xs bg-postponed-container px-2 py-1 font-semibold text-postponed">
            <Icon name="alert" size="sm" />0
          </span>
        ) : (
          <span className="text-label tabular-nums text-text-primary">{row.channel_count}</span>
        ),
    },
    {
      id: 'commentator',
      header: copy.columns.commentator,
      cell: (row) =>
        row.commentator ? (
          <bdi className="text-label text-text-secondary">{row.commentator.name}</bdi>
        ) : (
          <span className="text-caption text-text-tertiary">—</span>
        ),
    },
    {
      id: 'sources',
      header: copy.columns.source,
      cell: (row) => (
        <span className="flex flex-wrap items-center gap-1">
          {row.sources.map((name) => (
            <SourceBadge key={name} name={name} />
          ))}
        </span>
      ),
    },
  ];

  return (
    <div className="flex min-w-0 flex-1 flex-col gap-4">
      <div className="flex flex-wrap items-end gap-3">
        <div className="min-w-0">
          <h1 className="heading-1 text-text-primary">{copy.title}</h1>
          <p className="text-caption text-text-secondary">{copy.summary(rows.length, competitionCount, missingCount)}</p>
        </div>
        <span className="flex-1" />
        <Link
          to="/matches/new"
          className={clsx(
            'text-label inline-flex h-12 items-center gap-2 rounded-lg bg-accent px-3 font-semibold text-on-accent',
            focusRing,
          )}
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
                setSelectionResetKey((key) => key + 1);
              }}
              className={clsx(
                'text-caption h-8 rounded-sm px-3 font-semibold',
                day === tab.day ? 'bg-segmented-on text-text-primary' : 'text-text-secondary hover:bg-surface-2',
                focusRing,
              )}
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
            className={clsx(
              'text-caption inline-flex h-8 items-center gap-2 rounded-md px-2 font-semibold ring-1 ring-inset',
              missingOnly ? 'bg-accent-container text-accent-text ring-accent' : 'bg-surface-1 text-text-secondary ring-divider',
              focusRing,
            )}
          >
            <Icon name="check" size="sm" />
            {copy.missingOnly}
          </button>
        </div>
      </div>

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
          <DataTable
            label={copy.title}
            columns={columns}
            rows={rows}
            rowKey={(row) => String(row.id)}
            rowTestId={(row) => `match-row-${row.id}`}
            rowLabel={(row) => `${row.home.name} × ${row.away.name}`}
            groupBy={groupLabel}
            selectable
            rowState={(row) => ({
              ...(row.missing_channels ? { warning: copy.groupMissing(row.channel_count) } : {}),
              ...(row.locked ? { locked: true } : {}),
            })}
            bulkActions={(keys) => (
              <BulkActions
                selected={rows.filter((row) => keys.includes(String(row.id)))}
                competitions={competitions}
                canRemoveChannels={session?.admin.role === 'admin'}
                onDone={() => setSelectionResetKey((key) => key + 1)}
              />
            )}
            rowActions={(row) => (
              <Link
                to={`/matches/${row.id}`}
                aria-labelledby={`edit-${row.id} match-teams-${row.id}`}
                className={`inline-flex size-8 items-center justify-center rounded-sm text-text-secondary hover:bg-surface-3 ${focusRing}`}
              >
                <span id={`edit-${row.id}`} hidden>
                  {copy.columns.edit}
                </span>
                <Icon name="edit" size="sm" />
              </Link>
            )}
            onEdit={(row) => navigate(`/matches/${row.id}`)}
            selectionResetKey={selectionResetKey}
          />
        )}
      </div>
    </div>
  );
}
