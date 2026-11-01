import { clsx } from 'clsx';
import type { ReactElement } from 'react';
import { Link } from 'react-router-dom';

import type { RecentChange, SourceHealth } from '../../api/generated/admin.schemas';
import { EmptyState } from '../../components/EmptyState/EmptyState';
import { KpiCard } from '../../components/KpiCard/KpiCard';
import { HealthChip } from '../../components/StatusChip/StatusChip';
import { focusRing } from '../../components/focus';
import { copyForErrorCode, dashboard as copy, sources as sourceCopy } from '../../i18n/ar';
import { formatCairoTime } from '../../lib/cairoTime';
import { healthTone } from '../sources/SourcesPage';
import { useDashboard } from './queries';

// A2 (admin board "Main"): the day's work first — matches without a channel, placeholders to complete,
// the sources' health — then the source tiles and the last changes. Every card opens the list it counts.

function recentLine(change: RecentChange): string {
  const who = change.by.kind === 'source' ? copy.bySource(change.by.name) : change.by.name;
  const action = copy.actions[change.action] ?? change.action;
  const entity = copy.entities[change.entity] ?? change.entity;
  return copy.recentLine(who, action, entity);
}

function SourceTile({ source }: { source: SourceHealth }): ReactElement {
  const tone = healthTone(source);
  return (
    <li data-testid={`dashboard-source-${source.name}`} className="flex items-center gap-3 rounded-lg bg-bg px-3 py-2">
      <bdi dir="ltr" className="text-caption min-w-0 flex-1 truncate font-mono font-semibold text-text-primary">
        {source.name}
      </bdi>
      <span className="text-caption text-text-tertiary">
        {source.last_success_at ? formatCairoTime(source.last_success_at) : sourceCopy.neverSucceeded}
      </span>
      <HealthChip health={tone}>
        {tone === 'open' ? sourceCopy.breakerOpen : tone === 'near_limit' ? sourceCopy.runStatus.partial : sourceCopy.healthy}
      </HealthChip>
    </li>
  );
}

export function DashboardPage(): ReactElement {
  const { data, isPending, isError, error } = useDashboard();
  const board = data?.data;

  if (isPending) {
    return <p className="text-label text-text-secondary">{copy.loading}</p>;
  }

  if (isError || !board) {
    return <EmptyState kind="error" title={copyForErrorCode(error?.code ?? '')} body={copy.loading} />;
  }

  const healthy = board.sources.filter((source) => healthTone(source) === 'ok').length;
  const matches = board.missing_channels.reduce((total, group) => total + group.matches.length, 0);

  return (
    <div className="flex min-w-0 flex-1 flex-col gap-4">
      <div className="flex flex-wrap items-end gap-3">
        <div className="min-w-0">
          <h1 className="heading-1 text-text-primary">{copy.title}</h1>
          <p className="text-caption text-text-secondary">{copy.subtitle}</p>
        </div>
      </div>

      <div className="grid gap-3 md:grid-cols-3">
        <KpiCard
          icon="tv"
          label={copy.missing}
          value={String(board.missing_channels_count)}
          context={copy.missingContext(matches)}
          tone={board.missing_channels_count > 0 ? 'attention' : 'default'}
          href="/matches"
        />
        <KpiCard
          icon="alert"
          label={copy.placeholders}
          value={String(board.placeholders_to_complete)}
          context={copy.placeholdersContext}
          tone={board.placeholders_to_complete > 0 ? 'attention' : 'default'}
          href="/channels"
        />
        <KpiCard
          icon="database"
          label={copy.sourcesHealth}
          value={board.sources.length === 0 ? '—' : `${Math.round((healthy / board.sources.length) * 100)}%`}
          context={copy.sourcesContext(healthy, board.sources.length)}
          progress={
            board.sources.length === 0 ? undefined : { value: healthy, max: board.sources.length }
          }
          href="/sources"
        />
      </div>

      <div className="grid gap-4 lg:grid-cols-2">
        <section className="flex min-w-0 flex-col gap-3 rounded-xl bg-surface-1 p-4 ring-1 ring-inset ring-divider">
          <div className="flex items-center gap-2">
            <h2 className="heading-2 min-w-0 flex-1 text-text-primary">{copy.missingTitle}</h2>
            <Link to="/matches" className={clsx('text-caption font-semibold text-accent-text', focusRing)}>
              {copy.missingOpen}
            </Link>
          </div>

          {board.missing_channels.length === 0 ? (
            <p className="text-label text-text-secondary">{copy.missingEmpty}</p>
          ) : (
            <div className="flex flex-col gap-3">
              {board.missing_channels.map((group) => (
                <div key={String(group.competition.id ?? group.competition.name)} className="flex flex-col gap-1">
                  <div className="flex items-center gap-2">
                    <bdi className="text-caption font-semibold text-text-secondary">{group.competition.name}</bdi>
                    <span className="text-micro rounded-pill bg-surface-3 px-2 tabular-nums text-text-secondary">
                      {group.matches.length}
                    </span>
                  </div>
                  <ul className="flex flex-col gap-1">
                    {group.matches.map((match) => (
                      <li key={match.id}>
                        <Link
                          to={`/matches/${match.id}`}
                          className={clsx(
                            'text-label flex items-center gap-2 rounded-sm px-2 py-1 text-text-primary hover:bg-surface-2',
                            focusRing,
                          )}
                        >
                          <IconBall />
                          <bdi className="min-w-0 flex-1 truncate">
                            {match.home} × {match.away}
                          </bdi>
                          <span className="text-caption text-text-tertiary">
                            {match.kickoff_at ? formatCairoTime(match.kickoff_at) : '—'}
                          </span>
                        </Link>
                      </li>
                    ))}
                  </ul>
                </div>
              ))}
            </div>
          )}
        </section>

        <section className="flex min-w-0 flex-col gap-3 rounded-xl bg-surface-1 p-4 ring-1 ring-inset ring-divider">
          <div className="flex items-center gap-2">
            <h2 className="heading-2 min-w-0 flex-1 text-text-primary">{copy.sourceTitle}</h2>
            <Link to="/sources" className={clsx('text-caption font-semibold text-accent-text', focusRing)}>
              {copy.sourceOpen}
            </Link>
          </div>
          <ul aria-label={copy.sourceTitle} className="flex flex-col gap-2">
            {board.sources.map((source) => (
              <SourceTile key={source.name} source={source} />
            ))}
          </ul>
        </section>
      </div>

      <section className="flex min-w-0 flex-col gap-3 rounded-xl bg-surface-1 p-4 ring-1 ring-inset ring-divider">
        <h2 className="heading-2 text-text-primary">{copy.recentTitle}</h2>
        {board.recent_changes.length === 0 ? (
          <p className="text-label text-text-secondary">{copy.recentEmpty}</p>
        ) : (
          <ul className="flex flex-col divide-y divide-divider">
            {board.recent_changes.map((change, index) => (
              <li
                key={`${change.at}-${String(change.entity_id)}-${index}`}
                className="flex flex-wrap items-center gap-2 py-2"
              >
                <span className="text-caption flex-1 text-text-primary">{recentLine(change)}</span>
                <span className="text-micro text-text-tertiary">{formatCairoTime(change.at)}</span>
              </li>
            ))}
          </ul>
        )}
      </section>
    </div>
  );
}

function IconBall(): ReactElement {
  return <span aria-hidden="true" className="size-1 rounded-pill bg-text-tertiary" />;
}
