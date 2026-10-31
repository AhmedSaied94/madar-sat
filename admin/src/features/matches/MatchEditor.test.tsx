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
  broadcasts: [
    { slot: 1, label: 'Sky Sport Italy', logo_asset_id: 31, logo: null, commentator_id: null },
  ],
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
  // A second team with the same name, told apart by its country (A-R1-6).
  {
    id: 201,
    name: 'الأهلي',
    country: 'مصر',
    logo: null,
    primary_competition: { id: 12, name: 'الدوري الإيطالي' },
    competitions: [{ id: 12, name: 'الدوري الإيطالي' }],
  },
  {
    id: 202,
    name: 'الأهلي',
    country: 'السعودية',
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

let patched: { body: Record<string, unknown>; ifMatch: string | null; bearer: string | null } | null = null;
let patchCalls = 0;
let created: { body: Record<string, unknown> } | null = null;
let channelQueries: URL[] = [];
/** What the next `GET /matches/48213` answers, and with which version: a test replaces both to model a
 *  refetch that brings changed data (A-R2-1). */
let matchBody: Record<string, unknown> = match;
let matchEtag = '"v1"';

const session = {
  access_token: 'token-1',
  token_type: 'Bearer',
  expires_in: 900,
  admin: { id: 1, email: 'editor@example.com', name: 'سارة', role: 'editor' },
};

function serveMatchData(overrides: Record<string, unknown> = {}): void {
  patched = null;
  patchCalls = 0;
  created = null;
  channelQueries = [];
  matchBody = { ...match, ...overrides };
  matchEtag = '"v1"';
  server.use(
    // This suite starts signed in: the editor's writes carry the bearer the mutator holds (A-R1-1).
    mswHttp.post('*/admin/api/auth/refresh', () => HttpResponse.json(envelope(session))),
    mswHttp.get('*/admin/api/matches/48213', () =>
      HttpResponse.json(envelope(matchBody), { headers: { ETag: matchEtag } }),
    ),
    mswHttp.patch('*/admin/api/matches/48213', async ({ request }) => {
      patchCalls += 1;
      // A write without the bearer is refused, as the real API refuses it (A-R1-1).
      const bearer = request.headers.get('Authorization');
      patched = {
        body: (await request.json()) as Record<string, unknown>,
        ifMatch: request.headers.get('If-Match'),
        bearer,
      };
      return bearer
        ? HttpResponse.json(envelope({ ...match, ...overrides }), { headers: { ETag: '"v2"' } })
        : HttpResponse.json(errorBody('token_expired'), { status: 401 });
    }),
    mswHttp.post('*/admin/api/matches', async ({ request }) => {
      created = { body: (await request.json()) as Record<string, unknown> };
      return HttpResponse.json(envelope({ ...match, id: 48299 }), { status: 201, headers: { ETag: '"new"' } });
    }),
    mswHttp.get('*/admin/api/matches/48299', () =>
      HttpResponse.json(envelope({ ...match, id: 48299 }), { headers: { ETag: '"new"' } }),
    ),
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
    mswHttp.get('*/admin/api/broadcast-presets', () =>
      HttpResponse.json(
        envelope([
          // A preset's own id (71/72) is never a media asset id: `logo_asset_id` is the asset (A-R2-2).
          { id: 71, name: 'Sky Sport Italy', logo: null, logo_asset_id: 31 },
          { id: 72, name: 'beIN Sports', logo: null, logo_asset_id: 82 },
        ]),
      ),
    ),
    mswHttp.get('*/admin/api/satellites', () =>
      HttpResponse.json(
        envelope([
          {
            id: 2,
            name_ar: 'هوت بيرد',
            name_en: 'Hot Bird',
            orbital_position: 13,
            kind: 'satellite',
            slug: 'hot-bird',
            logo: null,
            logo_asset_id: null,
            priority: 1,
            best_frequency: null,
            worst_frequency: null,
            reception_url: null,
          },
        ]),
      ),
    ),
    mswHttp.get('*/admin/api/teams', () => HttpResponse.json(envelope(teams))),
    mswHttp.get('*/admin/api/channels', ({ request }) => {
      channelQueries.push(new URL(request.url));
      return HttpResponse.json(envelope(channels));
    }),
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
function renderEditor(overrides: Record<string, unknown> = {}) {
  serveMatchData(overrides);
  const router = createMemoryRouter(
    [
      { path: '/matches/new', element: <MatchEditor /> },
      { path: '/matches/:id', element: <MatchEditor /> },
      {
        path: '/matches',
        element: (
          <Routes>
            <Route index element={<p>قائمة المباريات</p>} />
          </Routes>
        ),
      },
      { path: '/channels', element: <p>القنوات</p> },
    ],
    { initialEntries: ['/matches/48213'] },
  );
  renderRtl(<RouterProvider router={router} />, { withRouter: false, wrapper: Providers });
  return router;
}

function renderNewEditor() {
  serveMatchData();
  const router = createMemoryRouter(
    [
      { path: '/matches/new', element: <MatchEditor /> },
      { path: '/matches/:id', element: <MatchEditor /> },
      { path: '/matches', element: <p>قائمة المباريات</p> },
    ],
    { initialEntries: ['/matches/new'] },
  );
  renderRtl(<RouterProvider router={router} />, { withRouter: false, wrapper: Providers });
  return router;
}

const waitForEditor = () => screen.findByRole('heading', { name: 'ميلان × بولونيا' });
const saveButton = () => screen.getByRole('button', { name: 'حفظ' });

beforeEach(() => {
  vi.useRealTimers();
});

describe('MatchEditor (A4)', () => {
  it('offers the teams with country and competitions, and accepts free text', async () => {
    renderEditor();
    await waitForEditor();

    const home = screen.getByLabelText('صاحب الأرض');
    expect(home).toHaveValue('ميلان');
    await userEvent.click(home);
    expect(screen.getAllByText('إيطاليا · الدوري الإيطالي').length).toBeGreaterThan(0);

    await userEvent.clear(home);
    await userEvent.type(home, 'فريق غير مربوط');
    expect(screen.getByText('أو اكتب اسماً')).toBeInTheDocument();
  });

  it('picks a team by id when two teams share a name', async () => {
    renderEditor();
    await waitForEditor();

    const home = screen.getByLabelText('صاحب الأرض');
    await userEvent.clear(home);
    await userEvent.type(home, 'الأهلي');
    const options = screen.getAllByRole('option', { name: /الأهلي/ });
    await userEvent.click(options[1] as HTMLElement);

    await userEvent.click(saveButton());

    await waitFor(() => expect(patched).not.toBeNull());
    // The second «الأهلي» (السعودية) is 202; the old name lookup always chose the first one.
    expect(patched?.body).toMatchObject({ fields: { home: { team_id: 202 } } });
  });

  it('picks a team with the keyboard, without the mouse', async () => {
    renderEditor();
    await waitForEditor();

    const home = screen.getByLabelText('صاحب الأرض');
    await userEvent.clear(home);
    await userEvent.type(home, 'الأهلي');
    await screen.findAllByRole('option', { name: /الأهلي/ });
    // Arrow keys move the active option and Enter picks it (A-R1-6, WCAG 2.1.1).
    await userEvent.keyboard('{ArrowDown}{ArrowDown}{ArrowDown}{Enter}');

    await userEvent.click(saveButton());

    await waitFor(() => expect(patched).not.toBeNull());
    expect(patched?.body).toMatchObject({ fields: { home: { team_id: 202 } } });
  });

  it('sends the Cairo kickoff as the right UTC instant on each side of the DST change', async () => {
    renderEditor();
    await waitForEditor();

    const time = screen.getByLabelText('الوقت بتوقيت القاهرة');
    await userEvent.clear(time);
    await userEvent.type(time, '20:00');

    await userEvent.click(saveButton());

    await waitFor(() => expect(patched).not.toBeNull());
    // The version and the bearer both come from the mutator: the save of an existing match is not a 428.
    expect(patched?.ifMatch).toBe('"v1"');
    expect({ calls: patchCalls, bearer: patched?.bearer }).toEqual({ calls: 1, bearer: 'Bearer token-1' });
    expect(patched?.body).toMatchObject({ fields: { kickoff_at: '2026-10-31T18:00:00.000Z' } });
    expect(await screen.findByText('تم الحفظ')).toBeInTheDocument();
  });

  it('marks a locked field as locked, through the shared Field', async () => {
    renderEditor({ locked_fields: ['match_date', 'stadium'] });
    await waitForEditor();

    // The importer will not change it, so the editor sees why the field is marked (A-R1-10).
    expect(screen.getAllByTestId('field-lock').length).toBe(2);
    expect(screen.getByLabelText('الملعب')).toHaveAttribute('aria-describedby');
    expect(screen.getAllByTestId('field-control')[0]).toHaveAttribute('data-state', 'locked');
  });

  it('prints the stored UTC time beside the Cairo one', async () => {    renderEditor();
    await waitForEditor();

    const time = screen.getByLabelText('الوقت بتوقيت القاهرة');
    await userEvent.clear(time);
    await userEvent.type(time, '20:00');

    // 20:00 Cairo on 31 October 2026 is 18:00 UTC, which is what the hint must say (A-R1-12).
    expect(screen.getByText(/يُحفظ 18:00 UTC/)).toBeInTheDocument();
  });

  it('saves again under the version the first save returned', async () => {
    renderEditor();
    await waitForEditor();

    const time = screen.getByLabelText('الوقت بتوقيت القاهرة');
    await userEvent.clear(time);
    await userEvent.type(time, '20:00');
    await userEvent.click(saveButton());
    await waitFor(() => expect(patched?.ifMatch).toBe('"v1"'));

    const stadium = screen.getByLabelText('الملعب');
    await userEvent.clear(stadium);
    await userEvent.type(stadium, 'سان سيرو 2');
    await userEvent.click(saveButton());

    // The stale version of the first load is not reused: the second save would be a 409 against itself.
    await waitFor(() => expect(patched?.body).toMatchObject({ fields: { stadium: 'سان سيرو 2' } }));
    expect(patched?.ifMatch).toBe('"v2"');
  });

  it.each([
    // Cairo is +03:00 while DST is on and +02:00 once it is off, so the stored instant differs.
    ['2026-04-25T09:00:00Z', '13:00', '2026-04-25T10:00:00.000Z'],
    ['2026-11-15T10:00:00Z', '13:00', '2026-11-15T11:00:00.000Z'],
  ])('stores %s typed as a Cairo wall time on each side of the DST change', async (kickoff, typed, stored) => {
    renderEditor({ kickoff_at: kickoff, match_date: kickoff.slice(0, 10) });
    await waitForEditor();

    const time = screen.getByLabelText('الوقت بتوقيت القاهرة');
    await userEvent.clear(time);
    await userEvent.type(time, typed);
    await userEvent.click(saveButton());

    await waitFor(() => expect(patched).not.toBeNull());
    expect(patched?.body).toMatchObject({ fields: { kickoff_at: stored } });
  });

  it('marks a match whose time is not decided with time_tbd', async () => {
    renderEditor();
    await waitForEditor();

    await userEvent.click(screen.getByLabelText('الموعد لم يتحدد'));
    await userEvent.click(saveButton());

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

  it('refuses a manual live status without a score instead of saving 0–0', async () => {
    renderEditor();
    await waitForEditor();

    await userEvent.selectOptions(screen.getByLabelText('الحالة'), 'live');
    await userEvent.click(saveButton());

    expect(await screen.findByText('أدخل نتيجة المباراة كاملة قبل الحفظ')).toBeInTheDocument();
    expect(patched).toBeNull();
  });

  it('sends the score, the minute and the period of a manual status', async () => {
    renderEditor({ status: { ...match.status, status: 'live', status_source: 'manual', minute: '67', period: '2H', score: { home: 1, away: 0, home_pen: null, away_pen: null } } });
    await waitForEditor();

    expect(screen.getByLabelText('الدقيقة')).toHaveValue('67');
    await userEvent.clear(screen.getByLabelText('الدقيقة'));
    await userEvent.type(screen.getByLabelText('الدقيقة'), '72');
    await userEvent.click(saveButton());

    await waitFor(() => expect(patched).not.toBeNull());
    expect(patched?.body).toMatchObject({ status: { set: { status: 'live', score: { home: 1, away: 0 }, minute: '72', period: '2H' } } });
  });

  it('sends a penalty-only change', async () => {
    renderEditor({
      status: {
        status: 'penalties',
        status_source: 'manual',
        estimated: false,
        period: null,
        minute: null,
        score: { home: 1, away: 1, home_pen: null, away_pen: null },
        status_label: null,
        status_updated_at: null,
      },
    });
    await waitForEditor();

    await userEvent.type(screen.getByLabelText('ركلات الترجيح صاحب الأرض'), '4');
    await userEvent.click(saveButton());

    await waitFor(() => expect(patched).not.toBeNull());
    expect(patched?.body).toMatchObject({ status: { set: { score: { home_pen: 4 } } } });
  });

  it('offers two broadcaster slots and their presets, and sends the preset’s asset id, never its id', async () => {
    renderEditor();
    await waitForEditor();

    // A preset sets the label and the media asset the slot saves. Its own id (72) is a different table;
    // sending it would publish an unrelated media asset as the broadcaster's logo (A-R2-2, B1-R2-8).
    const first = screen.getByLabelText('يعرض على');
    await userEvent.clear(first);
    await userEvent.type(first, 'beIN Sports');
    await userEvent.selectOptions(screen.getByLabelText('البث اليدوي المعلق 2'), '7');
    await userEvent.click(saveButton());

    await waitFor(() => expect(patched).not.toBeNull());
    expect(patched?.body).toMatchObject({
      broadcasts: [{ slot: 1, label: 'beIN Sports', logo_asset_id: 82, commentator_id: null }],
    });
  });

  it('drops a slot’s logo when its label becomes another broadcaster', async () => {
    renderEditor();
    await waitForEditor();

    const first = screen.getByLabelText('يعرض على');
    await userEvent.type(first, ' HD');
    await userEvent.click(saveButton());

    await waitFor(() => expect(patched).not.toBeNull());
    // «Sky Sport Italy HD» is not Sky Sport Italy: the slot must not keep Sky's logo (A-R2-12).
    expect(patched?.body).toMatchObject({
      broadcasts: [{ slot: 1, label: 'Sky Sport Italy HD', logo_asset_id: null }],
    });
  });

  it('offers the stage presets over free text', async () => {
    renderEditor();
    await waitForEditor();

    const stage = screen.getByLabelText('المرحلة');
    const listId = stage.getAttribute('list');
    expect(listId).toBeTruthy();
    const options = Array.from(document.getElementById(listId ?? '')?.querySelectorAll('option') ?? []).map(
      (option) => option.getAttribute('value'),
    );
    // US4 scenario 4's rounds are suggestions; the field still takes any text (A-R2-5).
    expect(options).toEqual(['الجولة الأولى', 'ذهاب دور 16', 'إياب دور 16', 'ربع النهائي', 'نصف النهائي', 'النهائي']);

    await userEvent.clear(stage);
    await userEvent.type(stage, 'ربع النهائي');
    await userEvent.click(saveButton());

    await waitFor(() => expect(patched).not.toBeNull());
    expect(patched?.body).toMatchObject({ fields: { competition_stage: 'ربع النهائي' } });
  });

  it('never sends half a score', async () => {
    renderEditor({
      status: {
        status: 'abandoned',
        status_source: 'manual',
        estimated: false,
        period: null,
        minute: null,
        score: null,
        status_label: null,
        status_updated_at: null,
      },
    });
    await waitForEditor();

    await userEvent.type(screen.getByLabelText('صاحب الأرض النتيجة'), '2');
    await userEvent.click(saveButton());

    expect(await screen.findByText('أدخل نتيجة المباراة كاملة قبل الحفظ')).toBeInTheDocument();
    expect(patched).toBeNull();
  });

  it('keeps a slot’s logo when only its commentator changed', async () => {    renderEditor();
    await waitForEditor();

    await userEvent.selectOptions(screen.getByLabelText('البث اليدوي المعلق 1'), '7');
    await userEvent.click(saveButton());

    await waitFor(() => expect(patched).not.toBeNull());
    expect(patched?.body).toMatchObject({ broadcasts: [{ slot: 1, label: 'Sky Sport Italy', logo_asset_id: 31 }] });
  });

  it('adds a channel from the filtered picker, and unlocks commentator 2 only after commentator 1', async () => {
    renderEditor();
    await waitForEditor();

    await userEvent.type(screen.getByLabelText('ابحث عن قناة'), 'STC');
    await userEvent.selectOptions(screen.getByLabelText('التصنيف'), 'sports');
    // The satellite list arrives from the API before it can be chosen (A-R1-7).
    await screen.findByRole('option', { name: /هوت بيرد/ });
    await userEvent.selectOptions(screen.getByLabelText('القمر'), '2');
    await waitFor(() => expect(channelQueries.at(-1)?.searchParams.get('satellite_id')).toBe('2'));

    const addButtons = screen.getAllByRole('button', { name: 'إضافة' });
    await userEvent.click(addButtons[1] as HTMLElement);

    const link = screen.getByTestId('channel-link-6001');
    const second = screen.getByLabelText('المعلق 2 STC TV');
    expect(second).toBeDisabled();

    await userEvent.selectOptions(screen.getByLabelText('المعلق 1 STC TV'), '7');
    expect(second).toBeEnabled();
    expect(link).toHaveTextContent('manual');
  });

  it('filters the picker to platforms without a satellite', async () => {
    renderEditor();
    await waitForEditor();

    await userEvent.selectOptions(screen.getByLabelText('القمر'), 'platform');

    await waitFor(() => expect(channelQueries.at(-1)?.searchParams.get('kind')).toBe('platform'));
    expect(channelQueries.at(-1)?.searchParams.get('satellite_id')).toBeNull();
  });

  it('hides a channel from this match only, without a confirmation', async () => {
    renderEditor();
    await waitForEditor();

    await userEvent.click(screen.getByLabelText('إخفاء من هذا الماتش فقط Sky Sport Italy'));
    await userEvent.click(saveButton());

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

  it('shows «إظهار» for a channel hidden everywhere, and unhides it', async () => {
    renderEditor({
      channels: [{ ...(match.channels[0] as Record<string, unknown>), hidden_by_name: true }],
    });
    await waitForEditor();

    expect(screen.getByText('مخفية دائماً')).toBeInTheDocument();
    await userEvent.click(screen.getByRole('button', { name: 'إظهار' }));

    await waitFor(() => expect(screen.queryByText('مخفية دائماً')).not.toBeInTheDocument());
  });

  it('keeps the dialog open and says so when hiding everywhere is refused', async () => {
    renderEditor();
    await waitForEditor();
    server.use(
      mswHttp.post('*/admin/api/hidden-channel-names', () =>
        HttpResponse.json(errorBody('forbidden'), { status: 403 }),
      ),
    );

    await userEvent.click(screen.getByRole('button', { name: 'إخفاء دائماً' }));
    const dialog = screen.getByRole('alertdialog', { name: 'إخفاء «Sky Sport Italy» دائماً؟' });
    await userEvent.type(within(dialog).getByLabelText(/للتأكيد اكتب/), 'إخفاء دائماً');
    await userEvent.click(within(dialog).getByRole('button', { name: 'إخفاء دائماً' }));

    expect(await screen.findByText('صلاحيتك لا تسمح بهذا الإجراء')).toBeInTheDocument();
    expect(dialog).toBeInTheDocument();
  });

  it('shows the other editor’s version and time in the conflict dialog, and reloads it', async () => {
    renderEditor();
    await waitForEditor();

    server.use(
      mswHttp.patch('*/admin/api/matches/48213', () =>
        HttpResponse.json(
          errorBody('edit_conflict', {
            current_etag: '"v2"',
            changed_at: '2026-10-30T16:02:11Z',
            changed_by: { kind: 'admin', name: 'يوسف عمر' },
          }),
          { status: 409 },
        ),
      ),
      // The version the server holds now: a later kickoff than the one this editor loaded.
      mswHttp.get('*/admin/api/matches/48213', () =>
        HttpResponse.json(envelope({ ...match, kickoff_at: '2026-10-31T19:00:00Z' }), { headers: { ETag: '"v2"' } }),
      ),
    );

    const time = screen.getByLabelText('الوقت بتوقيت القاهرة');
    await userEvent.clear(time);
    await userEvent.type(time, '23:00');
    await userEvent.click(saveButton());

    const dialog = await screen.findByRole('alertdialog', { name: 'عدّل يوسف عمر هذا العنصر' });
    expect(dialog).toHaveTextContent('في 18:02 بتوقيت القاهرة');

    await userEvent.click(within(dialog).getByRole('button', { name: 'اعرض التغييرات' }));
    const diff = within(dialog).getByTestId('conflict-diff');
    // Their version, not the editor's own unsaved edit, is what the diff shows.
    expect(within(diff).getByText('19:30')).toHaveAttribute('data-change', 'before');
    expect(within(diff).getByText('21:00')).toHaveAttribute('data-change', 'after');

    await userEvent.click(within(dialog).getByRole('button', { name: 'إعادة التحميل' }));
    await waitFor(() => expect(dialog).not.toBeInTheDocument());
    expect(screen.getByLabelText('الوقت بتوقيت القاهرة')).toHaveValue('21:00');
  });

  it('drops the editor’s own edits on «تجاهل تعديلاتي»', async () => {
    renderEditor();
    await waitForEditor();

    server.use(
      mswHttp.patch('*/admin/api/matches/48213', () =>
        HttpResponse.json(errorBody('edit_conflict', { changed_by: { kind: 'admin', name: 'يوسف عمر' } }), { status: 409 }),
      ),
    );

    const time = screen.getByLabelText('الوقت بتوقيت القاهرة');
    await userEvent.clear(time);
    await userEvent.type(time, '23:00');
    await userEvent.click(saveButton());

    const dialog = await screen.findByRole('alertdialog', { name: 'عدّل يوسف عمر هذا العنصر' });
    await userEvent.click(within(dialog).getByRole('button', { name: 'تجاهل تعديلاتي' }));

    await waitFor(() => expect(dialog).not.toBeInTheDocument());
    expect(screen.getByLabelText('الوقت بتوقيت القاهرة')).toHaveValue('19:30');
    // The 409's message belonged to the edits just dropped, so it goes with them.
    expect(screen.queryByText('عُدّل هذا العنصر من شخص آخر. راجع التغييرات قبل الحفظ')).not.toBeInTheDocument();
  });

  it('saves under the version a changed refetch returned, after «إعادة التحميل»', async () => {
    renderEditor();
    await waitForEditor();

    // Their save changed the stadium, and the refetch that follows the 409 answers with that data at "v4".
    matchBody = { ...match, stadium: 'سان سيرو الجديد' };
    matchEtag = '"v4"';
    server.use(
      mswHttp.patch('*/admin/api/matches/48213', async ({ request }) => {
        patchCalls += 1;
        const body = (await request.json()) as Record<string, unknown>;
        if (patchCalls === 1) {
          return HttpResponse.json(
            errorBody('edit_conflict', {
              changed_at: '2026-10-31T12:00:00Z',
              changed_by: { kind: 'admin', name: 'يوسف عمر' },
            }),
            { status: 409 },
          );
        }
        patched = { body, ifMatch: request.headers.get('If-Match'), bearer: request.headers.get('Authorization') };
        return HttpResponse.json(envelope(matchBody), { headers: { ETag: '"v5"' } });
      }),
    );

    await userEvent.clear(screen.getByLabelText('الملعب'));
    await userEvent.type(screen.getByLabelText('الملعب'), 'سان سيرو 3');
    await userEvent.click(saveButton());

    const dialog = await screen.findByRole('alertdialog');
    await userEvent.click(within(dialog).getByRole('button', { name: 'إعادة التحميل' }));
    await waitFor(() => expect(dialog).not.toBeInTheDocument());

    await userEvent.type(screen.getByLabelText('الملعب'), '!');
    await userEvent.click(saveButton());

    await waitFor(() => expect(patchCalls).toBe(2));
    // The reloaded version, not a version the refetch lost: without it this save is a 428 (A-R2-1).
    expect(patched?.ifMatch).toBe('"v4"');
  });

  it('keeps the version when A4 is reopened from a changed refetch', async () => {
    const router = renderEditor();
    await waitForEditor();

    // A save returns "v2", the invalidation refetches the match with other data at "v3".
    await userEvent.clear(screen.getByLabelText('الملعب'));
    await userEvent.type(screen.getByLabelText('الملعب'), 'سان سيرو 2');
    matchBody = { ...match, stadium: 'سان سيرو 2' };
    matchEtag = '"v3"';
    await userEvent.click(saveButton());
    await waitFor(() => expect(patched?.ifMatch).toBe('"v1"'));

    await router.navigate('/matches');
    expect(await screen.findByText('قائمة المباريات')).toBeInTheDocument();
    await router.navigate('/matches/48213');
    await waitForEditor();

    await userEvent.type(screen.getByLabelText('الملعب'), '!');
    await userEvent.click(saveButton());

    await waitFor(() => expect(patchCalls).toBe(2));
    expect(patched?.ifMatch).toBe('"v3"');
  });

  it('offers no reload, and keeps the edits, when the refetch after a 409 fails', async () => {
    renderEditor();
    await waitForEditor();

    server.use(
      mswHttp.patch('*/admin/api/matches/48213', () =>
        HttpResponse.json(
          errorBody('edit_conflict', {
            changed_at: '2026-10-31T12:00:00Z',
            changed_by: { kind: 'admin', name: 'يوسف عمر' },
          }),
          { status: 409 },
        ),
      ),
      // The version the server holds can't be read: the dialog must not be built from the cache (A-R3-1).
      mswHttp.get('*/admin/api/matches/48213', () => HttpResponse.error()),
    );

    await userEvent.clear(screen.getByLabelText('الوقت بتوقيت القاهرة'));
    await userEvent.type(screen.getByLabelText('الوقت بتوقيت القاهرة'), '23:00');
    await userEvent.click(saveButton());

    expect(
      await screen.findByText('تعذّر الاتصال بالخادم. تأكد من اتصال WireGuard وحاول مرة أخرى'),
    ).toBeInTheDocument();
    expect(screen.queryByRole('alertdialog')).not.toBeInTheDocument();
    // A failed background refetch no longer replaces the editor: the edits are still on screen.
    expect(screen.getByLabelText('الوقت بتوقيت القاهرة')).toHaveValue('23:00');
  });

  it('keeps the edits when Escape closes the conflict dialog', async () => {
    renderEditor();
    await waitForEditor();

    server.use(
      mswHttp.patch('*/admin/api/matches/48213', () =>
        HttpResponse.json(errorBody('edit_conflict', { changed_by: { kind: 'admin', name: 'يوسف عمر' } }), { status: 409 }),
      ),
    );

    await userEvent.clear(screen.getByLabelText('الوقت بتوقيت القاهرة'));
    await userEvent.type(screen.getByLabelText('الوقت بتوقيت القاهرة'), '23:00');
    await userEvent.click(saveButton());

    const dialog = await screen.findByRole('alertdialog');
    await userEvent.keyboard('{Escape}');

    // Escape dismisses the dialog; only «تجاهل تعديلاتي» throws the edits away (A-R2-6).
    await waitFor(() => expect(dialog).not.toBeInTheDocument());
    expect(screen.getByLabelText('الوقت بتوقيت القاهرة')).toHaveValue('23:00');
  });

  it('diffs a score-only conflict with names, and says when their save time is unknown', async () => {
    renderEditor();
    await waitForEditor();

    matchBody = {
      ...match,
      status: {
        status: 'finished',
        status_source: 'manual',
        estimated: false,
        period: null,
        minute: null,
        score: { home: 2, away: 1, home_pen: null, away_pen: null },
        status_label: null,
        status_updated_at: null,
      },
    };
    matchEtag = '"v2"';
    server.use(
      mswHttp.patch('*/admin/api/matches/48213', () =>
        // No `changed_at`: the dialog must not pass the client's clock off as their save time (A-R2-7).
        HttpResponse.json(errorBody('edit_conflict', { changed_by: { kind: 'admin', name: 'يوسف عمر' } }), { status: 409 }),
      ),
    );

    await userEvent.type(screen.getByLabelText('الملعب'), ' ');
    await userEvent.click(saveButton());

    const dialog = await screen.findByRole('alertdialog');
    expect(dialog).toHaveTextContent('في وقت غير معروف');

    await userEvent.click(within(dialog).getByRole('button', { name: 'اعرض التغييرات' }));
    const diff = within(dialog).getByTestId('conflict-diff');
    // A score-only change is a change: the diff names it, with numbers the editor can read (A-R2-7).
    expect(diff).toHaveTextContent('النتيجة');
    expect(diff).toHaveTextContent('2 – 1');
  });

  it('keeps the keyboard inside the rows the picker shows', async () => {
    renderEditor();
    await waitForEditor();

    const many = Array.from({ length: 7 }, (_, index) => ({
      id: 300 + index,
      name: 'الأهلي',
      country: 'مصر',
      logo: null,
      primary_competition: { id: 12, name: 'الدوري الإيطالي' },
      competitions: [{ id: 12, name: 'الدوري الإيطالي' }],
    }));
    server.use(mswHttp.get('*/admin/api/teams', () => HttpResponse.json(envelope(many))));

    const home = screen.getByLabelText('صاحب الأرض');
    await userEvent.clear(home);
    await userEvent.type(home, 'الأهلي');
    await screen.findAllByRole('option', { name: /الأهلي/ });

    // Seven results, five rows: the arrows stop at the fifth, so Enter cannot pick an unseen team (A-R2-8).
    expect(screen.getAllByRole('option', { name: /الأهلي/ })).toHaveLength(5);
    await userEvent.keyboard('{ArrowDown}{ArrowDown}{ArrowDown}{ArrowDown}{ArrowDown}{ArrowDown}{Enter}');

    await userEvent.click(saveButton());
    await waitFor(() => expect(patched).not.toBeNull());
    expect(patched?.body).toMatchObject({ fields: { home: { team_id: 304 } } });
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
    await userEvent.click(saveButton());

    expect(await screen.findByText(message)).toBeInTheDocument();
  });

  it('shows a failed save in Arabic without pretending it stuck', async () => {
    renderEditor();
    await waitForEditor();

    server.use(
      mswHttp.patch('*/admin/api/matches/48213', () => HttpResponse.json(errorBody('internal_error'), { status: 500 })),
    );

    await userEvent.clear(screen.getByLabelText('الوقت بتوقيت القاهرة'));
    await userEvent.type(screen.getByLabelText('الوقت بتوقيت القاهرة'), '21:00');
    await userEvent.click(saveButton());

    expect(await screen.findByText('حدث خطأ في الخادم. حاول مرة أخرى بعد قليل')).toBeInTheDocument();
    expect(screen.queryByText('تم الحفظ')).not.toBeInTheDocument();
  });

  it('keeps one failed-save toast per editor, and takes it away when the editor closes', async () => {
    const router = renderEditor();
    await waitForEditor();

    server.use(
      mswHttp.patch('*/admin/api/matches/48213', () => HttpResponse.json(errorBody('internal_error'), { status: 500 })),
    );

    await userEvent.clear(screen.getByLabelText('الوقت بتوقيت القاهرة'));
    await userEvent.type(screen.getByLabelText('الوقت بتوقيت القاهرة'), '21:00');
    await userEvent.click(saveButton());
    expect(await screen.findByText('فشل الحفظ')).toBeInTheDocument();

    // A second failure replaces the first toast instead of stacking another.
    await userEvent.click(saveButton());
    await waitFor(() => expect(screen.getAllByText('فشل الحفظ')).toHaveLength(1));

    await router.navigate('/matches');
    const guard = await screen.findByRole('alertdialog', { name: 'لديك تغييرات غير محفوظة' });
    await userEvent.click(within(guard).getByRole('button', { name: 'غادر دون حفظ' }));

    expect(await screen.findByText('قائمة المباريات')).toBeInTheDocument();
    expect(screen.queryByText('فشل الحفظ')).not.toBeInTheDocument();
  });

  it('blocks leaving with unsaved changes, and says «ابقَ» and «احفظ وغادر»', async () => {
    const router = renderEditor();
    await waitForEditor();

    await userEvent.clear(screen.getByLabelText('الملعب'));
    await userEvent.type(screen.getByLabelText('الملعب'), 'سان سيرو 2');

    await router.navigate('/matches');

    const dialog = await screen.findByRole('alertdialog', { name: 'لديك تغييرات غير محفوظة' });
    expect(within(dialog).getByRole('button', { name: 'ابقَ' })).toBeInTheDocument();

    // «ابقَ» stays on A4 with the edits.
    await userEvent.click(within(dialog).getByRole('button', { name: 'ابقَ' }));
    expect(router.state.location.pathname).toBe('/matches/48213');
    expect(screen.getByLabelText('الملعب')).toHaveValue('سان سيرو 2');
  });

  it('leaves for where the editor was going once «احفظ وغادر» sticks', async () => {
    const router = renderEditor();
    await waitForEditor();

    await userEvent.clear(screen.getByLabelText('الملعب'));
    await userEvent.type(screen.getByLabelText('الملعب'), 'سان سيرو 2');
    await router.navigate('/channels');

    const dialog = await screen.findByRole('alertdialog', { name: 'لديك تغييرات غير محفوظة' });
    await userEvent.click(within(dialog).getByRole('button', { name: 'احفظ وغادر' }));

    await waitFor(() => expect(patched?.body).toMatchObject({ fields: { stadium: 'سان سيرو 2' } }));
    await waitFor(() => expect(router.state.location.pathname).toBe('/channels'));
  });

  it('stays on A4 when «احفظ وغادر» fails', async () => {
    const router = renderEditor();
    await waitForEditor();
    server.use(
      mswHttp.patch('*/admin/api/matches/48213', () => HttpResponse.json(errorBody('internal_error'), { status: 500 })),
    );

    await userEvent.clear(screen.getByLabelText('الملعب'));
    await userEvent.type(screen.getByLabelText('الملعب'), 'سان سيرو 2');
    await router.navigate('/channels');

    const dialog = await screen.findByRole('alertdialog', { name: 'لديك تغييرات غير محفوظة' });
    await userEvent.click(within(dialog).getByRole('button', { name: 'احفظ وغادر' }));

    await waitFor(() => expect(dialog).not.toBeInTheDocument());
    expect(router.state.location.pathname).toBe('/matches/48213');
  });

  it('asks the browser to confirm a reload while there are unsaved changes', async () => {
    renderEditor();
    await waitForEditor();

    const before = new Event('beforeunload', { cancelable: true });
    window.dispatchEvent(before);
    expect(before.defaultPrevented).toBe(false);

    await userEvent.clear(screen.getByLabelText('الملعب'));
    await userEvent.type(screen.getByLabelText('الملعب'), 'سان سيرو 2');

    const after = new Event('beforeunload', { cancelable: true });
    window.dispatchEvent(after);
    expect(after.defaultPrevented).toBe(true);
  });

  it('shows a skeleton while loading, and an error state on 404', async () => {
    serveMatchData();
    server.use(
      mswHttp.get('*/admin/api/matches/48213', () =>
        HttpResponse.json(errorBody('match_not_found'), { status: 404 }),
      ),
    );
    const router = createMemoryRouter([{ path: '/matches/:id', element: <MatchEditor /> }], {
      initialEntries: ['/matches/48213'],
    });
    renderRtl(<RouterProvider router={router} />, { withRouter: false, wrapper: Providers });

    expect(screen.getByTestId('editor-skeleton')).toBeInTheDocument();
    expect(await screen.findByText('هذه المباراة غير موجودة. ربما حُذفت')).toBeInTheDocument();
    // An empty editor with Save enabled would let the editor publish a blank match.
    expect(screen.queryByRole('button', { name: 'حفظ' })).not.toBeInTheDocument();
  });

  it('treats a non-numeric id as not found', async () => {
    serveMatchData();
    const router = createMemoryRouter([{ path: '/matches/:id', element: <MatchEditor /> }], {
      initialEntries: ['/matches/abc'],
    });
    renderRtl(<RouterProvider router={router} />, { withRouter: false, wrapper: Providers });

    expect(await screen.findByText('هذه المباراة غير موجودة. ربما حُذفت')).toBeInTheDocument();
  });

  it('creates a match from «إضافة مباراة» with a typed body, then opens it', async () => {
    const router = renderNewEditor();

    await userEvent.type(screen.getByLabelText('صاحب الأرض'), 'ميلان');
    await userEvent.click((await screen.findAllByRole('option', { name: /ميلان/ }))[0] as HTMLElement);
    await userEvent.type(screen.getByLabelText('الضيف'), 'بولونيا');
    await userEvent.click((await screen.findAllByRole('option', { name: /بولونيا/ }))[0] as HTMLElement);
    await userEvent.selectOptions(screen.getByLabelText('البطولة'), '12');
    await userEvent.type(screen.getByLabelText('الوقت بتوقيت القاهرة'), '20:00');

    await userEvent.click(screen.getByRole('button', { name: 'حفظ' }));

    await waitFor(() => expect(created).not.toBeNull());
    expect(created?.body).toMatchObject({
      match_date: expect.stringMatching(/^\d{4}-\d{2}-\d{2}$/),
      home: { team_id: 101 },
      away: { team_id: 102 },
      competition_id: 12,
      kickoff_at: expect.any(String),
    });
    await waitFor(() => expect(router.state.location.pathname).toBe('/matches/48299'));
  });
});
