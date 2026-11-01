import { clsx } from 'clsx';
import type { ReactElement, ReactNode } from 'react';
import { Link } from 'react-router-dom';

import { kpi as copy } from '../../i18n/ar';
import { focusRing } from '../focus';
import { Icon, type IconName } from '../Icon/Icon';

// A dashboard figure (A2, KpiCard README): the work to do leads, with a big tabular number, one line
// of context and, when there is one, the progress bar or the way to the list it counts.

export interface KpiCardProps {
  icon: IconName;
  label: string;
  /** Already formatted, Western digits; the card never formats a number itself. */
  value: string;
  context: string;
  /** `attention` when the work is what needs looking at, never for a total. */
  tone?: 'default' | 'attention' | undefined;
  progress?: { value: number; max: number } | undefined;
  /** Where the counted rows are; every card that counts work links to them. */
  href?: string | undefined;
}

const shell =
  'flex min-w-0 flex-col gap-2 rounded-xl bg-surface-1 p-4 text-start ring-1 ring-inset ring-divider';

export function KpiCard({ icon, label, value, context, tone = 'default', progress, href }: KpiCardProps): ReactElement {
  const body: ReactNode = (
    <>
      <span className="text-caption flex items-center gap-2 font-semibold text-text-secondary">
        <Icon name={icon} size="lg" label={label} className={tone === 'attention' ? 'text-postponed' : 'text-text-tertiary'} />
        {label}
      </span>

      <span className="flex flex-wrap items-baseline gap-2">
        <span
          data-testid="kpi-value"
          className={clsx(
            'heading-1 tabular-nums',
            tone === 'attention' ? 'text-postponed' : 'text-text-primary',
          )}
        >
          {value}
        </span>
        <span className="text-caption text-text-secondary">{context}</span>
      </span>

      {progress ? (
        <span
          role="progressbar"
          aria-label={label}
          aria-valuemin={0}
          aria-valuemax={progress.max}
          aria-valuenow={progress.value}
          aria-valuetext={copy.progress(progress.value, progress.max)}
          className="mt-1 flex h-2 w-full overflow-hidden rounded-pill bg-surface-3"
        >
          <span
            aria-hidden="true"
            className={clsx('h-full rounded-pill', tone === 'attention' ? 'bg-postponed' : 'bg-accent')}
            style={{ width: `${Math.max(0, Math.min(100, (progress.value / progress.max) * 100))}%` }}
          />
        </span>
      ) : null}
    </>
  );

  return (
    <div data-testid="kpi-card" data-tone={tone}>
      {href ? (
        <Link
          to={href}
          aria-label={copy.open(label)}
          className={clsx(shell, 'hover:bg-surface-2', focusRing)}
        >
          {body}
        </Link>
      ) : (
        <div className={shell}>{body}</div>
      )}
    </div>
  );
}
