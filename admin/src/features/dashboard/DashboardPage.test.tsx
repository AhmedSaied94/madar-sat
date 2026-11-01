import { screen } from '@testing-library/react';
import { HttpResponse, http as mswHttp } from 'msw';
import type { ReactElement, ReactNode } from 'react';
import { describe, expect, it } from 'vitest';

import { ToastProvider } from '../../components/Toast/Toast';
import { cairoDay, cairoDayBounds } from '../../lib/cairoTime';
import { renderRtl } from '../../test/render';
import { server } from '../../test/server';
import { DashboardPage } from './DashboardPage';

const envelope = (data: unknown): Record<string, unknown> => ({ success: true, data, error: null, meta: {} });

const board = {
  missing_channels: [
    {
      competition: { id: 12, name: 'الدوري المصري الممتاز', priority: 3 },
      matches: [
        { id: 48213, kickoff_at: '2026-11-01T18:00:00Z', home: 'الأهلي', away: 'الزمالك' },
        { id: 48214, kickoff_at: '2026-11-01T15:00:00Z', home: 'البنك الأهلي', away: 'المصري' },
      ],
    },
  ],
  missing_channels_count: 2,
  placeholders_to_complete: 14,
  sources: [
    {
      name: 'ysscores',
      kind: 'scraper',
      is_enabled: true,
      breaker: 'closed',
      breaker_opened_at: null,
      consecutive_failures: 0,
      paused: false,
      last_success_at: '2026-11-01T06:00:00Z',
      last_run: null,
      items_24h: [1, 2],
      error_rate_24h: null,
      running: false,
    },
    {
      name: 'livesoccertv',
      kind: 'scraper',
      is_enabled: true,
      breaker: 'open',
      breaker_opened_at: '2026-11-01T05:00:00Z',
      consecutive_failures: 3,
      paused: true,
      last_success_at: null,
      last_run: null,
      items_24h: [],
      error_rate_24h: 1,
      running: false,
    },
  ],
  recent_changes: [
    {
      at: '2026-11-01T09:30:00Z',
      by: { kind: 'admin', name: 'سارة حسن' },
      entity: 'match',
      entity_id: 48213,
      action: 'update',
    },
    {
      at: '2026-11-01T08:00:00Z',
      by: { kind: 'source', name: 'livesoccertv' },
      entity: 'channel',
      entity_id: 501,
      action: 'create',
    },
  ],
};

const requests: URL[] = [];

function serve(): void {
  requests.length = 0;
  server.use(
    mswHttp.get('*/admin/api/dashboard', ({ request }) => {
      requests.push(new URL(request.url));
      return HttpResponse.json(envelope(board));
    }),
  );
}

function Providers({ children }: { children: ReactNode }): ReactElement {
  return <ToastProvider>{children}</ToastProvider>;
}

function renderPage() {
  serve();
  return renderRtl(<DashboardPage />, { wrapper: Providers });
}

describe('DashboardPage (A2)', () => {
  it('asks for the Cairo day and shows the three figures', async () => {
    renderPage();

    expect(await screen.findByRole('heading', { name: 'مباريات بلا قنوات', level: 2 })).toBeInTheDocument();
    const bounds = cairoDayBounds(cairoDay(new Date().toISOString()));
    expect(requests.at(-1)?.searchParams.get('from')).toBe(bounds.from);
    expect(requests.at(-1)?.searchParams.get('to')).toBe(bounds.to);

    const values = screen.getAllByTestId('kpi-value').map((node) => node.textContent);
    expect(values).toEqual(['2', '14', '50%']);
  });

  it('lists the matches without a channel by competition and opens their editor', async () => {
    renderPage();

    expect(await screen.findByText('الدوري المصري الممتاز')).toBeInTheDocument();
    const link = screen.getByRole('link', { name: /الأهلي × الزمالك/ });
    expect(link).toHaveAttribute('href', '/matches/48213');
    expect(screen.getByRole('link', { name: 'افتح المباريات' })).toBeInTheDocument();
  });

  it('shows each source with its health and where to manage it', async () => {
    renderPage();

    const healthy = await screen.findByTestId('dashboard-source-ysscores');
    expect(healthy).toHaveTextContent('سليم');
    const broken = screen.getByTestId('dashboard-source-livesoccertv');
    expect(broken).toHaveTextContent('الدائرة مفتوحة');
    expect(screen.getByRole('link', { name: 'افتح المصادر' })).toHaveAttribute('href', '/sources');
  });

  it('writes the last changes as one Arabic line each', async () => {
    renderPage();

    expect(await screen.findByText('سارة حسن عدّل مباراة')).toBeInTheDocument();
    expect(screen.getByText('مصدر livesoccertv أضاف قناة')).toBeInTheDocument();
  });
});
