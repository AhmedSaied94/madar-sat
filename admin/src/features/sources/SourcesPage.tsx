import { clsx } from 'clsx';
import { useState, type ReactElement } from 'react';
import { Link } from 'react-router-dom';

import { pauseSource, resumeSource, runSource } from '../../api/generated/admin';
import type { ImportRunRow, SourceHealth } from '../../api/generated/admin.schemas';
import { ApiError, NETWORK_ERROR } from '../../api/http';
import { EmptyState } from '../../components/EmptyState/EmptyState';
import { Icon } from '../../components/Icon/Icon';
import { HealthChip, type SourceHealth as HealthTone } from '../../components/StatusChip/StatusChip';
import { useToast } from '../../components/Toast/Toast';
import { focusRing } from '../../components/focus';
import { formatCairoTime } from '../../lib/cairoTime';
import { copyForErrorCode, sources as copy } from '../../i18n/ar';
import { useRefreshAdmin } from '../../lib/useRefreshAdmin';
import { UnresolvedQueue } from '../unresolved/UnresolvedQueue';
import { useSources, useSourceRuns } from './queries';

// A13 (admin board "Sources"): one card per source with its health, the last 24 hours as a sparkline,
// «تشغيل الآن» disabled while a run holds the lock, pause and resume, and one source's run history
// underneath with its cursor. The health refetches every 30 s while the page is visible (R24).

/** The chip's tone from the breaker and the last 24 hours' error rate. */
export function healthTone(source: SourceHealth): HealthTone {
  if (source.breaker === 'open') return 'open';
  // A run the scheduler chose not to start is not a fault: no red, no amber (contract A13).
  if (source.last_run?.status === 'stopped') return 'neutral';
  if (source.last_run?.status === 'failed' || (source.error_rate_24h ?? 0) >= 0.5) return 'near_limit';
  return 'ok';
}

function Sparkline({ values }: { values: readonly number[] }): ReactElement {
  const peak = Math.max(1, ...values);
  return (
    <span aria-hidden="true" className="flex h-8 items-end gap-1">
      {values.length === 0 ? <span className="text-caption text-text-tertiary">—</span> : null}
      {values.map((value, index) => (
        <span
          key={index}
          className="w-1 rounded-pill bg-free"
          style={{ height: `${Math.max(6, Math.round((value / peak) * 100))}%` }}
        />
      ))}
    </span>
  );
}

function SourceCard({
  source,
  selected,
  onSelect,
  busy,
  onRun,
  onPause,
  onResume,
}: {
  source: SourceHealth;
  selected: boolean;
  onSelect: () => void;
  busy: boolean;
  onRun: () => void;
  onPause: () => void;
  onResume: () => void;
}): ReactElement {
  const tone = healthTone(source);
  const live = source.live ?? null;
  return (
    <li
      data-testid={`source-${source.name}`}
      data-selected={selected || undefined}
      className={clsx(
        'flex min-w-0 flex-col gap-3 rounded-xl bg-surface-1 p-4 ring-1 ring-inset',
        selected ? 'ring-accent' : 'ring-divider',
      )}
    >
      <div className="flex items-start gap-2">
        <bdi dir="ltr" className="text-label min-w-0 flex-1 truncate font-mono font-semibold text-text-primary">
          {live === null ? source.name : copy.live.name}
        </bdi>
        <HealthChip health={tone}>
          {tone === 'open'
            ? copy.breakerOpen
            : tone === 'neutral'
              ? copy.stopped[reasonOf(source)]
              : tone === 'near_limit'
                ? copy.runStatus.partial
                : copy.healthy}
        </HealthChip>
      </div>

      {live === null ? (
        <>
          <div className="flex items-center justify-between gap-2">
            <span className="text-caption text-text-secondary">
              {source.last_success_at ? copy.lastSuccess(formatCairoTime(source.last_success_at)) : copy.neverSucceeded}
            </span>
            <Sparkline values={source.items_24h} />
          </div>

          <p className="text-caption text-text-tertiary">
            {source.error_rate_24h === null
              ? copy.noErrorRate
              : copy.errorRate(Math.round(source.error_rate_24h * 100))}
            {source.paused ? ` · ${copy.paused}` : null}
          </p>
        </>
      ) : (
        <>
          <div className="grid grid-cols-3 gap-2">
            <LiveStat label={copy.live.matchesLabel} value={copy.live.matchesLive(live.matches_live)} />
            <LiveStat label={copy.live.shareLabel} value={copy.live.errorShare(Math.round(live.error_share * 100))} />
            <LiveStat label={copy.live.readersLabel} value={String(live.sources.length)} />
          </div>
          <ul className="flex flex-wrap gap-2">
            {live.sources.map((reader) => (
              <li key={reader.name} className="text-caption flex items-center gap-1 text-text-secondary">
                <bdi dir="ltr" className="font-mono">
                  {reader.name}
                </bdi>
                <span
                  data-state={reader.state}
                  className={clsx(
                    'text-micro rounded-xs px-2 py-1',
                    reader.state === 'ok' ? 'bg-free-container text-free' : 'bg-error-container text-error',
                  )}
                >
                  {copy.live.readerState[reader.state] ?? reader.state}
                </span>
              </li>
            ))}
          </ul>
        </>
      )}

      <div className="flex flex-wrap items-center gap-2">
        {live === null ? (
          <button
            type="button"
            disabled={source.running || busy}
            onClick={onRun}
            className={clsx(
              'text-caption inline-flex h-8 items-center gap-2 rounded-md bg-accent px-3 font-semibold text-on-accent disabled:cursor-not-allowed disabled:bg-surface-3 disabled:text-text-disabled',
              focusRing,
            )}
          >
            <Icon name="refresh" size="sm" />
            {source.running ? copy.running : copy.runNow}
          </button>
        ) : (
          <span className="text-caption text-text-tertiary">{copy.live.noRun}</span>
        )}
        <button
          type="button"
          disabled={busy}
          onClick={source.paused ? onResume : onPause}
          className={clsx(
            'text-caption inline-flex h-8 items-center gap-2 rounded-md bg-surface-2 px-3 font-semibold text-text-primary hover:bg-surface-3 disabled:cursor-not-allowed disabled:text-text-disabled',
            focusRing,
          )}
        >
          {source.paused ? copy.resume : copy.pause}
        </button>
        <button
          type="button"
          onClick={onSelect}
          aria-pressed={selected}
          className={clsx(
            'text-caption ms-auto inline-flex h-8 items-center rounded-md px-2 font-semibold',
            selected ? 'text-accent-text' : 'text-text-secondary hover:text-text-primary',
            focusRing,
          )}
        >
          {copy.openRuns}
        </button>
      </div>
    </li>
  );
}

/** One figure of the Live poller card, in the board's mini form. */
function LiveStat({ label, value }: { label: string; value: string }): ReactElement {
  return (
    <div className="flex flex-col gap-1 rounded-md bg-surface-2 px-2 py-1">
      <b className="text-label tabular-nums text-text-primary">{value}</b>
      <span className="text-micro text-text-tertiary">{label}</span>
    </div>
  );
}

const RUN_STATUS_KEY: Record<ImportRunRow['status'], keyof typeof copy.runStatus> = {
  running: 'running',
  succeeded: 'succeeded',
  partial: 'partial',
  failed: 'failed',
  stopped: 'stopped',
};

/** A stopped run's reason, from the two the scheduler uses; anything else stays as it came. */
export function reasonOf(source: SourceHealth): 'not_configured' | 'budget_reached' {
  return source.last_run?.error === 'budget_reached' ? 'budget_reached' : 'not_configured';
}

/** The reason of a stopped run, in Arabic (contract A13). */
function stoppedReason(error: string | null): string | null {
  if (error === null) return null;
  return error === 'not_configured' ? copy.stopped.not_configured : error === 'budget_reached' ? copy.stopped.budget_reached : error;
}

export function SourcesPage(): ReactElement {
  const { data, isPending, isError, error } = useSources();
  const sources = data?.data ?? [];
  const [selectedName, setSelectedName] = useState<string | null>(null);
  const [cursor, setCursor] = useState<string | null>(null);
  const [cursorTrail, setCursorTrail] = useState<readonly (string | null)[]>([]);
  const [busy, setBusy] = useState<string | null>(null);
  const toast = useToast();
  const refresh = useRefreshAdmin();

  const selected = selectedName ?? sources[0]?.name ?? null;
  const runs = useSourceRuns(selected, cursor);
  const runRows = runs.data?.data ?? [];
  const nextCursor = (runs.data?.meta as { next_cursor?: string | null } | undefined)?.next_cursor ?? null;

  async function call(name: string, action: () => Promise<unknown>, done: string): Promise<void> {
    setBusy(name);
    try {
      await action();
      toast.show({ kind: 'success', title: done });
      refresh();
    } catch (failure) {
      const code = failure instanceof ApiError ? failure.code : NETWORK_ERROR;
      toast.show({ kind: 'error', title: copy.runNow, description: copyForErrorCode(code) });
      refresh();
    } finally {
      setBusy(null);
    }
  }

  return (
    <div className="flex min-w-0 flex-1 flex-col gap-4">
      <div className="flex flex-wrap items-end gap-3">
        <div className="min-w-0">
          <h1 className="heading-1 text-text-primary">{copy.title}</h1>
          <p className="text-caption text-text-secondary">{copy.subtitle(sources.length)}</p>
        </div>
      </div>

      {isPending ? (
        <p className="text-label text-text-secondary">{copy.detail.loading}</p>
      ) : isError ? (
        <EmptyState
          kind="error"
          title={copyForErrorCode(error?.code ?? '')}
          body={copy.detail.logUnavailable}
          action={{ label: copy.loadMore, onClick: () => void refresh() }}
        />
      ) : (
        <ul aria-label={copy.title} className="grid gap-3 md:grid-cols-2 xl:grid-cols-3">
          {sources.map((source) => (
            <SourceCard
              key={source.name}
              source={source}
              selected={source.name === selected}
              busy={busy === source.name}
              onSelect={() => {
                setSelectedName(source.name);
                setCursor(null);
                setCursorTrail([]);
              }}
              onRun={() => void call(source.name, () => runSource(source.name), copy.runQueued)}
              onPause={() => void call(source.name, () => pauseSource(source.name), copy.pauseDone)}
              onResume={() => void call(source.name, () => resumeSource(source.name), copy.resumeDone)}
            />
          ))}
        </ul>
      )}

      <UnresolvedQueue />

      {selected === null ? null : (
        <section className="flex min-w-0 flex-col gap-3 rounded-xl bg-surface-1 p-4 ring-1 ring-inset ring-divider">
          <h2 className="heading-2 text-text-primary">{copy.runsTitle(selected)}</h2>

          {runs.isPending ? (
            <p className="text-label text-text-secondary">{copy.detail.loading}</p>
          ) : runRows.length === 0 ? (
            <p className="text-label text-text-secondary">{copy.noRuns}</p>
          ) : (
            <table className="w-full border-collapse text-start">
              <caption className="sr-only">{copy.runsTitle(selected)}</caption>
              <thead>
                <tr className="text-micro border-b border-divider text-start text-text-tertiary">
                  <th scope="col" className="p-2 text-start">{copy.columns.started}</th>
                  <th scope="col" className="p-2 text-start">{copy.columns.status}</th>
                  <th scope="col" className="p-2 text-end">{copy.columns.found}</th>
                  <th scope="col" className="p-2 text-end">{copy.columns.upserted}</th>
                  <th scope="col" className="p-2 text-end">{copy.columns.httpErrors}</th>
                  <th scope="col" className="p-2" />
                </tr>
              </thead>
              <tbody>
                {runRows.map((run) => (
                  <tr key={run.id} data-testid={`run-${run.id}`} className="border-b border-divider last:border-0">
                    <td className="text-caption p-2 text-text-secondary">
                      {formatCairoTime(run.started_at)} · {formatCairoTime(run.started_at)}
                    </td>
                    <td className="text-caption p-2">
                      <span className="flex flex-wrap items-center gap-2">
                        <span
                          data-status={run.status}
                          className={clsx(
                            'text-micro rounded-xs px-2 py-1',
                            run.status === 'failed'
                              ? 'bg-error-container text-error'
                              : run.status === 'partial'
                                ? 'bg-postponed-container text-postponed'
                                : run.status === 'running'
                                  ? 'bg-surface-2 text-text-secondary'
                                  : run.status === 'stopped'
                                    ? 'bg-surface-2 text-text-tertiary'
                                    : 'bg-free-container text-free',
                          )}
                        >
                          {copy.runStatus[RUN_STATUS_KEY[run.status]]}
                        </span>
                        {run.status === 'stopped' && stoppedReason(run.error) !== null ? (
                          <span className="text-micro text-text-tertiary">{stoppedReason(run.error)}</span>
                        ) : null}
                      </span>
                    </td>
                    <td className="text-caption p-2 text-end tabular-nums text-text-primary">{run.items_found}</td>
                    <td className="text-caption p-2 text-end tabular-nums text-text-primary">{run.items_upserted}</td>
                    <td className="text-caption p-2 text-end tabular-nums text-text-secondary">{run.http_errors}</td>
                    <td className="p-2 text-end">
                      <Link
                        to={`/import-runs/${run.id}`}
                        className={`text-caption font-semibold text-accent-text ${focusRing}`}
                      >
                        {copy.columns.detail}
                      </Link>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          )}

          {nextCursor ? (
            <button
              type="button"
              onClick={() => {
                setCursorTrail((trail) => [...trail, cursor]);
                setCursor(nextCursor);
              }}
              className={`text-caption self-start font-semibold text-accent-text ${focusRing}`}
            >
              {copy.loadMore}
            </button>
          ) : null}
          {cursorTrail.length > 0 ? (
            <button
              type="button"
              onClick={() => {
                const trail = [...cursorTrail];
                const previous = trail.pop() ?? null;
                setCursorTrail(trail);
                setCursor(previous);
              }}
              className={`text-caption self-start font-semibold text-text-secondary ${focusRing}`}
            >
              {copy.previous}
            </button>
          ) : null}
        </section>
      )}
    </div>
  );
}
