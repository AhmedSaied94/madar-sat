import { clsx } from 'clsx';
import type { ReactElement } from 'react';

import type { Polarization } from '../../api/generated/admin.schemas';
import { focusRing } from '../focus';

// A frequency as the editor enters it (A7's satellite and A8's channel): MHz, polarization and symbol
// rate stay one LTR island, whatever the surrounding text direction.

export interface FrequencyValue {
  mhz: string;
  pol: Polarization;
  sr: string;
}

export const POLARIZATIONS: readonly Polarization[] = ['H', 'V', 'L', 'R'];

interface FrequencyFieldProps {
  label: string;
  value: FrequencyValue;
  onChange: (next: FrequencyValue) => void;
  hint?: string | undefined;
  error?: string | undefined;
  /** A leading mark in the label, e.g. the station-strength glyph. */
  icon?: 'signal';
}

export function FrequencyField({ label, value, onChange, hint, error, icon }: FrequencyFieldProps): ReactElement {
  return (
    <fieldset className="flex flex-col gap-2">
      <legend className="text-caption flex items-center gap-2 font-semibold text-text-secondary">
        {icon ? <span data-icon={icon} aria-hidden="true" className="size-2 rounded-pill bg-current" /> : null}
        {label}
      </legend>
      <div dir="ltr" className="flex items-center gap-2">
        <span
          className={clsx(
            'flex min-w-0 flex-1 items-center gap-2 rounded-md bg-bg px-3 ring-inset',
            error ? 'ring-2 ring-error' : 'ring-1 ring-divider-strong focus-within:ring-2 focus-within:ring-focus-ring',
          )}
        >
          <input
            inputMode="numeric"
            aria-label={`${label} · MHz`}
            aria-invalid={error ? true : undefined}
            value={value.mhz}
            onChange={(event) => onChange({ ...value, mhz: event.target.value.replace(/[^0-9]/g, '') })}
            className="text-body min-w-0 flex-1 bg-transparent py-2 font-mono tabular-nums text-text-primary outline-none"
          />
          <span aria-hidden="true" className="text-micro font-mono text-text-tertiary">
            MHz
          </span>
        </span>

        <div role="radiogroup" aria-label={`${label} · polarization`} className="flex flex-none gap-1 rounded-lg bg-bg p-1">
          {POLARIZATIONS.map((pol) => (
            <button
              key={pol}
              type="button"
              role="radio"
              aria-checked={value.pol === pol}
              dir="ltr"
              onClick={() => onChange({ ...value, pol })}
              className={clsx(
                'text-micro size-8 rounded-sm font-mono font-semibold',
                value.pol === pol ? 'bg-text-primary text-text-on-inverse' : 'text-text-secondary hover:bg-surface-2',
                focusRing,
              )}
            >
              {pol}
            </button>
          ))}
        </div>

        <span className="flex min-w-0 flex-1 items-center gap-2 rounded-md bg-bg px-3 ring-1 ring-inset ring-divider-strong focus-within:ring-2 focus-within:ring-focus-ring">
          <input
            inputMode="numeric"
            aria-label={`${label} · symbol rate`}
            value={value.sr}
            onChange={(event) => onChange({ ...value, sr: event.target.value.replace(/[^0-9]/g, '') })}
            className="text-body min-w-0 flex-1 bg-transparent py-2 font-mono tabular-nums text-text-primary outline-none"
          />
          <span aria-hidden="true" className="text-micro font-mono text-text-tertiary">
            SR
          </span>
        </span>
      </div>
      {error ? <span className="text-caption text-error">{error}</span> : null}
      {hint ? <span className="text-caption text-text-tertiary">{hint}</span> : null}
    </fieldset>
  );
}
