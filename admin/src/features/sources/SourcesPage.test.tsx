import { screen, waitFor, within } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { HttpResponse, http as mswHttp } from 'msw';
import type { ReactElement, ReactNode } from 'react';
import { Route, Routes } from 'react-router-dom';
import { describe, expect, it } from 'vitest';

import { ToastProvider } from '../../components/Toast/Toast';
import { renderRtl } from '../../test/render';
import { server } from '../../test/server';
import { SourceRunPage } from './SourceRunPage';
import { SourcesPage } from './SourcesPage';

const envelope = (data: unknown, meta: Record<string, unknown> = {}): Record<string, unknown> => ({
  success: true,
  data,
  error: null,
  meta,
});

const ysscores = {
  name: 'ysscores',
  kind: 'scraper',
  is_enabled: true,
  breaker: 'closed',
  breaker_opened_at: null,
  consecutive_failures: 0,
  paused: false,
  last_success_at: '2026-11-01T06:00:00Z',
  last_run: {
    id: 9123,
    status: 'succeeded',
    started_at: '2026-11-01T06:00:00Z',
    finished_at: '2026-11-01T06:02:00Z',
    items_found: 64,
    items_upserted: 12,
    http_errors: 0,
    error: null,
  },
  items_24h: [41, 0, 64, 58],
  error_rate_24h: 0.25,
  running: false,
};

const livesoccertv = {
  ...ysscores,
  name: 'livesoccertv',
  running: true,
  breaker: 'open',
  paused: true,
  error_rate_24h: 0.8,
};

const runs = [
  {
    id: 9123,
    status: 'succeeded',
    started_at: '2026-11-01T06:00:00Z',
    finished_at: '2026-11-01T06:02:00Z',
    items_found: 64,
    items_upserted: 12,
    http_errors: 0,
    error: null,
  },
  {
    id: 9122,
    status: 'failed',
    started_at: '2026-11-01T05:00:00Z',
    finished_at: '2026-11-01T05:01:00Z',
    items_found: 0,
    items_upserted: 0,
    http_errors: 2,
    error: 'timeout',
  },
];

const runDetail = {
  ...runs[0],
  raw_path: 'ysscores/2026-11-01/run.json',
  log: { unmatched_matches: ['الأهلي × الزمالك'], placeholders_created: ['Al Kass Two HD'], skipped_channels: 7, errors: [] },
  log_available: true,
};

const runLinks: URL[] = [];

function serve(): void {
  runLinks.length = 0;
  server.use(
    mswHttp.get('*/admin/api/sources', () => HttpResponse.json(envelope([ysscores, livesoccertv]))),
    mswHttp.get('*/admin/api/sources/:name/runs', ({ request, params }) => {
      runLinks.push(new URL(request.url));
      const isSecondPage = new URL(request.url).searchParams.get('cursor') === 'next-1';
      return HttpResponse.json(
        envelope(isSecondPage ? [runs[1]] : [runs[0]], { next_cursor: isSecondPage ? null : 'next-1', name: params['name'] }),
      );
    }),
  );
}

function Providers({ children }: { children: ReactNode }): ReactElement {
  return <ToastProvider>{children}</ToastProvider>;
}

function renderPage() {
  serve();
  return renderRtl(<SourcesPage />, { wrapper: Providers });
}

describe('SourcesPage (A13)', () => {
  it('shows a card per source with its health, and only «تشغيل الآن» while it is not running', async () => {
    renderPage();

    const healthy = await screen.findByTestId('source-ysscores');
    expect(within(healthy).getByText('سليم')).toBeInTheDocument();
    expect(within(healthy).getByRole('button', { name: 'تشغيل الآن' })).toBeEnabled();

    const broken = screen.getByTestId('source-livesoccertv');
    expect(within(broken).getByText('الدائرة مفتوحة')).toBeInTheDocument();
    // A source whose lock is held cannot be started again from here.
    expect(within(broken).getByRole('button', { name: 'جارٍ التشغيل' })).toBeDisabled();
    expect(within(broken).getByRole('button', { name: 'استئناف' })).toBeInTheDocument();
  });

  it('runs a source and reports a run already in progress', async () => {
    let posted = 0;
    renderPage();
    const card = await screen.findByTestId('source-ysscores');

    server.use(
      mswHttp.post('*/admin/api/sources/:name/run', () => {
        posted += 1;
        return HttpResponse.json(envelope({ queued: true }), { status: 202 });
      }),
    );
    await userEvent.click(within(card).getByRole('button', { name: 'تشغيل الآن' }));
    await waitFor(() => expect(posted).toBe(1));

    server.use(
      mswHttp.post('*/admin/api/sources/:name/run', () =>
        HttpResponse.json(
          { success: false, data: null, error: { code: 'run_in_progress', message: 'x' }, meta: {} },
          { status: 409 },
        ),
      ),
    );
    await userEvent.click(within(card).getByRole('button', { name: 'تشغيل الآن' }));
    expect(await screen.findByText(/هذا المصدر يعمل الآن/)).toBeInTheDocument();
  });

  it('lists the selected source runs and pages with the cursor', async () => {
    renderPage();
    await screen.findByTestId('source-ysscores');

    expect(await screen.findByTestId('run-9123')).toBeInTheDocument();
    expect(screen.getByTestId('run-9123')).toHaveTextContent('64');
    expect(runLinks.at(-1)?.searchParams.get('cursor')).toBeNull();

    await userEvent.click(screen.getByRole('button', { name: 'المزيد' }));
    expect(await screen.findByTestId('run-9122')).toBeInTheDocument();
    expect(runLinks.at(-1)?.searchParams.get('cursor')).toBe('next-1');
  });
});

describe('SourceRunPage (A13 run detail)', () => {
  it('shows the run counts and the log the importer kept', async () => {
    server.use(mswHttp.get('*/admin/api/import-runs/:id', () => HttpResponse.json(envelope(runDetail))));

    renderRtl(
      <Routes>
        <Route path="/import-runs/:id" element={<SourceRunPage />} />
      </Routes>,
      { route: '/import-runs/9123', wrapper: Providers },
    );

    expect(await screen.findByText('تفاصيل التشغيلة')).toBeInTheDocument();
    expect(screen.getByText('العناصر الموجودة')).toBeInTheDocument();
    expect(screen.getByText('الأهلي × الزمالك')).toBeInTheDocument();
    expect(screen.getByText('Al Kass Two HD')).toBeInTheDocument();
    expect(screen.getByText('7')).toBeInTheDocument();
  });
});
