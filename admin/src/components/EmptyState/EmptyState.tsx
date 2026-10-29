import { cva } from 'class-variance-authority';
import type { ReactElement } from 'react';

import { focusRing } from '../focus';
import { Icon, type IconName } from '../Icon/Icon';

// What a screen shows when there is nothing to list or loading failed (EmptyState README):
// the orbit-ring illustration, a title, one line of help and at most one action.

export type EmptyStateKind = 'empty' | 'error' | 'allClear';

const glyphStyles = cva('relative inline-flex size-12 items-center justify-center rounded-pill', {
  variants: {
    kind: {
      empty: 'bg-surface-2 text-text-secondary',
      error: 'bg-error-container text-error',
      allClear: 'bg-free-container text-free',
    },
  },
});

const glyphIcon: Record<EmptyStateKind, IconName> = {
  empty: 'search',
  error: 'alert',
  allClear: 'check',
};

interface EmptyStateProps {
  kind: EmptyStateKind;
  title: string;
  body: string;
  action?: { label: string; onClick: () => void };
}

export function EmptyState({ kind, title, body, action }: EmptyStateProps): ReactElement {
  return (
    <div data-testid="empty-state" data-kind={kind} className="flex flex-col items-center gap-3 px-8 py-12 text-center">
      <div aria-hidden="true" className="relative flex items-center justify-center p-8">
        <span className="absolute inset-0 rounded-pill ring-1 ring-inset ring-divider" />
        <span className="absolute inset-4 rounded-pill ring-1 ring-inset ring-divider-strong" />
        <span className="absolute end-2 top-3 size-2 rounded-pill bg-accent" />
        <span data-testid="empty-state-glyph" className={glyphStyles({ kind })}>
          <Icon name={glyphIcon[kind]} size="xl" />
        </span>
      </div>
      <h2 className="heading-2 text-text-primary">{title}</h2>
      <p className="text-body max-w-list-pane-width text-text-secondary">{body}</p>
      {action ? (
        <button
          type="button"
          onClick={action.onClick}
          className={`text-label h-8 rounded-md bg-surface-2 px-4 font-semibold text-text-primary hover:bg-surface-3 ${focusRing}`}
        >
          {action.label}
        </button>
      ) : null}
    </div>
  );
}
