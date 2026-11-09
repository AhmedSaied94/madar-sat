import { screen, waitFor, within } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { delay, http, HttpResponse } from 'msw';
import { afterEach, describe, expect, it, vi } from 'vitest';

import { renderRtl } from '../../test/render';
import { server } from '../../test/server';
import { envelope, Providers, refusal, restoreAs } from '../../test/signedIn';
import { MatchPicker, type PickedMatch } from './MatchPicker';

// A15's match picker (A-R1-6): every match of the chosen Cairo day, searchable by team or competition,
// with the pick marked and real loading, empty and error states. It serves both the deep link and the
// «متابعو المباراة» audience.

const team = (id: number, name: string) => ({ id, name, logo: null });

function match(n: number, home: string, away: string, competition = 'الدوري المصري') {
  return {
    id: 48000 + n,
    match_date: '2026-11-09',
    kickoff_at: `2026-11-09T${String(8 + n).padStart(2, '0')}:00:00Z`,
    time_tbd: false,
    status: 'scheduled',
    estimated: false,
    score: null,
    competition: { id: 10 + n, name: competition, logo: null, priority: n, stage: null },
    home: team(1000 + n, home),
    away: team(2000 + n, away),
    channel_count: 1,
    broadcaster_count: 0,
    missing_channels: false,
    commentator: null,
    sources: ['ysscores'],
    locked: false,
    etag: `"row-${48000 + n}"`,
  };
}

const twelve = [
  ...Array.from({ length: 11 }, (_, index) => match(index + 1, `فريق ${index + 1}`, `ضيف ${index + 1}`)),
  match(12, 'ليفربول', 'تشيلسي', 'الدوري الإنجليزي'),
];

function serve(rows: unknown[] = twelve): URL[] {
  const requests: URL[] = [];
  server.use(
    http.get('*/admin/api/matches', ({ request }) => {
      requests.push(new URL(request.url));
      return HttpResponse.json(envelope(rows));
    }),
  );
  return requests;
}

function renderPicker(props: { selectedId?: number | null; trigger?: string } = {}) {
  const picks: PickedMatch[] = [];
  restoreAs('admin');
  renderRtl(<MatchPicker {...props} onPick={(picked) => picks.push(picked)} />, { wrapper: Providers });
  return picks;
}

afterEach(() => {
  vi.useRealTimers();
});

describe('A15 the match picker', () => {
  it('offers every match, not just the first eight, and picks one beyond the eighth', async () => {
    serve();
    const picks = renderPicker();

    const list = await screen.findByRole('list', { name: 'المباراة' });
    await waitFor(() => expect(within(list).getAllByRole('button')).toHaveLength(12));
    await userEvent.click(within(list).getByRole('button', { name: /ليفربول × تشيلسي/ }));

    expect(picks).toEqual([{ id: 48012, label: 'ليفربول × تشيلسي', route: '/match/48012' }]);
  });

  it('narrows the list by team or competition', async () => {
    serve();
    renderPicker();

    const list = await screen.findByRole('list', { name: 'المباراة' });
    await waitFor(() => expect(within(list).getAllByRole('button')).toHaveLength(12));
    await userEvent.type(screen.getByLabelText('ابحث بالفريق أو البطولة'), 'تشيل');
    expect(within(list).getAllByRole('button')).toHaveLength(1);

    await userEvent.clear(screen.getByLabelText('ابحث بالفريق أو البطولة'));
    await userEvent.type(screen.getByLabelText('ابحث بالفريق أو البطولة'), 'الإنجليزي');
    expect(within(list).getByRole('button', { name: /ليفربول × تشيلسي/ })).toBeInTheDocument();
  });

  it('asks for today’s Cairo day first, then the day chosen, then the whole window', async () => {
    vi.useFakeTimers({ toFake: ['Date'] });
    vi.setSystemTime(new Date('2026-11-09T10:00:00Z'));
    const requests = serve();
    renderPicker();

    await waitFor(() => expect(requests.length).toBeGreaterThan(0));
    expect(requests.at(-1)?.searchParams.get('from')).toBe('2026-11-08T22:00:00.000Z');
    expect(requests.at(-1)?.searchParams.get('to')).toBe('2026-11-09T22:00:00.000Z');

    const day = screen.getByLabelText('يوم المباراة');
    await userEvent.selectOptions(day, within(day).getByRole('option', { name: 'غداً' }));
    await waitFor(() => expect(requests.at(-1)?.searchParams.get('from')).toBe('2026-11-09T22:00:00.000Z'));
    expect(requests.at(-1)?.searchParams.get('to')).toBe('2026-11-10T22:00:00.000Z');

    // The list's widest window: yesterday and the six days after today (eight days, admin-api).
    await userEvent.selectOptions(day, within(day).getByRole('option', { name: 'كل الأيام' }));
    await waitFor(() => expect(requests.at(-1)?.searchParams.get('from')).toBe('2026-11-07T22:00:00.000Z'));
    expect(requests.at(-1)?.searchParams.get('to')).toBe('2026-11-15T22:00:00.000Z');
  });

  it('marks the picked match', async () => {
    serve();
    renderPicker({ selectedId: 48012 });

    const list = await screen.findByRole('list', { name: 'المباراة' });
    expect(await within(list).findByRole('button', { name: /ليفربول × تشيلسي/ })).toHaveAttribute('aria-pressed', 'true');
    expect(within(list).getByRole('button', { name: /فريق 1 ×/ })).toHaveAttribute('aria-pressed', 'false');
  });

  it('says it is loading while the day is read', async () => {
    server.use(
      http.get('*/admin/api/matches', async () => {
        await delay('infinite');
        return HttpResponse.json(envelope([]));
      }),
    );
    renderPicker();

    expect(await screen.findByText('جارٍ تحميل المباريات')).toBeInTheDocument();
    expect(screen.queryByText('اكتب عنواناً ونصاً قبل الإرسال')).not.toBeInTheDocument();
  });

  it('says so when the day has no match', async () => {
    serve([]);
    renderPicker();
    expect(await screen.findByText('لا مباريات في هذا اليوم')).toBeInTheDocument();
  });

  it('says so when the search matches none', async () => {
    serve();
    renderPicker();
    const list = await screen.findByRole('list', { name: 'المباراة' });
    await waitFor(() => expect(within(list).getAllByRole('button')).toHaveLength(12));
    await userEvent.type(screen.getByLabelText('ابحث بالفريق أو البطولة'), 'ريال');
    expect(screen.getByText('لا مباراة تطابق البحث')).toBeInTheDocument();
  });

  it('shows a failed read with a retry that reads again', async () => {
    let calls = 0;
    server.use(
      http.get('*/admin/api/matches', () => {
        calls += 1;
        return HttpResponse.json(refusal('internal_error'), { status: 500 });
      }),
    );
    renderPicker();

    expect(await screen.findByText('حدث خطأ في الخادم. حاول مرة أخرى بعد قليل')).toBeInTheDocument();
    const before = calls;
    await userEvent.click(screen.getByRole('button', { name: 'إعادة المحاولة' }));
    await waitFor(() => expect(calls).toBeGreaterThan(before));
  });
});
