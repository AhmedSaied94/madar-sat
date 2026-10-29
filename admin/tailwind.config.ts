import type { Config } from 'tailwindcss';

import { colors, layout, radius, shadows, spacing } from './src/styles/tokens';

// Every theme value comes from the design tokens (constitution IV, research R15).
// Colors and shadows point at the CSS variables, so `data-theme` switches the theme at runtime.
const toVars = (names: readonly string[]): Record<string, string> =>
  Object.fromEntries(names.map((name) => [name, `var(--${name})`]));

const withoutPrefix = (values: Record<string, string>, prefix: string): Record<string, string> =>
  Object.fromEntries(Object.entries(values).map(([name, value]) => [name.replace(prefix, ''), value]));

const space = { 0: '0', ...withoutPrefix(spacing, 'space-'), ...layout };

export default {
  content: ['./index.html', './src/**/*.{ts,tsx}'],
  theme: {
    colors: {
      transparent: 'transparent',
      current: 'currentColor',
      ...toVars(Object.keys(colors.dark)),
    },
    spacing: space,
    maxWidth: { none: 'none', full: '100%', ...space },
    borderRadius: { none: '0', ...withoutPrefix(radius, 'radius-') },
    // shadow-raised, shadow-subtle, shadow-readout-glow
    boxShadow: { none: 'none', ...withoutPrefix(toVars(Object.keys(shadows.dark)), 'shadow-') },
    fontFamily: {
      display: 'var(--font-display)',
      sans: 'var(--font-sans)',
      mono: 'var(--font-mono)',
    },
    // Type sizes come only from the tokens.css text styles (`heading-1`, `text-body`, ...).
    fontSize: {},
    extend: {
      keyframes: {
        'toast-in': {
          from: { opacity: '0', transform: 'translateY(var(--space-2))' },
          to: { opacity: '1', transform: 'none' },
        },
      },
      // Used only behind `motion-safe:`, so reduced motion gets no animation.
      animation: { 'toast-in': 'toast-in 160ms ease-out' },
    },
  },
  plugins: [],
} satisfies Config;
