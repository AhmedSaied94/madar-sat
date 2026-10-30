import { screen, waitFor, within } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { HttpResponse, http as mswHttp } from 'msw';
import type { ReactElement, ReactNode } from 'react';
import { describe, expect, it } from 'vitest';

import { ToastProvider } from '../../components/Toast/Toast';
import { SessionProvider } from '../auth/session';
import { cairoDay, cairoDayBounds, shiftCairoDay } from '../../lib/cairoTime';
import { renderRtl } from '../../test/render';
import { server } from '../../test/server';
import { MatchesPage } from './MatchesPage';

const envelope = (data: unknown, meta: Record<string, unknown> = {}): Record<string, unknown> => ({
  success: true,
  data,
  error: null,
  meta,
});

const team = (name: string) => ({ id: 1, name, logo: null });

const rows = [
  {
    id: 48213,
    match_date: '2026-10-31',
    kickoff_at: '2026-10-31T18:00:00Z',
    time_tbd: false,
    status: 'scheduled',
    estimated: false,
    score: null,
    competition: { id: 12, name: 'الدوري المصري الممتاز', logo: null, priority: 3, stage: 'الجولة 9' },
    home: team('الأهلي'),
    away: team('الزمالك'),
    channel_count: 14,
    broadcaster_count: 0,
    missing_channels: false,
    commentator: { id: 7, name: 'مدحت شلبي' },
    sources: ['ysscores', 'legacy'],
    locked: true,
  },
  {
    id: 48214,
    match_date: '2026-10-31',
    kickoff_at: '2026-10-31T15:00:00Z',
    time_tbd: false,
    status: 'live',
    estimated: true,
    score: { home: 1, away: 0, home_pen: null, away_pen: null },
    competition: { id: 12, name: 'الدوري المصري الممتاز', logo: null, priority: 3, stage: 'الجولة 9' },
    home: team('البنك الأهلي'),
    away: team('المصري'),
    channel_count: 0,
    broadcaster_count: 0,
    missing_channels: true,
    commentator: null,
    sources: ['kickoff'],
    locked: false,
  },
  {
    id: 48215,
    match_date: '2026-10-31',
    kickoff_at: null,
    time_tbd: true,
    status: 'postponed',
    estimated: false,
    score: null,
    competition: { id: 40, name: 'دوري أبطال آسيا 2', logo: null, priority: 5, stage: 'الجولة 3' },
    home: team('النهضة'),
    away: team('الريان'),
    channel_count: 29,
    broadcaster_count: 1,
    missing_channels: false,
    commentator: { id: 9, name: 'حسن العيدروس' },
    sources: ['manual'],
    locked: false,
  },
];

const session = (role: 'admin' | 'editor') => ({
  access_token: 't',
  token_type: 'Bearer',
  expires_in: 900,
  admin: { id: 1, email: `${role}@example.com`, name: 'سارة', role },
});

const listRequests: URL[] = [];

function serveMatches(role: 'admin' | 'editor' = 'editor', list: readonly unknown[] = rows): void {
  listRequests.length = 0;
  server.use(
    mswHttp.post('*/admin/api/auth/refresh', () => HttpResponse.json(envelope(session(role)))),
    mswHttp.get('*/admin/api/matches', ({ request }) => {
      listRequests.push(new URL(request.url));
      return HttpResponse.json(envelope(list, { count: list.length }));
    }),
    mswHttp.get('*/admin/api/competitions', () =>
      HttpResponse.json(
        envelope([
          { id: 12, sport: 'football', name: 'الدوري المصري الممتاز', logo: null, logo_asset_id: null, priority: 3 },
          { id: 40, sport: 'football', name: 'دوري أبطال آسيا 2', logo: null, logo_asset_id: null, priority: 5 },
        ]),
      ),
    ),
    mswHttp.get('*/admin/api/sources', () =>
      HttpResponse.json(
        envelope([
          { name: 'ysscores', kind: 'scraper', is_enabled: true },
          { name: 'legacy', kind: 'scraper', is_enabled: true },
        ]),
      ),
    ),
  );
}

function Providers({ children }: { children: ReactNode }): ReactElement {
  return (
    <SessionProvider>
      <ToastProvider>{children}</ToastProvider>
    </SessionProvider>
  );
}

function renderPage(role: 'admin' | 'editor' = 'editor', list: readonly unknown[] = rows) {
  serveMatches(role, list);
  return renderRtl(<MatchesPage />, { wrapper: Providers });
}

/** The list has answered once a row is on screen. */
const waitForRows = () => screen.findByTestId('match-row-48213');

describe('MatchesPage (A3)', () => {
  it('asks for one Cairo day and shows it in the tabs', async () => {
    renderPage();

    await waitForRows();

    const today = cairoDay(new Date().toISOString());
    const bounds = cairoDayBounds(today);
    const url = listRequests.at(-1);
    expect(url?.searchParams.get('from')).toBe(bounds.from);
    expect(url?.searchParams.get('to')).toBe(bounds.to);

    // The tabs step the same Cairo day boundaries, not the browser's zone.
    await userEvent.click(screen.getByRole('button', { name: 'غداً' }));
    await waitFor(() => expect(listRequests.at(-1)?.searchParams.get('from')).toBe(cairoDayBounds(shiftCairoDay(today, 1)).from));
  });

  it('sends the four filters as query parameters', async () => {
    renderPage();
    await waitForRows();

    await userEvent.selectOptions(screen.getByLabelText('البطولة'), '40');
    await userEvent.selectOptions(screen.getByLabelText('المصدر'), 'ysscores');
    await userEvent.selectOptions(screen.getByLabelText('الحالة'), 'live');
    await userEvent.click(screen.getByRole('button', { name: 'بلا قنوات فقط' }));

    await waitFor(() => {
      const url = listRequests.at(-1);
      expect(url?.searchParams.get('competition_id')).toBe('40');
      expect(url?.searchParams.get('source')).toBe('ysscores');
      expect(url?.searchParams.get('status')).toBe('live');
      expect(url?.searchParams.get('missing_channels')).toBe('true');
    });
  });

  it('groups rows by competition with time, teams, status, channels, commentator, sources and the lock', async () => {
    renderPage();

    await waitForRows();
    const group = screen.getByRole('columnheader', { name: /الدوري المصري الممتاز · الجولة 9/ });
    expect(group).toHaveTextContent('2');

    const first = screen.getByTestId('match-row-48213');
    expect(first).toHaveTextContent('8:00');
    expect(first).toHaveTextContent('الأهلي');
    expect(first).toHaveTextContent('الزمالك');
    expect(first).toHaveTextContent('مجدولة');
    expect(first).toHaveTextContent('14');
    expect(first).toHaveTextContent('مدحت شلبي');
    expect(first).toHaveTextContent('YSS');
    expect(first).toHaveTextContent('LST');
    expect(first.querySelector('[aria-label="حقول مقفلة"]')).not.toBeNull();

    const live = screen.getByTestId('match-row-48214');
    expect(live).toHaveTextContent('مباشر · تقديري');
    expect(live).toHaveTextContent('0');
  });

  it('shows the skeleton while loading and the empty state when the day has no matches', async () => {
    renderPage('editor', []);

    expect(screen.getByTestId('matches-skeleton')).toBeInTheDocument();
    expect(await screen.findByText('لا مباريات في هذا اليوم')).toBeInTheDocument();
  });

  it('offers the all-clear state when the missing-channels filter finds nothing', async () => {
    renderPage('editor', []);
    await screen.findByText('لا مباريات في هذا اليوم');

    await userEvent.click(screen.getByRole('button', { name: 'بلا قنوات فقط' }));

    expect(await screen.findByText('كل مباريات اليوم لها قنوات')).toBeInTheDocument();
  });

  it('changes the competition of the selection for an editor, with each row version', async () => {
    let sent: Record<string, unknown> | null = null;
    renderPage('editor');
    await waitForRows();

    server.use(
      mswHttp.get('*/admin/api/matches/:id', ({ request }) =>
        HttpResponse.json(envelope({}), {
          headers: { ETag: `"etag-${new URL(request.url).pathname.split('/').at(-1)}"` },
        }),
      ),
      mswHttp.post('*/admin/api/matches/bulk', async ({ request }) => {
        sent = (await request.json()) as Record<string, unknown>;
        return HttpResponse.json(envelope({ updated: [{ id: 48213, etag: '"new"' }] }));
      }),
    );

    await userEvent.click(within(screen.getByTestId('match-row-48213')).getByRole('checkbox'));
    await userEvent.click(screen.getByRole('button', { name: 'تغيير البطولة' }));
    const dialog = screen.getByRole('alertdialog', { name: 'تغيير بطولة المباريات المحددة' });
    await userEvent.selectOptions(within(dialog).getByLabelText('البطولة'), '40');
    await userEvent.click(screen.getByRole('button', { name: 'تغيير' }));

    await waitFor(() => expect(sent).not.toBeNull());
    expect(sent).toMatchObject({
      action: 'change_competition',
      competition_id: 40,
      items: [{ id: 48213, etag: '"etag-48213"' }],
    });
  });

  it('keeps channel removal for an admin, behind the typed phrase', async () => {
    renderPage('admin');
    await waitForRows();

    await userEvent.click(within(screen.getByTestId('match-row-48213')).getByRole('checkbox'));
    await userEvent.click(screen.getByRole('button', { name: 'إزالة القنوات' }));

    const dialog = screen.getByRole('alertdialog', { name: 'إزالة القنوات من 1 مباراة؟' });
    const confirm = within(dialog).getByRole('button', { name: 'إزالة القنوات' });
    expect(confirm).toBeDisabled();

    await userEvent.type(within(dialog).getByLabelText(/للتأكيد اكتب/), 'إزالة القنوات من 1');
    expect(confirm).toBeEnabled();
  });

  it('hides channel removal from an editor', async () => {
    renderPage('editor');
    await waitForRows();

    await userEvent.click(within(screen.getByTestId('match-row-48213')).getByRole('checkbox'));

    expect(screen.queryByRole('button', { name: 'إزالة القنوات' })).not.toBeInTheDocument();
  });

  it('has «إضافة مباراة» and no delete action anywhere', async () => {
    renderPage();
    await waitForRows();

    expect(screen.getByRole('link', { name: 'إضافة مباراة' })).toHaveAttribute('href', '/matches/new');
    expect(screen.queryByRole('button', { name: /حذف/ })).not.toBeInTheDocument();
  });
});
