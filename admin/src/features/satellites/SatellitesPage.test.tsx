import { screen, waitFor, within } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { HttpResponse, http as mswHttp } from 'msw';
import type { ReactElement, ReactNode } from 'react';
import { describe, expect, it } from 'vitest';

import { ToastProvider } from '../../components/Toast/Toast';
import { renderRtl } from '../../test/render';
import { server } from '../../test/server';
import { SatellitesPage } from './SatellitesPage';

const envelope = (data: unknown): Record<string, unknown> => ({ success: true, data, error: null, meta: {} });

const satellites = [
  {
    id: 2,
    slug: 'nilesat',
    kind: 'satellite',
    name_en: 'Nilesat 7.0W',
    name_ar: 'نايل سات',
    orbital_position: -7,
    logo: null,
    logo_asset_id: null,
    best_frequency: { mhz: 12054, pol: 'V', sr: 27500 },
    worst_frequency: { mhz: 11373, pol: 'H', sr: 27500 },
    reception_url: 'https://youtu.be/nilesat',
    priority: 1,
  },
  {
    id: 9,
    slug: 'astra',
    kind: 'satellite',
    name_en: 'Astra 19.2E',
    name_ar: 'استرا 19',
    orbital_position: 19.2,
    logo: null,
    logo_asset_id: null,
    best_frequency: null,
    worst_frequency: null,
    reception_url: null,
    priority: 2,
  },
];

const etagOfRow = (id: number): string => `"sat-${String(id)}"`;

function serve(): void {
  server.use(
    mswHttp.get('*/admin/api/satellites', () => HttpResponse.json(envelope(satellites))),
    mswHttp.get('*/admin/api/satellites/:id', ({ params }) => {
      const row = satellites.find((satellite) => satellite.id === Number(params['id']));
      return HttpResponse.json(envelope(row), { headers: { ETag: etagOfRow(Number(params['id'])) } });
    }),
  );
}

function Providers({ children }: { children: ReactNode }): ReactElement {
  return <ToastProvider>{children}</ToastProvider>;
}

function renderPage() {
  serve();
  return renderRtl(<SatellitesPage />, { wrapper: Providers });
}

async function keyboardReorder(): Promise<void> {
  const handle = screen.getAllByRole('button', { name: /إعادة الترتيب$/ })[0];
  if (!handle) throw new Error('expected a handle');
  handle.focus();
  await userEvent.keyboard('[Space]');
  await userEvent.keyboard('[ArrowDown]');
  await userEvent.keyboard('[Space]');
}

describe('SatellitesPage (A7)', () => {
  it('lists the satellites in order with their position readout and the missing-frequency mark', async () => {
    renderPage();

    expect(await screen.findByText('نايل سات')).toBeInTheDocument();
    const items = screen.getAllByRole('listitem');
    expect(items[0]).toHaveTextContent('7.0W');
    expect(items[0]).toHaveTextContent('Nilesat 7.0W');
    expect(items[1]).toHaveTextContent('19.2E');
    expect(items[1]).toHaveTextContent('بلا أقوى/أضعف تردد');
  });

  it('prints the orbital position in the dark readout well, LTR (A-R1-8)', async () => {
    renderPage();
    await screen.findByText('نايل سات');

    const readout = screen.getAllByTestId('frequency-readout')[0];
    if (!readout) throw new Error('expected a readout');
    expect(readout).toHaveAttribute('dir', 'ltr');
    expect(readout).toHaveClass('bg-readout-bg', 'text-readout');
    expect(readout).toHaveTextContent('7.0W');
  });

  it('refuses a reception link that is not https, and sends nothing', async () => {
    const patches: string[] = [];
    renderPage();
    await screen.findByText('نايل سات');

    server.use(
      mswHttp.patch('*/admin/api/satellites/:id', async ({ request }) => {
        patches.push(request.url);
        return HttpResponse.json(envelope(satellites[0]), { headers: { ETag: '"sat-2b"' } });
      }),
    );

    await userEvent.click(screen.getByRole('button', { name: 'تعديل نايل سات' }));
    const drawer = await screen.findByRole('dialog', { name: 'تعديل القمر' });
    const reception = within(drawer).getByLabelText('فيديو طريقة الاستقبال');
    await userEvent.clear(reception);
    await userEvent.type(reception, 'http://youtube.com/watch?v=1');
    await userEvent.click(within(drawer).getByRole('button', { name: 'حفظ' }));

    // The refusal comes from the contract's own regex, on the field, and the form sends nothing.
    expect(await within(drawer).findByText('أدخل رابطاً يبدأ بـ https://')).toBeInTheDocument();
    expect(patches).toHaveLength(0);
  });

  it('saves a frequency change under the version it loaded, leaving the untouched fields out', async () => {
    let sent: Record<string, unknown> | null = null;
    let ifMatch: string | null = null;
    renderPage();
    await screen.findByText('نايل سات');

    server.use(
      mswHttp.patch('*/admin/api/satellites/:id', async ({ request }) => {
        ifMatch = request.headers.get('If-Match');
        sent = (await request.json()) as Record<string, unknown>;
        return HttpResponse.json(envelope(satellites[0]), { headers: { ETag: '"sat-2b"' } });
      }),
    );

    await userEvent.click(screen.getByRole('button', { name: 'تعديل نايل سات' }));
    const drawer = await screen.findByRole('dialog', { name: 'تعديل القمر' });
    const best = within(drawer).getByLabelText('أقوى تردد · MHz');
    await userEvent.clear(best);
    await userEvent.type(best, '12092');
    await userEvent.click(within(drawer).getByRole('radio', { name: 'H', checked: false }));
    await userEvent.click(within(drawer).getByRole('button', { name: 'حفظ' }));

    await waitFor(() => expect(sent).not.toBeNull());
    expect(sent).toEqual({ best_frequency: { mhz: 12092, pol: 'H', sr: 27500 } });
    expect(ifMatch).toBe('"sat-2"');
  });

  it('saves the new order with each row version when the keyboard moves a row', async () => {
    let sent: Record<string, unknown> | null = null;
    renderPage();
    await screen.findByText('نايل سات');

    server.use(
      mswHttp.put('*/admin/api/satellites/order', async ({ request }) => {
        sent = (await request.json()) as Record<string, unknown>;
        return HttpResponse.json(envelope({ updated: [] }));
      }),
    );

    await keyboardReorder();

    await waitFor(() => expect(sent).not.toBeNull());
    expect(sent).toMatchObject({
      items: [
        { id: 9, if_match: '"sat-9"' },
        { id: 2, if_match: '"sat-2"' },
      ],
    });
  });

  it('opens the conflict dialog when the order it saw is stale, and reloads', async () => {
    let listReads = 0;
    renderPage();
    await screen.findByText('نايل سات');
    listReads = 0;

    server.use(
      mswHttp.get('*/admin/api/satellites', () => {
        listReads += 1;
        return HttpResponse.json(envelope([satellites[1], satellites[0]]));
      }),
      mswHttp.put('*/admin/api/satellites/order', () =>
        HttpResponse.json(
          {
            success: false,
            data: null,
            error: { code: 'edit_conflict', message: 'x' },
            meta: { stale_ids: [2], changed_by: { kind: 'admin', name: 'سارة' }, changed_at: '2026-11-01T09:30:00Z' },
          },
          { status: 409 },
        ),
      ),
    );

    await keyboardReorder();

    const dialog = await screen.findByRole('alertdialog', { name: /عدّل سارة هذا العنصر/ });
    await userEvent.click(within(dialog).getByRole('button', { name: 'إعادة التحميل' }));

    await waitFor(() => expect(listReads).toBeGreaterThan(0));
  });

  it('opens the conflict dialog on a stale edit and sends nothing on a second save', async () => {
    let patches = 0;
    renderPage();
    await screen.findByText('نايل سات');

    server.use(
      mswHttp.patch('*/admin/api/satellites/:id', () => {
        patches += 1;
        return HttpResponse.json(
          {
            success: false,
            data: null,
            error: { code: 'edit_conflict', message: 'x' },
            meta: { changed_by: { kind: 'admin', name: 'سارة' }, changed_at: '2026-11-01T09:30:00Z' },
          },
          { status: 409 },
        );
      }),
    );

    await userEvent.click(screen.getByRole('button', { name: 'تعديل نايل سات' }));
    const drawer = await screen.findByRole('dialog', { name: 'تعديل القمر' });
    const nameAr = within(drawer).getByLabelText('الاسم بالعربية');
    await userEvent.clear(nameAr);
    await userEvent.type(nameAr, 'نايل سات الجديد');

    // Their save lands after this editor loaded.
    server.use(
      mswHttp.get('*/admin/api/satellites/:id', () =>
        HttpResponse.json(envelope({ ...satellites[0], name_ar: 'نايل سات ٢' }), { headers: { ETag: '"sat-2c"' } }),
      ),
    );
    await userEvent.click(within(drawer).getByRole('button', { name: 'حفظ' }));

    const dialog = await screen.findByRole('alertdialog', { name: /عدّل سارة هذا العنصر/ });
    await userEvent.click(within(dialog).getByRole('button', { name: 'اعرض التغييرات' }));
    expect(within(dialog).getByText('نايل سات ٢')).toBeInTheDocument();

    // Save is answered by the dialog: the older version is never re-sent under the newer ETag.
    await userEvent.click(within(drawer).getByRole('button', { name: 'حفظ' }));
    expect(patches).toBe(1);
  });

  it('refuses an orbital position that is not a number the API accepts', async () => {
    const patches: string[] = [];
    renderPage();
    await screen.findByText('نايل سات');

    server.use(
      mswHttp.patch('*/admin/api/satellites/:id', async ({ request }) => {
        patches.push(request.url);
        return HttpResponse.json(envelope(satellites[0]), { headers: { ETag: '"sat-2b"' } });
      }),
    );

    await userEvent.click(screen.getByRole('button', { name: 'تعديل نايل سات' }));
    const drawer = await screen.findByRole('dialog', { name: 'تعديل القمر' });
    const degree = within(drawer).getByLabelText('الدرجة');
    await userEvent.clear(degree);
    await userEvent.type(degree, '190');
    await userEvent.click(within(drawer).getByRole('button', { name: 'حفظ' }));

    expect(await within(drawer).findByText('أدخل موقعاً بين 0 و 180 درجة')).toBeInTheDocument();
    expect(patches).toHaveLength(0);
  });
});
