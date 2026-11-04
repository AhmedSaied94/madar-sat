import { screen, waitFor, within } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { HttpResponse, http as mswHttp } from 'msw';
import type { ReactElement, ReactNode } from 'react';
import { describe, expect, it, vi } from 'vitest';

import { ToastProvider } from '../../components/Toast/Toast';
import { renderRtl } from '../../test/render';
import { server } from '../../test/server';
import { RightsHoldersPage } from './RightsHoldersPage';
import { rightsHolderBodySchema } from './RightsHolderEditor';

const role = vi.hoisted(() => ({ current: 'editor' as 'admin' | 'editor' }));

vi.mock('../auth/session', () => ({
  useSession: () => ({
    session: {
      access_token: 'token',
      expires_in: 900,
      token_type: 'Bearer',
      admin: { id: 1, name: 'سارة حسن', email: 'sara@example.com', role: role.current },
    },
    restoring: false,
    signIn: () => undefined,
    signOut: () => undefined,
  }),
}));

const envelope = (data: unknown, meta: Record<string, unknown> = {}): Record<string, unknown> => ({
  success: true,
  data,
  error: null,
  meta,
});

const rows = [
  {
    id: 3,
    name: 'beIN SPORTS',
    logo: 'https://media.example/bein.svg',
    competitions: ['الدوري الإنجليزي الممتاز', 'الدوري الإسباني', 'دوري أبطال أوروبا', 'دوري أبطال أفريقيا'],
    satellites: ['نايل سات', 'بدر'],
    sort_order: 1,
    etag: '"r-3"',
  },
  {
    id: 4,
    name: 'ON Sport',
    logo: null,
    competitions: ['الدوري المصري'],
    satellites: ['نايل سات'],
    sort_order: 2,
    etag: '"r-4"',
  },
];

const detail = {
  id: 3,
  name: 'beIN SPORTS',
  logo: 'https://media.example/bein.svg',
  logo_asset_id: 77,
  sort_order: 1,
  etag: '"r-3"',
  competition_ids: [12],
  carriages: [
    {
      access: 'encrypted',
      beam: 'wide',
      package: 'beIN',
      satellite_ids: [3],
      frequencies: [{ frequency_mhz: 11054, polarization: 'H', symbol_rate: 27500, is_primary: true }],
    },
  ],
};

const competitions = [
  { id: 12, name: 'الدوري الإنجليزي الممتاز', logo: null, logo_asset_id: null, sport: 'football', priority: 1, etag: '"c-12"' },
  { id: 14, name: 'الدوري الإسباني', logo: null, logo_asset_id: null, sport: 'football', priority: 2, etag: '"c-14"' },
];

const satellites = [
  {
    id: 3,
    name_ar: 'نايل سات',
    name_en: 'Nilesat',
    slug: 'nilesat',
    kind: 'satellite',
    logo: null,
    logo_asset_id: null,
    orbital_position: 7,
    priority: 1,
    reception_url: null,
    best_frequency: null,
    worst_frequency: null,
    etag: '"s-3"',
  },
  {
    id: 4,
    name_ar: 'بدر',
    name_en: 'Badr',
    slug: 'badr',
    kind: 'satellite',
    logo: null,
    logo_asset_id: null,
    orbital_position: 26,
    priority: 2,
    reception_url: null,
    best_frequency: null,
    worst_frequency: null,
    etag: '"s-4"',
  },
];

function serve(list: unknown[] = rows): void {
  server.use(
    mswHttp.get('*/admin/api/rights-holders', () => HttpResponse.json(envelope(list), { headers: { ETag: '"r-1"' } })),
    mswHttp.get('*/admin/api/rights-holders/:id', () =>
      HttpResponse.json(envelope(detail), { headers: { ETag: '"r-3"' } }),
    ),
    mswHttp.get('*/admin/api/competitions', () => HttpResponse.json(envelope(competitions))),
    mswHttp.get('*/admin/api/satellites', () => HttpResponse.json(envelope(satellites))),
  );
}

function Providers({ children }: { children: ReactNode }): ReactElement {
  return <ToastProvider>{children}</ToastProvider>;
}

function renderPage(): void {
  serve();
  renderRtl(<RightsHoldersPage />, { wrapper: Providers });
}

describe('RightsHoldersPage (A9)', () => {
  it('lists the holders in order with their competitions and satellites', async () => {
    renderPage();

    const first = await screen.findByTestId('rights-holder-3');
    expect(within(first).getByText('beIN SPORTS')).toHaveAttribute('dir', 'ltr');
    expect(
      within(first).getByText('الدوري الإنجليزي الممتاز · الدوري الإسباني · دوري أبطال أوروبا'),
    ).toBeInTheDocument();
    expect(within(first).getByText('+1')).toBeInTheDocument();
    expect(within(first).getByText('نايل سات · بدر')).toBeInTheDocument();

    expect(screen.getByText('2 جهة · الترتيب يحدد العرض في التطبيق')).toBeInTheDocument();
  });

  it('shows the loading, empty and failed states', async () => {
    let release: (() => void) | undefined;
    const gate = new Promise<void>((done) => {
      release = done;
    });
    server.use(
      mswHttp.get('*/admin/api/rights-holders', async () => {
        await gate;
        return HttpResponse.json(envelope([]));
      }),
      mswHttp.get('*/admin/api/competitions', () => HttpResponse.json(envelope([]))),
      mswHttp.get('*/admin/api/satellites', () => HttpResponse.json(envelope([]))),
    );
    const view = renderRtl(<RightsHoldersPage />, { wrapper: Providers });
    expect(screen.getByText('جارٍ تحميل الجهات')).toBeInTheDocument();
    release?.();
    expect(await screen.findByText('لا جهات بعد')).toBeInTheDocument();

    view.unmount();
    server.use(
      mswHttp.get('*/admin/api/rights-holders', () =>
        HttpResponse.json(
          { success: false, data: null, error: { code: 'internal_error', message: 'boom' }, meta: {} },
          { status: 500 },
        ),
      ),
    );
    renderRtl(<RightsHoldersPage />, { wrapper: Providers });
    expect(await screen.findByText('حدث خطأ في الخادم. حاول مرة أخرى بعد قليل')).toBeInTheDocument();
  });

  it('saves a new order from the keyboard, each row under the version it read', async () => {
    let body: unknown = null;
    renderPage();
    await screen.findByTestId('rights-holder-3');

    server.use(
      mswHttp.post('*/admin/api/rights-holders/reorder', async ({ request }) => {
        body = await request.json();
        return HttpResponse.json(envelope({ updated: [] }));
      }),
    );

    const handle = screen.getByRole('button', { name: 'اسحب beIN SPORTS لإعادة الترتيب' });
    handle.focus();
    await userEvent.keyboard(' ');
    await userEvent.keyboard('{ArrowDown}');
    await userEvent.keyboard(' ');

    await waitFor(() => expect(body).not.toBeNull());
    expect(body).toEqual({
      items: [
        { id: 4, if_match: '"r-4"' },
        { id: 3, if_match: '"r-3"' },
      ],
    });
  });

  it('creates a holder with its competitions, carriage, satellite and frequencies', async () => {
    let body: unknown = null;
    renderPage();
    await screen.findByTestId('rights-holder-3');

    server.use(
      mswHttp.post('*/admin/api/rights-holders', async ({ request }) => {
        body = await request.json();
        return HttpResponse.json(envelope({ ...detail, id: 9 }), { status: 201 });
      }),
    );

    await userEvent.click(screen.getByRole('button', { name: 'جهة جديدة' }));
    const drawer = await screen.findByRole('dialog', { name: 'جهة جديدة' });

    await userEvent.type(within(drawer).getByLabelText('اسم الجهة'), 'Eleven Sports');
    await userEvent.click(within(drawer).getByRole('checkbox', { name: 'الدوري الإسباني' }));

    await userEvent.click(within(drawer).getByRole('button', { name: 'قمر آخر' }));
    await userEvent.selectOptions(within(drawer).getByLabelText('القمر'), '3');
    await userEvent.selectOptions(within(drawer).getByLabelText('الوصول'), 'encrypted');
    await userEvent.selectOptions(within(drawer).getByLabelText('الحزمة'), 'wide');
    await userEvent.type(within(drawer).getByLabelText('الباقة'), 'beIN');

    await userEvent.click(within(drawer).getByRole('button', { name: 'تردد' }));
    await userEvent.type(within(drawer).getByLabelText('التردد · MHz'), '11054');
    await userEvent.type(within(drawer).getByLabelText('التردد · symbol rate'), '27500');
    await userEvent.click(within(drawer).getByRole('radio', { name: 'H' }));
    await userEvent.click(within(drawer).getByRole('radio', { name: 'تردد أساسي' }));

    await userEvent.click(within(drawer).getByRole('button', { name: 'حفظ' }));

    await waitFor(() => expect(body).not.toBeNull());
    expect(body).toEqual({
      name: 'Eleven Sports',
      competition_ids: [14],
      carriages: [
        {
          access: 'encrypted',
          beam: 'wide',
          package: 'beIN',
          satellite_ids: [3],
          frequencies: [{ frequency_mhz: 11054, polarization: 'H', symbol_rate: 27500, is_primary: true }],
        },
      ],
    });
  });

  it('refuses a carriage with no primary frequency before sending anything', async () => {
    let posted = false;
    renderPage();
    await screen.findByTestId('rights-holder-3');

    server.use(
      mswHttp.post('*/admin/api/rights-holders', () => {
        posted = true;
        return HttpResponse.json(envelope({ ...detail, id: 9 }), { status: 201 });
      }),
    );

    await userEvent.click(screen.getByRole('button', { name: 'جهة جديدة' }));
    const drawer = await screen.findByRole('dialog', { name: 'جهة جديدة' });
    await userEvent.type(within(drawer).getByLabelText('اسم الجهة'), 'Eleven Sports');
    await userEvent.click(within(drawer).getByRole('button', { name: 'قمر آخر' }));
    await userEvent.selectOptions(within(drawer).getByLabelText('القمر'), '3');
    await userEvent.click(within(drawer).getByRole('button', { name: 'تردد' }));
    await userEvent.type(within(drawer).getByLabelText('التردد · MHz'), '11054');
    await userEvent.type(within(drawer).getByLabelText('التردد · symbol rate'), '27500');

    await userEvent.click(within(drawer).getByRole('button', { name: 'حفظ' }));

    expect(await within(drawer).findByText('اختر تردداً أساسياً في كل قمر')).toBeInTheDocument();
    expect(posted).toBe(false);
  });

  it('refuses two primary frequencies in one carriage at the schema', () => {
    const first = { frequency_mhz: 11054, polarization: 'H' as const, symbol_rate: 27500, is_primary: true };
    const second = { frequency_mhz: 11013, polarization: 'H' as const, symbol_rate: 27500, is_primary: true };
    const body = (frequencies: (typeof first)[]) => ({
      name: 'Eleven Sports',
      competition_ids: [],
      carriages: [{ access: 'encrypted' as const, satellite_ids: [3], frequencies }],
    });

    expect(rightsHolderBodySchema.safeParse(body([first, second])).success).toBe(false);
    expect(rightsHolderBodySchema.safeParse(body([{ ...first, is_primary: false }])).success).toBe(false);
    expect(rightsHolderBodySchema.safeParse(body([first])).success).toBe(true);
  });

  it('shows the frequency as an LTR island in the editor', async () => {
    renderPage();
    const row = await screen.findByTestId('rights-holder-3');

    await userEvent.click(within(row).getByRole('button', { name: 'تعديل beIN SPORTS' }));
    const drawer = await screen.findByRole('dialog', { name: 'تعديل «beIN SPORTS»' });

    const mhz = await within(drawer).findByLabelText('التردد · MHz');
    expect(mhz).toHaveValue('11054');
    expect(mhz.closest('[dir="ltr"]')).not.toBeNull();
    expect(within(drawer).getByLabelText('الباقة')).toHaveValue('beIN');
  });

  it('shows the conflict copy when the version it read is stale', async () => {
    renderPage();
    const row = await screen.findByTestId('rights-holder-3');
    server.use(
      mswHttp.patch('*/admin/api/rights-holders/:id', () =>
        HttpResponse.json(
          { success: false, data: null, error: { code: 'edit_conflict', message: 'moved' }, meta: {} },
          { status: 409 },
        ),
      ),
    );

    await userEvent.click(within(row).getByRole('button', { name: 'تعديل beIN SPORTS' }));
    const drawer = await screen.findByRole('dialog', { name: 'تعديل «beIN SPORTS»' });
    await userEvent.clear(within(drawer).getByLabelText('اسم الجهة'));
    await userEvent.type(within(drawer).getByLabelText('اسم الجهة'), 'beIN SPORTS MENA');
    await userEvent.click(within(drawer).getByRole('button', { name: 'حفظ' }));

    expect(
      await within(drawer).findByText('عُدّل هذا العنصر من شخص آخر. راجع التغييرات قبل الحفظ'),
    ).toBeInTheDocument();
  });

  it('offers delete to an admin only, under the row version', async () => {
    let deleted: number | null = null;
    let ifMatch: string | null = null;
    role.current = 'editor';
    renderPage();
    const row = await screen.findByTestId('rights-holder-3');
    expect(within(row).queryByRole('button', { name: 'حذف beIN SPORTS' })).not.toBeInTheDocument();

    role.current = 'admin';
    const adminView = renderRtl(<RightsHoldersPage />, { wrapper: Providers });
    const adminRow = await within(adminView.container).findByTestId('rights-holder-3');

    server.use(
      mswHttp.delete('*/admin/api/rights-holders/:id', ({ params, request }) => {
        deleted = Number(params['id']);
        ifMatch = request.headers.get('If-Match');
        return HttpResponse.json(envelope(null));
      }),
    );

    await userEvent.click(within(adminRow).getByRole('button', { name: 'حذف beIN SPORTS' }));
    const dialog = await screen.findByRole('alertdialog', { name: 'حذف الجهة' });
    await userEvent.click(within(dialog).getByRole('button', { name: 'حذف' }));

    await waitFor(() => expect(deleted).toBe(3));
    expect(ifMatch).toBe('"r-3"');
  });
});
