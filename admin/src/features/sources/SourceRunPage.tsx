import { clsx } from 'clsx';
import { useEffect, useState, type ReactElement } from 'react';
import { Link, useParams } from 'react-router-dom';

import { useGetImportRunRaw } from '../../api/generated/admin';
import type { ImportRunDetail, RawPage, RawPageState } from '../../api/generated/admin.schemas';
import { EmptyState } from '../../components/EmptyState/EmptyState';
import { Button } from '../../components/Button/Button';
import { focusRing } from '../../components/focus';
import { formatCairoTime } from '../../lib/cairoTime';
import { copyForErrorCode, sources as copy } from '../../i18n/ar';
import { useImportRun } from './queries';

// A13's run detail (admin board "SourceRun"): the pipeline stages derived from the compact log, the
// log itself, and the page the run saved. The saved page reaches the admin over Redis (research R13)
// and is always shown as inert text: the workers' output never becomes markup in this app.

const statusTone: Record<ImportRunDetail['status'], string> = {
  running: 'bg-surface-2 text-text-secondary',
  succeeded: 'bg-free-container text-free',
  partial: 'bg-postponed-container text-postponed',
  failed: 'bg-error-container text-error',
};

/** How often a `pending` page is asked again, and how many answers it may take (10 s, per contract). */
export const RAW_POLL_MS = 1000;
export const RAW_POLL_TRIES = 10;

/** The next poll's delay: `pending` keeps asking up to the cap, anything else stops. */
export function rawPollInterval(state: RawPageState | undefined, polls: number): number | false {
  return state === 'pending' && polls < RAW_POLL_TRIES ? RAW_POLL_MS : false;
}

type StageState = 'done' | 'failed' | 'notStarted';

interface Stage {
  id: 'fetch' | 'parse' | 'normalize' | 'resolve' | 'upsert';
  state: StageState;
  detail: string | null;
}

function numberAt(source: Record<string, unknown>, key: string): number | null {
  const value = source[key];
  return typeof value === 'number' && !Number.isNaN(value) ? value : null;
}

function countAt(source: Record<string, unknown>, key: string): number | null {
  const value = source[key];
  if (typeof value !== 'object' || value === null) return null;
  return numberAt(value as Record<string, unknown>, 'count');
}

/**
 * The board's five stages, from the compact log: `fetch` from the planned targets and the HTTP
 * errors, `parse` and `upsert` from the counts, `resolve` from the unresolved names. The log records
 * no `normalize` count, so that one stays «لم يبدأ» — the contract says so rather than guessing.
 */
export function stagesOf(detail: ImportRunDetail): Stage[] {
  const log = typeof detail.log === 'object' && detail.log !== null ? (detail.log as Record<string, unknown>) : {};
  const counts = typeof log['counts'] === 'object' && log['counts'] !== null
    ? (log['counts'] as Record<string, unknown>)
    : {};
  const targets = numberAt(counts, 'targets');
  const httpErrors = numberAt(counts, 'http_errors');
  const found = numberAt(counts, 'items_found');
  const upserted = numberAt(counts, 'items_upserted');
  const unresolved = countAt(log, 'unresolved');
  const reachedParsing = found !== null && found > 0;

  return [
    {
      id: 'fetch',
      state: httpErrors !== null && httpErrors > 0 && !reachedParsing ? 'failed' : 'done',
      detail: targets === null ? null : copy.stages.pages(targets),
    },
    {
      id: 'parse',
      state: reachedParsing ? 'done' : 'notStarted',
      detail: found === null ? null : copy.stages.items(found),
    },
    { id: 'normalize', state: 'notStarted', detail: null },
    {
      id: 'resolve',
      state: reachedParsing ? 'done' : 'notStarted',
      detail: unresolved === null ? null : copy.stages.unresolved(unresolved),
    },
    {
      id: 'upsert',
      state: reachedParsing ? 'done' : 'notStarted',
      detail: upserted === null ? null : copy.stages.saved(upserted),
    },
  ];
}

function Stat({ label, value }: { label: string; value: string | number }): ReactElement {
  return (
    <div className="flex flex-col gap-1 rounded-lg bg-surface-1 p-3 ring-1 ring-inset ring-divider">
      <span className="text-caption text-text-secondary">{label}</span>
      <span className="heading-2 tabular-nums text-text-primary">{value}</span>
    </div>
  );
}

function ListBlock({ label, items }: { label: string; items: readonly string[] }): ReactElement {
  return (
    <div className="flex flex-col gap-1">
      <span className="text-caption font-semibold text-text-secondary">{`${label} (${items.length})`}</span>
      {items.length === 0 ? (
        <span className="text-caption text-text-tertiary">{copy.detail.empty}</span>
      ) : (
        <ul className="flex flex-col gap-1">
          {items.map((item, index) => (
            <li key={index} className="text-caption rounded-xs bg-bg px-2 py-1 text-text-secondary">
              {item}
            </li>
          ))}
        </ul>
      )}
    </div>
  );
}

function textList(value: unknown): string[] {
  return Array.isArray(value) ? value.map((item) => (typeof item === 'string' ? item : JSON.stringify(item))) : [];
}

/** A log list in either shape: D4 wrote a plain array, D5 writes `{count, items}` capped by 64 KB. */
function logList(value: unknown): string[] {
  if (Array.isArray(value)) return textList(value);
  if (typeof value !== 'object' || value === null) return [];
  return textList((value as Record<string, unknown>)['items']);
}

const stageTone: Record<StageState, string> = {
  done: 'bg-free-container text-free',
  failed: 'bg-error-container text-error',
  notStarted: 'bg-surface-2 text-text-secondary',
};

/** One page of the run's saved output, as the worker left it. */
function RawPagePanel({ runId, pages }: { runId: number; pages: number }): ReactElement {
  const [open, setOpen] = useState(false);
  const [page, setPage] = useState(0);
  const [polls, setPolls] = useState(0);

  const raw = useGetImportRunRaw(
    runId,
    { page },
    {
      query: {
        enabled: open,
        structuralSharing: false,
        refetchInterval: (query) => rawPollInterval(query.state.data?.data?.state, polls),
      },
    },
  );

  const state = raw.data?.data?.state;

  // Each `pending` answer counts once, so the ten-second window ends even if the interval agrees.
  useEffect(() => {
    if (state !== 'pending') return;
    setPolls((current) => current + 1);
  }, [state, raw.dataUpdatedAt]);

  useEffect(() => {
    setPolls(0);
  }, [page, open]);

  const body: RawPage | null | undefined = raw.data?.data;
  const gaveUp = state === 'pending' && polls >= RAW_POLL_TRIES;

  return (
    <section className="flex flex-col gap-3 rounded-xl bg-surface-1 p-4 ring-1 ring-inset ring-divider">
      <div className="flex flex-wrap items-center gap-2">
        <h2 className="heading-2 text-text-primary">{copy.raw.open}</h2>
        <Button variant={open ? 'secondary' : 'outline'} size="sm" onClick={() => setOpen((value) => !value)}>
          {open ? copy.raw.close : copy.raw.open}
        </Button>
        {pages > 1 ? (
          <span className="text-caption tabular-nums text-text-tertiary">{copy.raw.page(page, pages)}</span>
        ) : null}
        {pages > 1 ? (
          <span className="flex items-center gap-1">
            <Button variant="ghost" size="xs" disabled={page === 0} onClick={() => setPage((value) => value - 1)}>
              ‹
            </Button>
            <Button
              variant="ghost"
              size="xs"
              disabled={page >= pages - 1}
              onClick={() => setPage((value) => value + 1)}
            >
              ›
            </Button>
          </span>
        ) : null}
      </div>

      {!open ? null : raw.isPending ? (
        <p className="text-label text-text-secondary">{copy.raw.pending}</p>
      ) : gaveUp ? (
        <p role="alert" className="text-label font-semibold text-error">
          {copy.raw.timeout}
        </p>
      ) : body === undefined || body === null ? (
        <p className="text-label text-text-secondary">{copyForErrorCode(raw.error?.code ?? '')}</p>
      ) : body.state === 'pending' ? (
        <p role="status" className="text-label text-text-secondary">
          {copy.raw.pending}
        </p>
      ) : body.state === 'gone' ? (
        <p className="text-label text-text-secondary">{copy.raw.gone}</p>
      ) : (
        <div data-testid="raw-page" className="flex flex-col gap-2">
          <div className="flex flex-wrap items-center gap-2">
            <span className="text-caption text-text-tertiary">{copy.raw.url}</span>
            {body.url === null ? null : (
              <bdi dir="ltr" className="text-micro font-mono text-text-secondary">
                {body.url}
              </bdi>
            )}
            {body.content_type === null ? null : (
              <bdi dir="ltr" className="text-micro font-mono text-text-tertiary">
                {body.content_type}
              </bdi>
            )}
            {body.truncated ? (
              <span className="text-micro rounded-xs bg-postponed-container px-2 py-1 text-postponed">
                {copy.raw.truncated}
              </span>
            ) : null}
          </div>
          <p className="text-caption text-text-tertiary">{copy.raw.inert}</p>
          <pre
            dir="ltr"
            className="raw-page-text text-micro overflow-auto rounded-lg bg-bg p-3 font-mono whitespace-pre-wrap break-all text-text-secondary"
          >
            {body.text}
          </pre>
        </div>
      )}
    </section>
  );
}

export function SourceRunPage(): ReactElement {
  const { id } = useParams<{ id: string }>();
  const runId = id === undefined ? null : Number(id);
  const valid = runId !== null && Number.isInteger(runId) && runId > 0;
  const run = useImportRun(valid ? runId : null);

  if (!valid) {
    return (
      <EmptyState
        kind="error"
        title={copy.detail.notFound}
        body={copy.detail.logUnavailable}
        action={{ label: copy.detail.back, onClick: () => window.history.back() }}
      />
    );
  }

  if (run.isPending) {
    return <p className="text-label text-text-secondary">{copy.detail.loading}</p>;
  }

  const detail = run.data?.data;
  if (!detail) {
    return (
      <EmptyState
        kind="error"
        title={copyForErrorCode(run.error?.code ?? '')}
        body={copy.detail.logUnavailable}
        action={{ label: copy.detail.back, onClick: () => window.history.back() }}
      />
    );
  }

  const log = detail.log;
  const logObject = typeof log === 'object' && log !== null ? (log as Record<string, unknown>) : {};
  const worker = detail.worker ?? null;

  return (
    <div className="flex min-w-0 flex-1 flex-col gap-4">
      <div className="flex flex-wrap items-end gap-3">
        <div className="min-w-0">
          <p className="text-caption text-text-tertiary">{copy.title}</p>
          <h1 className="heading-1 text-text-primary">{copy.detail.title}</h1>
          <p className="text-caption text-text-secondary">
            {formatCairoTime(detail.started_at)}
            {detail.finished_at ? ` — ${formatCairoTime(detail.finished_at)}` : ''}
            {worker === null ? null : ' · '}
            {worker === null ? null : (
              <bdi dir="ltr" className="font-mono">
                {worker}
              </bdi>
            )}
          </p>
        </div>
        <span className="flex-1" />
        <Link to="/sources" className={clsx('text-caption font-semibold text-accent-text', focusRing)}>
          {copy.detail.back}
        </Link>
      </div>

      <div className="flex flex-wrap items-center gap-2">
        <span data-status={detail.status} className={clsx('text-micro rounded-xs px-2 py-1', statusTone[detail.status])}>
          {copy.runStatus[detail.status]}
        </span>
        {detail.error ? <span className="text-caption text-error">{detail.error}</span> : null}
        {detail.raw_path ? (
          <bdi dir="ltr" className="text-micro font-mono text-text-tertiary">
            {detail.raw_path}
          </bdi>
        ) : null}
      </div>

      <section
        data-testid="run-stages"
        aria-label={copy.detail.title}
        className="grid gap-2 rounded-xl bg-surface-1 p-4 ring-1 ring-inset ring-divider sm:grid-cols-5"
      >
        {stagesOf(detail).map((stage) => (
          <div key={stage.id} className="flex flex-col gap-1 rounded-lg bg-bg p-2">
            <bdi dir="ltr" className="text-caption font-mono font-semibold text-text-primary">
              {copy.stages[stage.id]}
            </bdi>
            <span className={clsx('text-micro w-fit rounded-xs px-2 py-1', stageTone[stage.state])}>
              {stage.state === 'notStarted'
                ? copy.stages.notStarted
                : stage.state === 'failed'
                  ? copy.stages.failed
                  : copy.stages.done}
            </span>
            {stage.detail === null ? null : (
              <span className="text-caption tabular-nums text-text-tertiary">{stage.detail}</span>
            )}
          </div>
        ))}
      </section>

      <div className="grid gap-3 sm:grid-cols-3">
        <Stat label={copy.detail.itemsFound} value={detail.items_found} />
        <Stat label={copy.detail.itemsUpserted} value={detail.items_upserted} />
        <Stat label={copy.detail.httpErrors} value={detail.http_errors} />
      </div>

      <RawPagePanel runId={detail.id} pages={detail.pages ?? 0} />

      <section className="flex flex-col gap-3 rounded-xl bg-surface-1 p-4 ring-1 ring-inset ring-divider">
        <h2 className="heading-2 text-text-primary">{copy.detail.log}</h2>
        {!detail.log_available ? (
          <p className="text-caption text-text-tertiary">{copy.detail.logUnavailable}</p>
        ) : (
          <div className="grid gap-4 md:grid-cols-2">
            <ListBlock label={copy.detail.unmatched} items={logList(logObject['unmatched'] ?? logObject['unmatched_matches'])} />
            <ListBlock label={copy.detail.placeholders} items={logList(logObject['placeholders_created'])} />
            <ListBlock label={copy.detail.errors} items={textList(logObject['errors'])} />
            <div className="flex flex-col gap-1">
              <span className="text-caption font-semibold text-text-secondary">{copy.detail.skipped}</span>
              <span className="heading-2 tabular-nums text-text-primary">
                {typeof logObject['skipped_channels'] === 'number' ? logObject['skipped_channels'] : copy.detail.empty}
              </span>
            </div>
          </div>
        )}
      </section>
    </div>
  );
}
