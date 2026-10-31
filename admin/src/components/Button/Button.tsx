import { cva } from 'class-variance-authority';
import type { ButtonHTMLAttributes, ReactElement } from 'react';

import { focusRing } from '../focus';

// Admin actions in five emphasis levels (Button README): one primary per screen, danger for deletes.
// Every size is a 48 px element: the two smaller ones clip a 40 px and a 32 px fill inside a
// transparent band of border, because `border-box` puts the border inside the height (A-R2-3).
export type ButtonVariant = 'primary' | 'secondary' | 'outline' | 'ghost' | 'danger';
export type ButtonSize = 'default' | 'sm' | 'xs';

const buttonStyles = cva(
  `text-label inline-flex flex-none items-center justify-center gap-2 whitespace-nowrap rounded-lg font-semibold transition-colors disabled:cursor-not-allowed disabled:bg-surface-3 disabled:text-text-disabled ${focusRing}`,
  {
    variants: {
      variant: {
        primary: 'bg-accent text-on-accent hover:brightness-105 active:brightness-95',
        secondary: 'bg-surface-2 text-text-primary hover:bg-surface-3 active:bg-surface-3',
        outline: 'bg-transparent text-text-primary ring-1 ring-inset ring-divider-strong hover:bg-surface-2 active:bg-surface-3',
        ghost: 'bg-transparent text-accent-text hover:bg-accent-container active:bg-surface-3',
        danger: 'bg-error-container text-error hover:brightness-110 active:brightness-90',
      },
      size: {
        default: 'h-12 px-5',
        // 48 − 2 × 4 = a 40 px fill; 48 − 2 × 8 = a 32 px fill. The target stays 48 px either way.
        sm: 'h-12 border-y-4 border-transparent bg-clip-padding px-3',
        xs: 'h-12 border-y-8 border-transparent bg-clip-padding px-2',
      },
      iconOnly: {
        true: 'w-12 px-0',
        false: '',
      },
      block: {
        true: 'w-full',
        false: '',
      },
    },
    defaultVariants: { variant: 'primary', size: 'default', iconOnly: false, block: false },
  },
);

export interface ButtonProps extends Omit<ButtonHTMLAttributes<HTMLButtonElement>, 'className'> {
  variant?: ButtonVariant;
  size?: ButtonSize;
  /** Busy: spinner, `aria-busy`, and no second submit. */
  loading?: boolean;
  /** The present-tense verb shown while busy («جارٍ الحفظ»); falls back to the label. */
  loadingLabel?: string;
  /** A square button whose label is its `aria-label`. */
  iconOnly?: boolean;
  block?: boolean;
}

export function Button({
  variant = 'primary',
  size = 'default',
  loading = false,
  loadingLabel,
  iconOnly = false,
  block = false,
  disabled = false,
  children,
  type = 'button',
  ...props
}: ButtonProps): ReactElement {
  return (
    <button
      {...props}
      type={type}
      disabled={disabled || loading}
      aria-busy={loading || undefined}
      data-variant={variant}
      data-size={size}
      className={buttonStyles({ variant, size, iconOnly, block })}
    >
      {loading ? (
        <span
          data-spinner
          aria-hidden="true"
          className="size-3 flex-none rounded-pill border-2 border-current border-e-transparent motion-safe:animate-spin"
        />
      ) : null}
      {loading ? (loadingLabel ?? children) : children}
    </button>
  );
}
