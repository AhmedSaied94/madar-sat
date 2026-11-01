import { render, screen } from '@testing-library/react';
import { describe, expect, it } from 'vitest';

import { colors } from '../../styles/tokens';
import { FrequencyReadout } from './FrequencyReadout';

// A-R1-8: the readout is a dark well with cyan mono digits, LTR, in BOTH themes. jsdom cannot resolve
// a CSS variable, so the test asserts the token classes the well is built from and that the token
// itself stays dark in the light theme.

const luminance = (hex: string): number => {
  const value = hex.replace('#', '');
  const channels = [0, 2, 4].map((offset) => Number.parseInt(value.slice(offset, offset + 2), 16) / 255);
  const [r, g, b] = channels.map((channel) => (channel <= 0.040_45 ? channel / 12.92 : ((channel + 0.055) / 1.055) ** 2.4));
  return 0.2126 * (r ?? 0) + 0.7152 * (g ?? 0) + 0.0722 * (b ?? 0);
};

describe('FrequencyReadout', () => {
  it('keeps the dark, LTR readout well in both themes', () => {
    for (const theme of ['dark', 'light'] as const) {
      document.documentElement.dataset['theme'] = theme;
      const { unmount } = render(
        <FrequencyReadout frequency={{ mhz: 11843, pol: 'H', sr: 27500 }} />);

      const well = screen.getByTestId('frequency-readout');
      expect(well).toHaveAttribute('dir', 'ltr');
      expect(well).toHaveClass('bg-readout-bg', 'text-readout', 'ring-readout-line', 'readout');
      // The old ad-hoc pill: a pale chip with dark text in the dark theme.
      expect(well).not.toHaveClass('bg-text-primary');
      expect(well).not.toHaveClass('text-text-on-inverse');

      unmount();
    }

    // The well is dark in both themes, so "always dark" is a property of the token, not of the theme.
    for (const theme of ['dark', 'light'] as const) {
      expect(luminance(colors[theme]['readout-bg'])).toBeLessThan(0.1);
    }
  });

  it('reads the tuning out to a screen reader, digits unchanged', () => {
    render(<FrequencyReadout frequency={{ mhz: 11843, pol: 'H', sr: 27500 }} />);

    expect(screen.getByRole('img', { name: 'التردد 11843، أفقي، معدل الترميز 27500' })).toBeInTheDocument();
    expect(screen.getByText('11843')).toBeInTheDocument();
    expect(screen.getByText('27500')).toBeInTheDocument();
    expect(screen.getByText('H')).toBeInTheDocument();
  });

  it('shows a bare value, such as an orbital position, in the same well', () => {
    render(<FrequencyReadout text="7.0W" size="lg" />);

    const well = screen.getByTestId('frequency-readout');
    expect(well).toHaveAttribute('data-size', 'lg');
    expect(well).toHaveClass('readout-lg');
    expect(well).toHaveTextContent('7.0W');
  });
});
