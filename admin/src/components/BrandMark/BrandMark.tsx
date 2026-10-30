import { cva, type VariantProps } from 'class-variance-authority';
import type { ReactElement } from 'react';

import { brand } from '../../i18n/ar';

const markStyles = cva('shrink-0', {
  variants: {
    size: {
      md: 'size-8',
      lg: 'size-12',
    },
  },
  defaultVariants: { size: 'md' },
});

interface BrandMarkProps extends VariantProps<typeof markStyles> {
  className?: string;
}

/** The orbit mark (madar-design `.mk`): a dark tile with a volt ring, planet and satellite. */
export function BrandMark({ size, className }: BrandMarkProps): ReactElement {
  return (
    <svg viewBox="0 0 32 32" aria-hidden="true" focusable="false" className={markStyles({ size, className })}>
      <rect width="32" height="32" rx="9" className="fill-on-accent" />
      <ellipse cx="16" cy="16" rx="12" ry="5" fill="none" strokeWidth="1.8" transform="rotate(-28 16 16)" className="stroke-accent" />
      <circle cx="16" cy="16" r="5.2" className="fill-accent" />
      <circle cx="26.6" cy="10.4" r="2.1" className="fill-accent" />
    </svg>
  );
}

interface BrandLockupProps {
  size?: 'md' | 'lg';
}

/** The «مدار» wordmark with the ADMIN tag, as drawn on the admin boards. */
export function BrandLockup({ size = 'md' }: BrandLockupProps): ReactElement {
  return (
    <div className="flex items-center gap-3">
      <BrandMark size={size} />
      <div className="flex flex-col gap-1">
        <span className="heading-2 font-extrabold leading-none">{brand.wordmark}</span>
        <span dir="ltr" className="text-micro text-end font-mono tracking-widest text-text-tertiary">
          {brand.tag}
        </span>
      </div>
    </div>
  );
}
