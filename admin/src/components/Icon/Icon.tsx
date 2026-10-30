import { cva, type VariantProps } from 'class-variance-authority';
import { createElement, type ReactElement } from 'react';

import { icons, type IconName } from './icons';

const iconStyles = cva('inline-block shrink-0', {
  variants: {
    size: {
      sm: 'size-3',
      md: 'size-4',
      lg: 'size-5',
      xl: 'size-6',
    },
  },
  defaultVariants: { size: 'md' },
});

interface IconProps extends VariantProps<typeof iconStyles> {
  name: IconName;
  className?: string;
  /** An accessible name. Without one the icon is decorative and hidden from assistive tech. */
  label?: string;
}

/** The design package's line icons (madar-design app.css `.ic .i-<name>`), drawn in currentColor. */
export function Icon({ name, size, className, label }: IconProps): ReactElement {
  const icon = icons[name];
  const a11y = label ? { role: 'img', 'aria-label': label } : { 'aria-hidden': true };

  return (
    <svg
      viewBox="0 0 24 24"
      fill={icon.filled ? 'currentColor' : 'none'}
      stroke={icon.filled ? 'none' : 'currentColor'}
      strokeWidth={icon.strokeWidth ?? '1.7'}
      strokeLinecap="round"
      strokeLinejoin="round"
      focusable="false"
      className={iconStyles({ size, className })}
      {...a11y}
    >
      {icon.children.map(([tag, attrs], index) => createElement(tag, { key: index, ...attrs }))}
    </svg>
  );
}

export type { IconName };
