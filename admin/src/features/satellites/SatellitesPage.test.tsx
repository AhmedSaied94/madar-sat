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

function serve(): void {
  server.use(
    mswHttp.get('*/admin/api/satellites', () => HttpResponse.json(envelope(satellites))),
    mswHttp.get('*/admin/api/satellites/:id', ({ params }) => {
      const row = satellites.find((satellite) => satellite.id === Number(params['id']));
      return HttpResponse.json(envelope(row), { headers: { ETag: `"sat-${String(params['id'])}"` } });
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

  it('refuses a reception link that is not https', async () => {
    renderPage();
    await screen.findByText('نايل سات');

    await userEvent.click(screen.getByRole('button', { name: 'تعديل نايل سات' }));
    const drawer = await screen.findByRole('dialog', { name: 'تعديل القمر' });
    const reception = within(drawer).getByLabelText('فيديو طريقة الاستقبال');
    await userEvent.clear(reception);
    await userEvent.type(reception, 'http://youtube.com/watch?v=1');

    expect(within(drawer).getByText('أدخل رابطاً يبدأ بـ https://')).toBeInTheDocument();
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
});
