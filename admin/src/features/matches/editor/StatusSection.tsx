import type { ReactElement } from 'react';

import type { Period, Status } from '../../../api/generated/admin.schemas';
import { Button } from '../../../components/Button/Button';
import { editor as copy, matchStatus } from '../../../i18n/ar';
import { penaltiesAllowed, scoreAllowed, type EditorState } from '../MatchEditor';

// A4's "الحالة والنتيجة": a manual status overrides the source until it goes back to «تلقائي».
// The score inputs are enabled only where data-model allows a score for that status.
const STATUSES: readonly Status[] = [
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

const PERIODS: readonly Period[] = ['1H', '2H', 'ET1', 'ET2'];

/** The period a manual status carries, so a live edit keeps the half it is in (A-R1-9). */
const periodLabels: Record<Period, string> = {
  '1H': copy.periodFirstHalf,
  '2H': copy.periodSecondHalf,
  ET1: copy.periodExtraFirst,
  ET2: copy.periodExtraSecond,
};

interface StatusSectionProps {
  state: EditorState;
  onChange: (next: Partial<EditorState>) => void;
  onReset: () => void;
}

export function StatusSection({ state, onChange, onReset }: StatusSectionProps): ReactElement {
  const manual = state.statusMode !== 'auto';
  const allowed = manual && scoreAllowed(state.statusMode as Status);
  const pens = manual && penaltiesAllowed(state.statusMode as Status);

  return (
    <section aria-label={copy.statusTitle} className="flex flex-col gap-4 rounded-xl bg-surface-1 p-4 ring-1 ring-inset ring-divider">
      <div className="flex flex-wrap items-center gap-3">
        <h2 className="text-label font-semibold text-text-primary">{copy.statusTitle}</h2>
        <span className="flex-1" />
        {manual ? (
          <Button variant="ghost" size="xs" onClick={onReset}>
            {copy.autoStatus}
          </Button>
        ) : null}
      </div>

      <div className="flex flex-wrap items-end gap-3">
        <label className="flex min-w-0 flex-col gap-2">
          <span className="text-caption font-semibold text-text-secondary">{copy.status}</span>
          <select
            aria-label={copy.status}
            value={state.statusMode}
            onChange={(event) => onChange({ statusMode: event.target.value as EditorState['statusMode'] })}
            className="text-body h-12 rounded-md bg-bg px-3 text-text-primary ring-1 ring-inset ring-divider-strong"
          >
            <option value="auto">{copy.autoStatus}</option>
            {STATUSES.map((value) => (
              <option key={value} value={value}>
                {matchStatus[value]}
              </option>
            ))}
          </select>
        </label>

        <label className="flex flex-col gap-2">
          <span className="text-caption font-semibold text-text-secondary">{`${copy.scoreLabel} · ${copy.home}`}</span>
          <input
            type="number"
            min={0}
            max={99}
            aria-label={`${copy.home} ${copy.scoreLabel}`}
            disabled={!allowed}
            value={state.scoreHome}
            onChange={(event) => onChange({ scoreHome: event.target.value })}
            className="text-body h-12 w-12 rounded-md bg-bg px-3 text-text-primary ring-1 ring-inset ring-divider-strong disabled:opacity-50"
          />
        </label>

        <label className="flex flex-col gap-2">
          <span className="text-caption font-semibold text-text-secondary">{`${copy.scoreLabel} · ${copy.away}`}</span>
          <input
            type="number"
            min={0}
            max={99}
            aria-label={`${copy.away} ${copy.scoreLabel}`}
            disabled={!allowed}
            value={state.scoreAway}
            onChange={(event) => onChange({ scoreAway: event.target.value })}
            className="text-body h-12 w-12 rounded-md bg-bg px-3 text-text-primary ring-1 ring-inset ring-divider-strong disabled:opacity-50"
          />
        </label>

        <label className="flex flex-col gap-2">
          <span className="text-caption font-semibold text-text-secondary">{copy.period}</span>
          <select
            aria-label={copy.period}
            disabled={!manual}
            value={state.period}
            onChange={(event) => onChange({ period: event.target.value as EditorState['period'] })}
            className="text-body h-12 rounded-md bg-bg px-3 text-text-primary ring-1 ring-inset ring-divider-strong disabled:opacity-50"
          >
            <option value="">—</option>
            {PERIODS.map((period) => (
              <option key={period} value={period}>
                {periodLabels[period]}
              </option>
            ))}
          </select>
        </label>

        <label className="flex flex-col gap-2">
          <span className="text-caption font-semibold text-text-secondary">{copy.minute}</span>
          <input
            type="text"
            inputMode="numeric"
            aria-label={copy.minute}
            disabled={!manual}
            value={state.minute}
            onChange={(event) => onChange({ minute: event.target.value })}
            className="text-body h-12 w-12 rounded-md bg-bg px-3 text-text-primary ring-1 ring-inset ring-divider-strong disabled:opacity-50"
          />
        </label>

        <label className="flex flex-col gap-2">
          <span className="text-caption font-semibold text-text-secondary">{`${copy.penalties} · ${copy.home}`}</span>
          <input
            type="number"
            min={0}
            max={99}
            aria-label={`${copy.penalties} ${copy.home}`}
            disabled={!pens}
            value={state.homePen}
            onChange={(event) => onChange({ homePen: event.target.value })}
            className="text-body h-12 w-12 rounded-md bg-bg px-3 text-text-primary ring-1 ring-inset ring-divider-strong disabled:opacity-50"
          />
        </label>

        <label className="flex flex-col gap-2">
          <span className="text-caption font-semibold text-text-secondary">{`${copy.penalties} · ${copy.away}`}</span>
          <input
            type="number"
            min={0}
            max={99}
            aria-label={`${copy.penalties} ${copy.away}`}
            disabled={!pens}
            value={state.awayPen}
            onChange={(event) => onChange({ awayPen: event.target.value })}
            className="text-body h-12 w-12 rounded-md bg-bg px-3 text-text-primary ring-1 ring-inset ring-divider-strong disabled:opacity-50"
          />
        </label>
      </div>

      <p className="text-caption text-text-tertiary">
        {manual ? copy.manualHint : `${copy.autoStatus} · ${copy.manualHint}`}
        {manual && !allowed ? ` · ${copy.scoreNotAllowed}` : ''}
      </p>
    </section>
  );
}
