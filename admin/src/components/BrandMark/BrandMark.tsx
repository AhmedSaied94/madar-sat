import { cva, type VariantProps } from 'class-variance-authority';
import { useId, type ReactElement } from 'react';

import { brand } from '../../i18n/ar';

const NEAR_HALF_OF_RING = 'M5.616 21.518A11.84 2.86 -28 0 0 26.524 10.402';

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

/**
 * The brand mark (madar-design `components/Logo/mark.svg`) on its ink tile. `data-theme="dark"`
 * keeps the planet light in both themes, because the tile is ink in both.
 */
export function BrandMark({ size, className }: BrandMarkProps): ReactElement {
  const bandId = useId();
  return (
    <svg
      viewBox="0 0 32 32"
      data-theme="dark"
      aria-hidden="true"
      focusable="false"
      className={markStyles({ size, className })}
    >
      <defs>
        <mask id={bandId} maskUnits="userSpaceOnUse" x="0" y="0" width="32" height="32">
          {/* Mask luminance, never painted: white keeps the planet and black cuts the ring's band. */}
          <rect width="32" height="32" fill="white" />
          <path d={NEAR_HALF_OF_RING} fill="none" stroke="black" strokeWidth="3.08" />
        </mask>
      </defs>
      <rect width="32" height="32" rx="9" className="fill-on-accent" />
      <ellipse
        cx="16.07"
        cy="15.96"
        rx="11.84"
        ry="2.86"
        fill="none"
        strokeWidth="1.66"
        transform="rotate(-28 16.07 15.96)"
        className="stroke-accent"
      />
      <circle cx="16" cy="16" r="5.69" mask={`url(#${bandId})`} className="fill-text-primary" />
      <g transform="translate(26.47 7.43) rotate(-28)" className="fill-text-primary">
        <rect x="-1.07" y="-1.07" width="2.14" height="2.14" rx="0.5" />
        <rect x="-3.56" y="-0.59" width="1.9" height="1.18" rx="0.2" />
        <rect x="1.66" y="-0.59" width="1.9" height="1.18" rx="0.2" />
      </g>
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
