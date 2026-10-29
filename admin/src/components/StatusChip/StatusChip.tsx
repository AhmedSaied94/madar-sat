import { cva } from 'class-variance-authority';
import type { ReactElement, ReactNode } from 'react';

import { roles, statusChips } from '../../i18n/ar';

// Compact admin labels (StatusChip README). Every chip carries text, so meaning never rests on color.
const chip = 'inline-flex h-5 items-center gap-1 whitespace-nowrap rounded-xs px-2 text-micro';

export type SendState = 'sent' | 'failed' | 'partial' | 'scheduled' | 'live';

const statStyles = cva(chip, {
  variants: {
    kind: {
      sent: 'bg-free-container text-free',
      failed: 'bg-error-container text-error',
      partial: 'bg-postponed-container text-postponed',
      scheduled: 'bg-surface-2 text-text-secondary',
      live: 'bg-live-container text-live',
    },
  },
});

const sendStateLabels: Record<SendState, string> = {
  sent: statusChips.sent,
  failed: statusChips.failed,
  partial: statusChips.partial,
  scheduled: statusChips.scheduled,
  live: statusChips.live,
};

interface StatProps {
  kind: SendState;
  /** Replaces the default label, e.g. a count with an icon in a table cell. */
  children?: ReactNode;
}

export function Stat({ kind, children }: StatProps): ReactElement {
  return (
    <span data-kind={kind} className={statStyles({ kind })}>
      {children ?? sendStateLabels[kind]}
    </span>
  );
}

export type SourceCode = 'YSS' | 'LST' | 'SEZ' | 'YK' | 'API' | 'manual';

export function SourceChip({ source }: { source: SourceCode }): ReactElement {
  if (source === 'manual') {
    return (
      <span data-source="manual" className={`${chip} bg-accent-container text-accent-text`}>
        {statusChips.manualSource}
      </span>
    );
  }
  return (
    <span data-source={source} dir="ltr" className={`${chip} bg-surface-2 font-mono tracking-wide text-text-secondary ring-1 ring-inset ring-divider`}>
      {source}
    </span>
  );
}

export type AdminRoleName = 'admin' | 'editor';

const roleStyles = cva(chip, {
  variants: {
    role: {
      admin: 'bg-accent-container text-accent-text',
      editor: 'bg-sports-container text-sports',
    },
  },
});

export function RoleChip({ role }: { role: AdminRoleName }): ReactElement {
  return (
    <span data-role={role} className={roleStyles({ role })}>
      {roles[role]}
    </span>
  );
}

export type SourceHealth = 'ok' | 'near_limit' | 'open';

const healthStyles = cva('text-caption inline-flex items-center gap-2 whitespace-nowrap font-semibold', {
  variants: {
    health: {
      ok: 'text-success',
      near_limit: 'text-postponed',
      open: 'text-error',
    },
  },
});

const healthLabels: Record<SourceHealth, string> = {
  ok: statusChips.healthOk,
  near_limit: statusChips.healthNearLimit,
  open: statusChips.healthOpen,
};

interface HealthChipProps {
  health: SourceHealth;
  /** Replaces the default label, e.g. «الدائرة مفتوحة». */
  children?: ReactNode;
}

export function HealthChip({ health, children }: HealthChipProps): ReactElement {
  return (
    <span data-health={health} className={healthStyles({ health })}>
      <span data-dot aria-hidden="true" className="size-2 rounded-pill bg-current" />
      {children ?? healthLabels[health]}
    </span>
  );
}
