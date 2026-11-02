import { screen, waitFor, within } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { HttpResponse, http as mswHttp } from 'msw';
import type { ReactElement, ReactNode } from 'react';
import { describe, expect, it } from 'vitest';

import { ToastProvider } from '../../components/Toast/Toast';
import { renderRtl } from '../../test/render';
import { server } from '../../test/server';
import { TeamsPage } from './TeamsPage';

const envelope = (data: unknown, meta: Record<string, unknown> = {}): Record<string, unknown> => ({
  success: true,
  data,
  error: null,
  meta,
});

const competitions = [
  { id: 12, sport: 'football', name: 'الدوري المصري الممتاز', logo: null, logo_asset_id: null, priority: 3, etag: '"c-12"' },
  { id: 40, sport: 'football', name: 'دوري أبطال آسيا 2', logo: null, logo_asset_id: null, priority: 5, etag: '"c-40"' },
];

const teamRows = [
  {
    id: 7,
    name: 'الأهلي',
    logo: null,
    country: 'EG',
    primary_competition: { id: 12, name: 'الدوري المصري الممتاز' },
    competitions: [{ id: 12, name: 'الدوري المصري الممتاز' }],
  },
  {
    id: 8,
    name: 'الزمالك',
    logo: null,
    country: 'EG',
    primary_competition: null,
    competitions: [],
  },
];

const teamDetail = (overrides: Record<string, unknown> = {}): Record<string, unknown> => ({
  id: 7,
  name: 'الأهلي',
  logo: null,
  logo_asset_id: null,
  country: 'EG',
  stadium: 'استاد القاهرة',
  primary_competition_id: 12,
  competition_ids: [12],
  sport: 'football',
  external_ids: [{ source: 'ysscores', external_id: '1191' }],
  ...overrides,
});

const listRequests: URL[] = [];

function serveTeams(): void {
  listRequests.length = 0;
  server.use(
    mswHttp.get('*/admin/api/teams', ({ request }) => {
      listRequests.push(new URL(request.url));
      return HttpResponse.json(envelope(teamRows, { count: teamRows.length }));
    }),
    mswHttp.get('*/admin/api/teams/:id', () =>
      HttpResponse.json(envelope(teamDetail()), { headers: { ETag: '"team-7"' } }),
    ),
    mswHttp.get('*/admin/api/competitions', () => HttpResponse.json(envelope(competitions))),
  );
}

function Providers({ children }: { children: ReactNode }): ReactElement {
  return <ToastProvider>{children}</ToastProvider>;
}

function renderPage() {
  serveTeams();
  return renderRtl(<TeamsPage />, { wrapper: Providers });
}

const waitForRows = () => screen.findByText('الأهلي');

describe('TeamsPage (A5)', () => {
  it('sends the search, competition and missing-logo filters', async () => {
    renderPage();
    await waitForRows();

    await userEvent.type(screen.getByLabelText('ابحث في الفرق'), 'الاهلي');
    await userEvent.selectOptions(screen.getByLabelText('البطولة'), '40');
    await userEvent.click(screen.getByRole('button', { name: 'بلا شعار' }));

    await waitFor(() => {
      const url = listRequests.at(-1);
      expect(url?.searchParams.get('q')).toBe('الاهلي');
      expect(url?.searchParams.get('competition_id')).toBe('40');
      expect(url?.searchParams.get('missing_logo')).toBe('true');
    });
  });

  it('lists the team with its main and other competitions', async () => {
    renderPage();

    const row = (await screen.findByText('الأهلي')).closest('tr');
    if (!row) throw new Error('expected a row');
    expect(row).toHaveTextContent('الدوري المصري الممتاز');
    expect(screen.getByText('الزمالك')).toBeInTheDocument();
  });

  it('saves the changed fields of a team under the version it loaded', async () => {
    let sent: Record<string, unknown> | null = null;
    let ifMatch: string | null = null;
    renderPage();
    await waitForRows();

    server.use(
      mswHttp.patch('*/admin/api/teams/:id', async ({ request }) => {
        ifMatch = request.headers.get('If-Match');
        sent = (await request.json()) as Record<string, unknown>;
        return HttpResponse.json(envelope(teamDetail({ name: 'الأهلي الأحمر' })), { headers: { ETag: '"team-8"' } });
      }),
    );

    await userEvent.click(screen.getByRole('button', { name: 'تعديل الأهلي' }));
    const drawer = await screen.findByRole('dialog', { name: 'تعديل الفريق' });
    const name = within(drawer).getByLabelText('اسم الفريق');
    await userEvent.clear(name);
    await userEvent.type(name, 'الأهلي الأحمر');
    await userEvent.click(within(drawer).getByRole('button', { name: 'حفظ' }));

    await waitFor(() => expect(sent).not.toBeNull());
    expect(sent).toMatchObject({ name: 'الأهلي الأحمر' });
    // Only what changed travels, and it travels under the version the editor loaded.
    expect(sent).not.toHaveProperty('stadium');
    expect(ifMatch).toBe('"team-7"');
  });

  it('refuses a team with no name, with the field error and without sending', async () => {
    const patches: string[] = [];
    renderPage();
    await waitForRows();

    server.use(
      mswHttp.patch('*/admin/api/teams/:id', async ({ request }) => {
        patches.push(request.url);
        return HttpResponse.json(envelope(teamDetail()), { headers: { ETag: '"team-8"' } });
      }),
    );

    await userEvent.click(screen.getByRole('button', { name: 'تعديل الأهلي' }));
    const drawer = await screen.findByRole('dialog', { name: 'تعديل الفريق' });
    await userEvent.clear(within(drawer).getByLabelText('اسم الفريق'));
    await userEvent.click(within(drawer).getByRole('button', { name: 'حفظ' }));

    expect(await within(drawer).findByText('هذا الحقل مطلوب')).toBeInTheDocument();
    expect(patches).toHaveLength(0);
  });

  it('creates a team from an empty editor', async () => {
    let sent: Record<string, unknown> | null = null;
    renderPage();
    await waitForRows();

    server.use(
      mswHttp.post('*/admin/api/teams', async ({ request }) => {
        sent = (await request.json()) as Record<string, unknown>;
        return HttpResponse.json(envelope(teamDetail({ id: 9, name: 'بيراميدز' })), { status: 201 });
      }),
    );

    await userEvent.click(screen.getByRole('button', { name: 'فريق جديد' }));
    const drawer = await screen.findByRole('dialog', { name: 'فريق جديد' });
    await userEvent.type(within(drawer).getByLabelText('اسم الفريق'), 'بيراميدز');
    await userEvent.selectOptions(within(drawer).getByLabelText('البطولة الرئيسية'), '40');
    await userEvent.click(within(drawer).getByRole('button', { name: 'حفظ' }));

    await waitFor(() => expect(sent).not.toBeNull());
    expect(sent).toMatchObject({ name: 'بيراميدز', primary_competition_id: 40 });
  });

  it('shows the other version on a 409 and adopts it on reload', async () => {
    renderPage();
    await waitForRows();

    server.use(
      mswHttp.patch('*/admin/api/teams/:id', () =>
        HttpResponse.json(
          {
            success: false,
            data: null,
            error: { code: 'edit_conflict', message: 'x' },
            meta: { changed_by: { kind: 'admin', name: 'سارة' }, changed_at: '2026-11-01T09:30:00Z' },
          },
          { status: 409 },
        ),
      ),
    );

    await userEvent.click(screen.getByRole('button', { name: 'تعديل الأهلي' }));
    const drawer = await screen.findByRole('dialog', { name: 'تعديل الفريق' });
    const name = within(drawer).getByLabelText('اسم الفريق');
    await userEvent.clear(name);
    await userEvent.type(name, 'اسمي');

    // Their save lands after this editor loaded: the refetch on the 409 is the first time this screen
    // sees it.
    server.use(
      mswHttp.get('*/admin/api/teams/:id', () =>
        HttpResponse.json(envelope(teamDetail({ name: 'الأهلي الجديد' })), { headers: { ETag: '"team-9"' } }),
      ),
    );
    await userEvent.click(within(drawer).getByRole('button', { name: 'حفظ' }));

    const dialog = await screen.findByRole('alertdialog', { name: /عدّل سارة هذا العنصر/ });
    await userEvent.click(within(dialog).getByRole('button', { name: 'اعرض التغييرات' }));
    expect(within(dialog).getByText('الأهلي الجديد')).toBeInTheDocument();

    await userEvent.click(within(dialog).getByRole('button', { name: 'إعادة التحميل' }));
    expect(within(drawer).getByLabelText('اسم الفريق')).toHaveValue('الأهلي الجديد');
  });

  it('previews the chosen logo on a dark and on a light tile', async () => {
    renderPage();
    await waitForRows();

    await userEvent.click(screen.getByRole('button', { name: 'تعديل الأهلي' }));
    const drawer = await screen.findByRole('dialog', { name: 'تعديل الفريق' });

    await userEvent.upload(
      within(drawer).getByLabelText('رفع شعار'),
      new File(['crest'], 'crest.png', { type: 'image/png' }),
    );

    const dark = await within(drawer).findByTestId('logo-tile-dark');
    const light = within(drawer).getByTestId('logo-tile-light');

    // Both grounds, each in its own theme, with the same artwork (T095, A-R1-6).
    expect(dark).toHaveAttribute('data-theme', 'dark');
    expect(light).toHaveAttribute('data-theme', 'light');
    for (const tile of [dark, light]) {
      expect(tile.querySelector('img')?.getAttribute('src')).toBe('https://media.example/logo/cd/cd34.webp');
    }
    expect(within(drawer).getByText('على خلفية داكنة')).toBeInTheDocument();
    expect(within(drawer).getByText('على خلفية فاتحة')).toBeInTheDocument();
  });

  it('asks before dropping unsaved edits', async () => {
    renderPage();
    await waitForRows();

    await userEvent.click(screen.getByRole('button', { name: 'تعديل الأهلي' }));
    const drawer = await screen.findByRole('dialog', { name: 'تعديل الفريق' });
    await userEvent.type(within(drawer).getByLabelText('اسم الفريق'), ' جديد');

    await userEvent.click(within(drawer).getByRole('button', { name: 'إغلاق' }));
    const guard = await screen.findByRole('alertdialog', { name: 'لديك تغييرات غير محفوظة' });

    await userEvent.click(within(guard).getByRole('button', { name: 'ابقَ' }));
    expect(screen.getByRole('dialog', { name: 'تعديل الفريق' })).toBeInTheDocument();
  });
});
