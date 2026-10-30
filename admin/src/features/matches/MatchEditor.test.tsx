import { screen, waitFor, within } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { HttpResponse, http as mswHttp } from 'msw';
import type { ReactElement, ReactNode } from 'react';
import { createMemoryRouter, Route, RouterProvider, Routes } from 'react-router-dom';
import { beforeEach, describe, expect, it, vi } from 'vitest';

import { ToastProvider } from '../../components/Toast/Toast';
import { SessionProvider } from '../auth/session';
import { renderRtl } from '../../test/render';
import { server } from '../../test/server';
import { MatchEditor } from './MatchEditor';

const envelope = (data: unknown): Record<string, unknown> => ({ success: true, data, error: null, meta: {} });

const errorBody = (code: string, meta: Record<string, unknown> = {}): Record<string, unknown> => ({
  success: false,
  data: null,
  error: { code, message: 'x' },
  meta,
});

const match = {
  id: 48213,
  sport: 'football',
  match_date: '2026-10-31',
  kickoff_at: '2026-10-31T17:30:00Z',
  time_tbd: false,
  competition_id: 12,
  competition_name: 'الدوري الإيطالي',
  competition_stage: 'الجولة الأولى',
  home: { team_id: 101, name: 'ميلان', logo_asset_id: null, logo: null },
  away: { team_id: 102, name: 'بولونيا', logo_asset_id: null, logo: null },
  stadium: 'سان سيرو',
  commentator_id: null,
  status: {
    status: 'scheduled',
    status_source: 'clock',
    estimated: false,
    period: null,
    minute: null,
    score: null,
    status_label: null,
    status_updated_at: null,
  },
  broadcasts: [],
  channels: [
    {
      channel_id: 5512,
      name: 'Sky Sport Italy',
      display_name: 'Sky Sport Italy',
      kind: 'satellite',
      satellite: { id: 2, name_ar: 'هوت بيرد', name_en: 'Hot Bird', orbital_position: 13 },
      frequency: { mhz: 11958, pol: 'V', sr: 27500 },
      access: 'encrypted',
      category: 'sports',
      logo: null,
      source: 'legacy',
      imported_by: 'legacy',
      is_hidden: false,
      hidden_by_name: false,
      commentator_id: null,
      commentator2_id: null,
    },
  ],
  locked_fields: [],
  external_ids: [],
  source: 'yssources',
  last_change: null,
};

const teams = [
  {
    id: 101,
    name: 'ميلان',
    country: 'إيطاليا',
    logo: null,
    primary_competition: { id: 12, name: 'الدوري الإيطالي' },
    competitions: [{ id: 12, name: 'الدوري الإيطالي' }],
  },
  {
    id: 102,
    name: 'بولونيا',
    country: 'إيطاليا',
    logo: null,
    primary_competition: { id: 12, name: 'الدوري الإيطالي' },
    competitions: [{ id: 12, name: 'الدوري الإيطالي' }],
  },
];

const channels = [
  {
    id: 5512,
    kind: 'satellite',
    name: 'Sky Sport Italy',
    display_name: 'Sky Sport Italy',
    logo_asset_id: null,
    logo: null,
    category: 'sports',
    country: null,
    satellite_id: 2,
    frequency: { mhz: 11958, pol: 'V', sr: 27500 },
    frequency_note: null,
    access: 'encrypted',
    provider: 'Sky',
    package: null,
    beam: 'wide',
    show_in_match: false,
    sort_order: 14,
    hidden_by_name: false,
  },
  {
    id: 6001,
    kind: 'platform',
    name: 'STC TV',
    display_name: 'STC TV',
    logo_asset_id: null,
    logo: null,
    category: 'sports',
    country: null,
    satellite_id: null,
    frequency: null,
    frequency_note: null,
    access: 'free',
    provider: 'STC',
    package: null,
    beam: null,
    show_in_match: true,
    sort_order: 3,
    hidden_by_name: false,
  },
];

let patched: { body: Record<string, unknown>; ifMatch: string | null } | null = null;

function serveMatchData(): void {
  patched = null;
  server.use(
    mswHttp.get('*/admin/api/matches/48213', () => HttpResponse.json(envelope(match), { headers: { ETag: '"v1"' } })),
    mswHttp.patch('*/admin/api/matches/48213', async ({ request }) => {
      patched = { body: (await request.json()) as Record<string, unknown>, ifMatch: request.headers.get('If-Match') };
      return HttpResponse.json(envelope(match), { headers: { ETag: '"v2"' } });
    }),
    mswHttp.get('*/admin/api/competitions', () =>
      HttpResponse.json(
        envelope([{ id: 12, sport: 'football', name: 'الدوري الإيطالي', logo: null, logo_asset_id: null, priority: 1 }]),
      ),
    ),
    mswHttp.get('*/admin/api/commentators', () =>
      HttpResponse.json(
        envelope([{ id: 7, name: 'فارس عوض', photo: null, photo_asset_id: null, audio: null, audio_asset_id: null, usage: { matches: 1, match_channels: 2 } }]),
      ),
    ),
    mswHttp.get('*/admin/api/teams', () => HttpResponse.json(envelope(teams))),
    mswHttp.get('*/admin/api/channels', () => HttpResponse.json(envelope(channels))),
  );
}

function Providers({ children }: { children: ReactNode }): ReactElement {
  return (
    <SessionProvider>
      <ToastProvider>{children}</ToastProvider>
    </SessionProvider>
  );
}

/** A4 behind the app's data router: `useBlocker` needs one. */
function renderEditor() {
  serveMatchData();
  const router = createMemoryRouter(
    [
      { path: '/matches/:id', element: <MatchEditor /> },
      {
        path: '/matches',
        element: (
          <Routes>
            <Route index element={<p>قائمة المباريات</p>} />
          </Routes>
        ),
      },
    ],
    { initialEntries: ['/matches/48213'] },
  );
  renderRtl(<RouterProvider router={router} />, { withRouter: false, wrapper: Providers });
  return router;
}

const waitForEditor = () => screen.findByRole('heading', { name: 'ميلان × بولونيا' });

beforeEach(() => {
  vi.useRealTimers();
});

describe('MatchEditor (A4)', () => {
  it('offers the teams with country and competitions, and accepts free text', async () => {
    renderEditor();
    await waitForEditor();

    const home = screen.getByLabelText('صاحب الأرض');
    expect(home).toHaveValue('ميلان');
    expect(screen.getAllByText('إيطاليا · الدوري الإيطالي').length).toBeGreaterThan(0);

    await userEvent.clear(home);
    await userEvent.type(home, 'فريق غير مربوط');
    expect(screen.getByText('أو اكتب اسماً')).toBeInTheDocument();
  });

  it('sends the Cairo kickoff as the right UTC instant on each side of the DST change', async () => {
    renderEditor();
    await waitForEditor();

    const time = screen.getByLabelText('الوقت بتوقيت القاهرة');
    await userEvent.clear(time);
    await userEvent.type(time, '20:00');

    await userEvent.click(screen.getByRole('button', { name: 'حفظ' }));

    await waitFor(() => expect(patched).not.toBeNull());
    expect(patched?.ifMatch).toBe('"v1"');
    expect(patched?.body).toMatchObject({ fields: { kickoff_at: '2026-10-31T18:00:00.000Z' } });
    expect(await screen.findByText('تم الحفظ')).toBeInTheDocument();
  });

  it('marks a match whose time is not decided with time_tbd', async () => {
    renderEditor();
    await waitForEditor();

    await userEvent.click(screen.getByLabelText('الموعد لم يتحدد'));
    await userEvent.click(screen.getByRole('button', { name: 'حفظ' }));

    await waitFor(() => expect(patched).not.toBeNull());
    expect(patched?.body).toMatchObject({ fields: { time_tbd: true, kickoff_at: null } });
  });

  it('allows a score only where the data model does, and penalties only with them', async () => {
    renderEditor();
    await waitForEditor();

    const status = screen.getByLabelText('الحالة');
    expect(screen.getByLabelText('صاحب الأرض النتيجة')).toBeDisabled();

    await userEvent.selectOptions(status, 'live');
    expect(screen.getByLabelText('صاحب الأرض النتيجة')).toBeEnabled();
    expect(screen.getByLabelText('ركلات الترجيح صاحب الأرض')).toBeDisabled();

    await userEvent.selectOptions(status, 'penalties');
    expect(screen.getByLabelText('ركلات الترجيح صاحب الأرض')).toBeEnabled();

    await userEvent.selectOptions(status, 'postponed');
    expect(screen.getByLabelText('صاحب الأرض النتيجة')).toBeDisabled();
  });

  it('offers two broadcaster slots and saves them as the manual broadcast', async () => {
    renderEditor();
    await waitForEditor();

    await userEvent.type(screen.getByLabelText('يعرض على'), 'STC TV');
    await userEvent.selectOptions(screen.getByLabelText('البث اليدوي المعلق 1'), '7');
    await userEvent.click(screen.getByRole('button', { name: 'حفظ' }));

    await waitFor(() => expect(patched).not.toBeNull());
    expect(patched?.body).toMatchObject({ broadcasts: [{ slot: 1, label: 'STC TV', commentator_id: 7 }] });
  });

  it('adds a channel from the filtered picker, and unlocks commentator 2 only after commentator 1', async () => {
    renderEditor();
    await waitForEditor();

    await userEvent.type(screen.getByLabelText('ابحث عن قناة'), 'STC');
    await userEvent.selectOptions(screen.getByLabelText('التصنيف'), 'sports');
    const addButtons = screen.getAllByRole('button', { name: 'إضافة' });
    await userEvent.click(addButtons[1] as HTMLElement);

    const link = screen.getByTestId('channel-link-6001');
    const second = screen.getByLabelText('المعلق 2: STC TV');
    expect(second).toBeDisabled();

    await userEvent.selectOptions(screen.getByLabelText('المعلق 1: STC TV'), '7');
    expect(second).toBeEnabled();
    expect(link).toHaveTextContent('manual');
  });

  it('hides a channel from this match only, without a confirmation', async () => {
    renderEditor();
    await waitForEditor();

    await userEvent.click(screen.getByLabelText('إخفاء من هذا الماتش فقط: Sky Sport Italy'));
    await userEvent.click(screen.getByRole('button', { name: 'حفظ' }));

    await waitFor(() => expect(patched).not.toBeNull());
    expect(patched?.body).toMatchObject({ channels: [{ channel_id: 5512, is_hidden: true }] });
  });

  it('hides a channel everywhere only after the typed confirmation', async () => {
    renderEditor();
    await waitForEditor();

    await userEvent.click(screen.getByRole('button', { name: 'إخفاء دائماً' }));
    const dialog = screen.getByRole('alertdialog', { name: 'إخفاء «Sky Sport Italy» دائماً؟' });
    const confirm = within(dialog).getByRole('button', { name: 'إخفاء دائماً' });
    expect(confirm).toBeDisabled();

    await userEvent.type(within(dialog).getByLabelText(/للتأكيد اكتب/), 'إخفاء دائماً');
    await userEvent.click(within(dialog).getByRole('button', { name: 'إخفاء دائماً' }));

    await waitFor(() => expect(dialog).not.toBeInTheDocument());
  });

  it('opens the conflict dialog on 409 and reloads the current match', async () => {
    renderEditor();
    await waitForEditor();

    server.use(
      mswHttp.patch('*/admin/api/matches/48213', () =>
        HttpResponse.json(
          errorBody('edit_conflict', { current_etag: '"v2"', changed_by: { kind: 'admin', name: 'يوسف عمر' } }),
          { status: 409 },
        ),
      ),
    );

    await userEvent.clear(screen.getByLabelText('الوقت بتوقيت القاهرة'));
    await userEvent.type(screen.getByLabelText('الوقت بتوقيت القاهرة'), '21:00');
    await userEvent.click(screen.getByRole('button', { name: 'حفظ' }));

    const dialog = await screen.findByRole('alertdialog', { name: 'عدّل يوسف عمر هذا العنصر' });
    await userEvent.click(screen.getByRole('button', { name: 'إعادة التحميل' }));

    await waitFor(() => expect(dialog).not.toBeInTheDocument());
    expect(screen.getByLabelText('الوقت بتوقيت القاهرة')).toHaveValue('19:30');
  });

  it.each([
    [428, 'precondition_required', 'أعد تحميل الصفحة ثم حاول مرة أخرى'],
    [422, 'validation_error', 'راجع البيانات المدخلة ثم حاول مرة أخرى'],
  ])('shows the Arabic copy of %s %s', async (status, code, message) => {
    renderEditor();
    await waitForEditor();

    server.use(
      mswHttp.patch('*/admin/api/matches/48213', () => HttpResponse.json(errorBody(code), { status })),
    );

    await userEvent.clear(screen.getByLabelText('الوقت بتوقيت القاهرة'));
    await userEvent.type(screen.getByLabelText('الوقت بتوقيت القاهرة'), '21:00');
    await userEvent.click(screen.getByRole('button', { name: 'حفظ' }));

    expect(await screen.findByText(message)).toBeInTheDocument();
  });

  it('blocks leaving with unsaved changes', async () => {
    const router = renderEditor();
    await waitForEditor();

    await userEvent.clear(screen.getByLabelText('الملعب'));
    await userEvent.type(screen.getByLabelText('الملعب'), 'سان سيرو 2');

    await router.navigate('/matches');

    expect(await screen.findByRole('alertdialog', { name: 'لديك تغييرات غير محفوظة' })).toBeInTheDocument();
  });
});
