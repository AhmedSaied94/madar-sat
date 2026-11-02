import { screen } from '@testing-library/react';
import { describe, expect, it } from 'vitest';

import { renderRtl } from '../../test/render';
import { KpiCard } from './KpiCard';

describe('KpiCard', () => {
  it('shows the label with its glyph, the figure and the context', () => {
    renderRtl(<KpiCard icon="tv" label="بدون قنوات" value="41" context="85 من 1,469" />);

    const card = screen.getByTestId('kpi-card');
    expect(card).toHaveTextContent('بدون قنوات');
    expect(card).toHaveTextContent('41');
    expect(card).toHaveTextContent('85 من 1,469');
    expect(screen.getByRole('img', { name: 'بدون قنوات' })).toBeInTheDocument();
  });

  it('gives the figure the attention tone only when the work needs it', () => {
    renderRtl(
      <>
        <KpiCard icon="tv" label="بدون قنوات" value="41" context="من 85" tone="attention" />
        <KpiCard icon="ball" label="مباريات اليوم" value="85" context="16 بطولة" />
      </>,
    );

    const [attention, calm] = screen.getAllByTestId('kpi-value');
    expect(attention).toHaveClass('text-postponed');
    expect(calm).toHaveClass('text-text-primary');
    expect(attention).toHaveClass('tabular-nums');
  });

  it('draws the progress bar with its real value', () => {
    renderRtl(
      <KpiCard icon="trophy" label="تغطية البطولات" value="94%" context="قبل ساعتين" progress={{ value: 94, max: 100 }} />,
    );

    const bar = screen.getByRole('progressbar', { name: 'تغطية البطولات' });
    expect(bar).toHaveAttribute('aria-valuenow', '94');
    expect(bar).toHaveAttribute('aria-valuemax', '100');
    expect(bar).toHaveAttribute('aria-valuetext', '94 من 100');
  });

  it('links to the filtered list it counts', () => {
    renderRtl(<KpiCard icon="tv" label="بدون قنوات" value="41" context="من 85" href="/matches?missing_channels=true" />);

    expect(screen.getByRole('link', { name: /بدون قنوات/ })).toHaveAttribute('href', '/matches?missing_channels=true');
  });

  it('is not a link when it counts nothing that opens anywhere', () => {
    renderRtl(<KpiCard icon="ball" label="مباريات اليوم" value="85" context="16 بطولة" />);

    expect(screen.queryByRole('link')).not.toBeInTheDocument();
  });
});
