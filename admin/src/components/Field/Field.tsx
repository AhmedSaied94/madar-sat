import { clsx } from 'clsx';
import { cva } from 'class-variance-authority';
import { forwardRef, useId, type InputHTMLAttributes, type ReactNode } from 'react';

import { field } from '../../i18n/ar';
import { Icon } from '../Icon/Icon';

// A labelled admin input (FormField README): default · focus · error · locked · disabled.
type FieldState = 'default' | 'error' | 'locked' | 'disabled';

const controlStyles = cva('flex min-w-0 items-center gap-2 rounded-md px-3 ring-inset', {
  variants: {
    state: {
      default: 'bg-bg ring-1 ring-divider-strong focus-within:ring-2 focus-within:ring-focus-ring',
      error: 'bg-bg ring-2 ring-error',
      locked: 'bg-postponed-container ring-1 ring-postponed focus-within:ring-2 focus-within:ring-focus-ring',
      disabled: 'bg-bg opacity-50 ring-1 ring-divider-strong',
    },
  },
});

export interface FieldProps extends Omit<InputHTMLAttributes<HTMLInputElement>, 'className' | 'children'> {
  label: string;
  hint?: string | undefined;
  /** Shown under the input. Validation copy says what is valid. */
  error?: string | undefined;
  /** The error state without a message under the field (the message is shown elsewhere). */
  invalid?: boolean;
  /** An editor's value the importer will not overwrite. */
  locked?: boolean;
  leading?: ReactNode;
  trailing?: ReactNode;
  /** LTR island for emails, frequencies and codes. */
  ltr?: boolean;
  mono?: boolean;
}

export const Field = forwardRef<HTMLInputElement, FieldProps>(function Field(
  { label, hint, error, invalid = false, locked = false, leading, trailing, ltr = false, mono = false, id, disabled, ...inputProps },
  ref,
) {
  const generatedId = useId();
  const inputId = id ?? generatedId;
  const hintText = hint ?? (locked ? field.lockedHint : undefined);
  const hintId = hintText ? `${inputId}-hint` : undefined;
  const errorId = error ? `${inputId}-error` : undefined;
  const describedBy = [hintId, errorId].filter(Boolean).join(' ') || undefined;
  const isInvalid = Boolean(error) || invalid;
  const state: FieldState = disabled ? 'disabled' : isInvalid ? 'error' : locked ? 'locked' : 'default';

  return (
    <div className="flex min-w-0 flex-col gap-2">
      <label htmlFor={inputId} className="text-caption flex items-center gap-2 font-semibold text-text-secondary">
        {locked ? (
          <span data-testid="field-lock" className="inline-flex text-postponed">
            <Icon name="lock" size="sm" label={field.lockedLabel} />
          </span>
        ) : null}
        {label}
      </label>
      <div data-testid="field-control" data-state={state} className={controlStyles({ state })}>
        {leading}
        <input
          ref={ref}
          id={inputId}
          disabled={disabled}
          aria-invalid={isInvalid || undefined}
          aria-describedby={describedBy}
          dir={ltr ? 'ltr' : undefined}
          className={clsx(
            'text-body min-w-0 flex-1 bg-transparent py-2 text-text-primary outline-none placeholder:text-text-tertiary disabled:cursor-not-allowed',
            ltr && 'text-start',
            mono && 'font-mono',
          )}
          {...inputProps}
        />
        {trailing}
      </div>
      {hintText ? (
        <span id={hintId} className="text-caption text-text-tertiary">
          {hintText}
        </span>
      ) : null}
      {error ? (
        <span id={errorId} className="text-caption text-error">
          {error}
        </span>
      ) : null}
    </div>
  );
});
