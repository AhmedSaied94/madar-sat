import { screen, waitFor, within } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { HttpResponse, http as mswHttp } from 'msw';
import type { ReactElement, ReactNode } from 'react';
import { Route, Routes } from 'react-router-dom';
import { describe, expect, it } from 'vitest';

import { ToastProvider } from '../../components/Toast/Toast';
import { renderRtl } from '../../test/render';
import { server } from '../../test/server';
import { RAW_POLL_MS, RAW_POLL_TRIES, SourceRunPage, rawPollInterval } from './SourceRunPage';
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
  live: null,
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
  pages: 1,
  worker: null,
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

// --- D5: the Live poller card and the raw page (A13) ------------------------------------------

const livePoller = {
  ...ysscores,
  name: 'live_poller',
  kind: 'live',
  error_rate_24h: 0.01,
  items_24h: [6, 6, 5, 6],
  live: {
    matches_live: 6,
    error_share: 0.01,
    sources: [
      { name: 'filgoal', state: 'ok' },
      { name: 'yallakora', state: 'failing' },
    ],
  },
};

function serveLive(): void {
  server.use(
    mswHttp.get('*/admin/api/sources', () => HttpResponse.json(envelope([ysscores, livePoller]))),
    mswHttp.get('*/admin/api/sources/:name/runs', () => HttpResponse.json(envelope([], { next_cursor: null }))),
  );
}

describe('SourcesPage · Live poller card (A13)', () => {
  it('shows what the feed is driving, each reader’s state and the error share, and no run button', async () => {
    serveLive();
    renderRtl(<SourcesPage />, { wrapper: Providers });

    const card = await screen.findByTestId('source-live_poller');
    expect(within(card).getByText('Live poller')).toBeInTheDocument();
    expect(within(card).getByText('6 مباشرة')).toBeInTheDocument();
    expect(within(card).getByText('1%')).toBeInTheDocument();
    expect(within(card).getByText('filgoal')).toBeInTheDocument();
    expect(within(card).getByText('yallakora')).toBeInTheDocument();
    expect(card.querySelector('[data-state="ok"]')).toHaveTextContent('سليم');
    expect(card.querySelector('[data-state="failing"]')).toHaveTextContent('متعثر');

    // A poller runs from the scheduler: nothing to start by hand, but it can still be paused.
    expect(within(card).queryByRole('button', { name: 'تشغيل الآن' })).not.toBeInTheDocument();
    expect(within(card).getByRole('button', { name: 'إيقاف' })).toBeInTheDocument();
  });

  it('pauses and resumes the poller like any other source', async () => {
    let paused: string | null = null;
    serveLive();
    renderRtl(<SourcesPage />, { wrapper: Providers });
    const card = await screen.findByTestId('source-live_poller');

    server.use(
      mswHttp.post('*/admin/api/sources/:name/pause', ({ params }) => {
        paused = String(params['name']);
        return HttpResponse.json(envelope(null));
      }),
    );

    await userEvent.click(within(card).getByRole('button', { name: 'إيقاف' }));
    await waitFor(() => expect(paused).toBe('live_poller'));
  });
});

const runWithPages = {
  ...runDetail,
  pages: 3,
  worker: 'worker-scrape@vps-2',
  log: {
    kind: 'scrape',
    counts: { items_found: 62, items_upserted: 12, http_errors: 0, targets: 3 },
    unmatched: { count: 1, items: ['الأهلي × الزمالك'] },
    unresolved: { count: 2, items: [] },
    placeholders_created: ['Al Kass Two HD'],
    skipped: { count: 7, items: [] },
  },
};

const rawText = '<html><body><script>window.stolen=1</script><img src=x onerror="window.stolen=2"></body></html>';

function renderRun(): void {
  renderRtl(
    <Routes>
      <Route path="/import-runs/:id" element={<SourceRunPage />} />
    </Routes>,
    { route: '/import-runs/9123', wrapper: Providers },
  );
}

describe('SourceRunPage · stages and raw page (A13)', () => {
  it('shows the pipeline stages from the log, and «لم يبدأ» for one it does not record', async () => {
    server.use(mswHttp.get('*/admin/api/import-runs/:id', () => HttpResponse.json(envelope(runWithPages))));
    renderRun();

    const stages = await screen.findByTestId('run-stages');
    expect(within(stages).getByText('fetch')).toBeInTheDocument();
    expect(within(stages).getByText('3 صفحات مطلوبة')).toBeInTheDocument();
    expect(within(stages).getByText('62 عنصر')).toBeInTheDocument();
    expect(within(stages).getByText('12 محفوظ')).toBeInTheDocument();
    expect(within(stages).getByText('2 غير محلول')).toBeInTheDocument();
    expect(within(stages).getAllByText('لم يبدأ')).toHaveLength(1);
  });

  it('polls the raw page while it is pending, then shows it as inert text and a URL that is not a link', async () => {
    let calls = 0;
    const url = 'https://www.yallakora.com/matches?date=2026-11-04';
    server.use(
      mswHttp.get('*/admin/api/import-runs/:id', () =>
        HttpResponse.json(envelope(runWithPages), { headers: { ETag: '"run-9123"' } }),
      ),
      mswHttp.get('*/admin/api/import-runs/:id/raw', () => {
        calls += 1;
        const body =
          calls < 3
            ? { state: 'pending', page: 0, pages: 3, url: null, content_type: null, text: null, truncated: false }
            : {
                state: 'ready',
                page: 0,
                pages: 3,
                url,
                content_type: 'text/html',
                text: rawText,
                truncated: true,
              };
        return HttpResponse.json(envelope(body), { headers: { ETag: `"raw-${calls}"` } });
      }),
    );
    renderRun();

    await userEvent.click(await screen.findByRole('button', { name: 'الصفحة الخام' }));

    expect(await screen.findByText('جارٍ تحضير الصفحة…')).toBeInTheDocument();
    const page = await screen.findByTestId('raw-page', undefined, { timeout: 8000 });
    expect(await within(page).findByText(rawText, { exact: false }, { timeout: 4000 })).toBeInTheDocument();
    expect(within(page).getByText('مختصرة')).toBeInTheDocument();
    expect(calls).toBeGreaterThanOrEqual(3);
    expect(page.querySelector('script')).toBeNull();
    expect(page.querySelector('img')).toBeNull();

    const address = within(page).getByText(url);
    expect(address).toHaveAttribute('dir', 'ltr');
    expect(within(page).queryByRole('link', { name: url })).not.toBeInTheDocument();
  });

  it('says so when the saved page is gone', async () => {
    server.use(
      mswHttp.get('*/admin/api/import-runs/:id', () => HttpResponse.json(envelope(runWithPages))),
      mswHttp.get('*/admin/api/import-runs/:id/raw', () =>
        HttpResponse.json(
          envelope({ state: 'gone', page: 0, pages: 3, url: null, content_type: null, text: null, truncated: false }),
        ),
      ),
    );
    renderRun();

    await userEvent.click(await screen.findByRole('button', { name: 'الصفحة الخام' }));
    expect(await screen.findByText('لم تُحفظ هذه الصفحة أو حُذفت')).toBeInTheDocument();
  });
});


describe('rawPollInterval (A13 raw page)', () => {
  it('keeps asking while the page is pending, up to the ten-second window', () => {
    expect(rawPollInterval('pending', 0)).toBe(RAW_POLL_MS);
    expect(rawPollInterval('pending', RAW_POLL_TRIES - 1)).toBe(RAW_POLL_MS);
    expect(rawPollInterval('pending', RAW_POLL_TRIES)).toBe(false);
  });

  it('stops on a page that arrived or is gone, and before the first answer', () => {
    expect(rawPollInterval('ready', 1)).toBe(false);
    expect(rawPollInterval('gone', 1)).toBe(false);
    expect(rawPollInterval(undefined, 0)).toBe(false);
  });
});
