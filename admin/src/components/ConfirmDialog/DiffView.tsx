import type { ReactElement } from 'react';

import { dialogs } from '../../i18n/ar';

// The diff extracted from `ConflictDialog` (contract admin-screens, top): the dialog keeps `stacked`,
// A17 asks for `columns` — the قبل / بعد grid the audit board draws. Both take the same `changes`, so a
// conflict and an audit entry never grow two renderings of the same thing.

export interface ConflictChange {
  /** The API field name, shown as a mono LTR key. */
  field: string;
  /** Its Arabic label. */
  label: string;
  before: string | null;
  after: string | null;
}

export type DiffLayout = 'stacked' | 'columns';

interface DiffViewProps {
  changes: readonly ConflictChange[];
  layout: DiffLayout;
}

const shown = (value: string | null): string => value ?? '—';

/** One key/value line, with the key in its Latin direction and the value beside it. */
function Line({
  change,
  side,
  tone,
}: {
  change: ConflictChange;
  side: 'before' | 'after';
  tone?: 'added' | 'removed';
}): ReactElement {
  const value = side === 'before' ? change.before : change.after;
  return (
    <div
      data-change={side}
      className={
        tone === 'added'
          ? 'text-label flex items-baseline gap-2 rounded-xs bg-free-container px-2 py-1 text-free'
          : tone === 'removed'
            ? 'text-label flex items-baseline gap-2 rounded-xs bg-error-container px-2 py-1 text-error'
            : 'text-label flex items-baseline gap-2 px-2 py-1'
      }
    >
      <bdi dir="ltr" className="text-micro font-mono text-text-tertiary">
        {change.field}
      </bdi>
      <bdi className="min-w-0 flex-1 break-all text-text-primary">{shown(value)}</bdi>
    </div>
  );
}

function StackedDiff({ changes }: { changes: readonly ConflictChange[] }): ReactElement {
  return (
    <div data-testid="diff" className="flex flex-col gap-3 rounded-lg bg-bg p-4">
      {changes.map((change) => (
        <div key={change.field} className="flex flex-col gap-1">
          <span className="text-caption flex items-center gap-2 font-semibold text-text-secondary">
            {change.label}
            <bdi dir="ltr" className="text-micro font-mono text-text-tertiary">
              {change.field}
            </bdi>
          </span>
          <p data-testid="diff-before" className="text-label rounded-xs bg-error-container px-2 py-1 text-error">
            <span aria-hidden="true" className="me-2 font-mono">
              −
            </span>
            <bdi data-change="before">{shown(change.before)}</bdi>
          </p>
          <p data-testid="diff-after" className="text-label rounded-xs bg-free-container px-2 py-1 text-free">
            <span aria-hidden="true" className="me-2 font-mono">
              +
            </span>
            <bdi data-change="after">{shown(change.after)}</bdi>
          </p>
        </div>
      ))}
    </div>
  );
}

function ColumnsDiff({ changes }: { changes: readonly ConflictChange[] }): ReactElement {
  if (changes.length === 0) return <div data-testid="diff" />;
  return (
    <div data-testid="diff" className="grid grid-cols-2 gap-4 rounded-lg bg-bg p-4">
      <div data-testid="diff-before" className="flex min-w-0 flex-col gap-1">
        <span className="text-caption border-b border-divider pb-1 font-semibold text-text-secondary">
          {dialogs.before}
        </span>
        {changes.map((change) => (
          <Line key={change.field} change={change} side="before" />
        ))}
      </div>
      <div data-testid="diff-after" className="flex min-w-0 flex-col gap-1">
        <span className="text-caption border-b border-divider pb-1 font-semibold text-text-secondary">
          {dialogs.after}
        </span>
        {changes.map((change) => (
          <Line key={change.field} change={change} side="after" />
        ))}
      </div>
    </div>
  );
}

export function DiffView({ changes, layout }: DiffViewProps): ReactElement {
  return layout === 'columns' ? <ColumnsDiff changes={changes} /> : <StackedDiff changes={changes} />;
}
