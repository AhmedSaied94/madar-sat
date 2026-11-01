import { clsx } from 'clsx';
import type { ReactElement } from 'react';
import { Link, useParams } from 'react-router-dom';

import type { ImportRunDetail } from '../../api/generated/admin.schemas';
import { EmptyState } from '../../components/EmptyState/EmptyState';
import { focusRing } from '../../components/focus';
import { formatCairoTime } from '../../lib/cairoTime';
import { copyForErrorCode, sources as copy } from '../../i18n/ar';
import { useImportRun } from './queries';

// A13's run detail (admin board "SourceRun"): the counts of one run and the compact log the importer
// kept, with the unmatched matches and the placeholders it created.

const statusTone: Record<ImportRunDetail['status'], string> = {
  running: 'bg-surface-2 text-text-secondary',
  succeeded: 'bg-free-container text-free',
  partial: 'bg-postponed-container text-postponed',
  failed: 'bg-error-container text-error',
};

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

  return (
    <div className="flex min-w-0 flex-1 flex-col gap-4">
      <div className="flex flex-wrap items-end gap-3">
        <div className="min-w-0">
          <p className="text-caption text-text-tertiary">{copy.title}</p>
          <h1 className="heading-1 text-text-primary">{copy.detail.title}</h1>
          <p className="text-caption text-text-secondary">
            {formatCairoTime(detail.started_at)} · {formatCairoTime(detail.started_at)}
            {detail.finished_at ? ` — ${formatCairoTime(detail.finished_at)}` : ''}
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

      <div className="grid gap-3 sm:grid-cols-3">
        <Stat label={copy.detail.itemsFound} value={detail.items_found} />
        <Stat label={copy.detail.itemsUpserted} value={detail.items_upserted} />
        <Stat label={copy.detail.httpErrors} value={detail.http_errors} />
      </div>

      <section className="flex flex-col gap-3 rounded-xl bg-surface-1 p-4 ring-1 ring-inset ring-divider">
        <h2 className="heading-2 text-text-primary">{copy.detail.log}</h2>
        {!detail.log_available ? (
          <p className="text-caption text-text-tertiary">{copy.detail.logUnavailable}</p>
        ) : (
          <div className="grid gap-4 md:grid-cols-2">
            <ListBlock label={copy.detail.unmatched} items={textList(logObject['unmatched_matches'])} />
            <ListBlock label={copy.detail.placeholders} items={textList(logObject['placeholders_created'])} />
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
