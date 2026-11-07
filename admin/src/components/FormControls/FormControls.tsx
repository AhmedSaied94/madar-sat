import { useId, type ReactElement } from 'react';
import { clsx } from 'clsx';

import { focusRing } from '../focus';

// The two controls A15 and A17 need and the admin didn't have (contract admin-screens, top): a labelled
// native select, so a keyboard and a phone get their own picker, and a segmented control for a choice of
// two or three — «الآن / مجدول» on the composer. Built once under `FormControls`.

interface SelectProps<Value extends string> {
  label: string;
  value: Value;
  options: readonly { value: Value; label: string }[];
  onChange: (value: Value) => void;
  disabled?: boolean;
}

export function Select<Value extends string>({
  label,
  value,
  options,
  onChange,
  disabled = false,
}: SelectProps<Value>): ReactElement {
  const id = useId();
  return (
    <div className="flex min-w-0 flex-col gap-2">
      <label htmlFor={id} className="text-caption font-semibold text-text-secondary">
        {label}
      </label>
      <select
        id={id}
        aria-label={label}
        value={value}
        disabled={disabled}
        onChange={(event) => onChange(event.target.value as Value)}
        className={clsx(
          'text-label h-8 min-w-0 rounded-md bg-bg px-3 text-text-primary ring-1 ring-inset ring-divider-strong disabled:cursor-not-allowed disabled:opacity-50',
          focusRing,
        )}
      >
        {options.map((option) => (
          <option key={option.value} value={option.value}>
            {option.label}
          </option>
        ))}
      </select>
    </div>
  );
}

interface SegmentedProps<Value extends string> {
  label: string;
  value: Value;
  options: readonly { value: Value; label: string }[];
  onChange: (value: Value) => void;
}

/** A two-or-three-way choice, drawn as one bar. Each button says whether it is the current one. */
export function Segmented<Value extends string>({
  label,
  value,
  options,
  onChange,
}: SegmentedProps<Value>): ReactElement {
  return (
    <div role="group" aria-label={label} className="inline-flex flex-none gap-1 rounded-lg bg-bg p-1 ring-1 ring-inset ring-divider">
      {options.map((option) => (
        <button
          key={option.value}
          type="button"
          aria-pressed={option.value === value}
          onClick={() => onChange(option.value)}
          className={clsx(
            'text-label h-8 rounded-md px-3 font-semibold',
            option.value === value ? 'bg-accent-container text-accent-text' : 'text-text-secondary hover:bg-surface-2',
            focusRing,
          )}
        >
          {option.label}
        </button>
      ))}
    </div>
  );
}

/** Visible copy that counts what the field holds, as the board's «36/65». */
export function Counter({ length, max }: { length: number; max: number }): ReactElement {
  return (
    <span dir="ltr" className="text-micro tabular-nums text-text-tertiary">
      {`${length}/${max}`}
    </span>
  );
}
