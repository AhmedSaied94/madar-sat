import { screen, waitFor, within } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { HttpResponse, http as mswHttp } from 'msw';
import type { ReactElement, ReactNode } from 'react';
import { describe, expect, it } from 'vitest';

import { ToastProvider } from '../../components/Toast/Toast';
import { renderRtl } from '../../test/render';
import { server } from '../../test/server';
import { ChannelsPage } from './ChannelsPage';

const envelope = (data: unknown): Record<string, unknown> => ({ success: true, data, error: null, meta: {} });

const bein = {
  id: 501,
  name: 'beIN SPORTS 1',
  display_name: 'beIN SPORTS 1 HD',
  kind: 'satellite',
  satellite_id: 2,
  frequency: { mhz: 11013, pol: 'H', sr: 27500 },
  access: 'encrypted',
  provider: 'beIN',
  package: null,
  category: 'sports',
  country: 'QA',
  show_in_match: true,
  hidden_by_name: false,
  logo: null,
  logo_asset_id: null,
  sort_order: null,
  beam: null,
  frequency_note: null,
  placeholder_source: null,
};

// What the importers leave behind: a platform, with no satellite and no frequency at all.
const placeholder = {
  ...bein,
  id: 777,
  name: 'Al Kass Two HD',
  kind: 'platform',
  display_name: null,
  satellite_id: null,
  frequency: null,
  access: null,
  provider: null,
  category: null,
  country: 'QA',
  show_in_match: false,
  placeholder_source: 'livesoccertv',
};

const channelDetail = (overrides: Record<string, unknown> = {}): Record<string, unknown> => ({
  ...bein,
  locked_fields: [],
  ...overrides,
});

const listRequests: URL[] = [];

function serve(): void {
  listRequests.length = 0;
  server.use(
    mswHttp.get('*/admin/api/channels', ({ request }) => {
      listRequests.push(new URL(request.url));
      return HttpResponse.json(envelope([bein, placeholder]));
    }),
    mswHttp.get('*/admin/api/channels/:id', ({ params }) => {
      const id = Number(params['id']);
      const detail = id === 777 ? channelDetail({ ...placeholder, locked_fields: [] }) : channelDetail();
      return HttpResponse.json(envelope(detail), { headers: { ETag: `"ch-${String(id)}"` } });
    }),
    mswHttp.get('*/admin/api/satellites', () =>
      HttpResponse.json(
        envelope([
          {
            id: 2,
            slug: 'nilesat',
            kind: 'satellite',
            name_en: 'Nilesat',
            name_ar: 'نايل سات',
            orbital_position: -7,
            logo: null,
            logo_asset_id: null,
            best_frequency: null,
            worst_frequency: null,
            reception_url: null,
            priority: 1,
          },
        ]),
      ),
    ),
  );
}

function Providers({ children }: { children: ReactNode }): ReactElement {
  return <ToastProvider>{children}</ToastProvider>;
}

function renderPage() {
  serve();
  return renderRtl(<ChannelsPage />, { wrapper: Providers });
}

const waitForRows = () => screen.findByText('beIN SPORTS 1');

describe('ChannelsPage (A8)', () => {
  it('sends every list filter as a query parameter', async () => {
    renderPage();
    await waitForRows();

    await userEvent.type(screen.getByLabelText('اسم أو رقم تردد'), 'bein');
    await userEvent.selectOptions(screen.getByLabelText('القمر'), '2');
    await userEvent.selectOptions(screen.getByLabelText('الفئة'), 'sports');
    await userEvent.selectOptions(screen.getByLabelText('الوصول'), 'encrypted');
    await userEvent.click(screen.getByRole('button', { name: 'بلا شعار' }));
    await userEvent.click(screen.getByRole('button', { name: 'منصات فقط' }));
    await userEvent.click(screen.getByRole('button', { name: 'يظهر في المباريات' }));
    await userEvent.click(screen.getByRole('button', { name: 'يحتاج استكمال' }));

    await waitFor(() => {
      const url = listRequests.at(-1);
      expect(url?.searchParams.get('q')).toBe('bein');
      expect(url?.searchParams.get('satellite_id')).toBe('2');
      expect(url?.searchParams.get('category')).toBe('sports');
      expect(url?.searchParams.get('access')).toBe('encrypted');
      expect(url?.searchParams.get('missing_logo')).toBe('true');
      expect(url?.searchParams.get('kind')).toBe('platform');
      expect(url?.searchParams.get('show_in_match')).toBe('true');
      expect(url?.searchParams.get('placeholder')).toBe('true');
    });
  });

  it('shows the carriage in the readout well and marks a placeholder as needing completion', async () => {
    renderPage();
    await waitForRows();

    const row = screen.getByText('beIN SPORTS 1').closest('tr');
    if (!row) throw new Error('expected a row');
    const readout = within(row).getByTestId('frequency-readout');
    expect(readout).toHaveAttribute('dir', 'ltr');
    expect(readout).toHaveClass('bg-readout-bg', 'text-readout');
    expect(row).toHaveTextContent('11013');
    expect(row).toHaveTextContent('27500');
    expect(row).toHaveTextContent('beIN');

    const incomplete = screen.getByText('Al Kass Two HD').closest('tr');
    if (!incomplete) throw new Error('expected the placeholder row');
    expect(within(incomplete).getAllByText('يحتاج استكمال').length).toBeGreaterThan(0);
    expect(incomplete).toHaveTextContent('بلا تردد');
  });

  it('keeps the carriage of a placeholder locked while the contract cannot change its kind', async () => {
    let sent: Record<string, unknown> | null = null;
    renderPage();
    await waitForRows();

    server.use(
      mswHttp.patch('*/admin/api/channels/:id', async ({ request }) => {
        sent = (await request.json()) as Record<string, unknown>;
        return HttpResponse.json(envelope(channelDetail()), { headers: { ETag: '"ch-778"' } });
      }),
    );

    await userEvent.click(screen.getByRole('button', { name: 'تعديل Al Kass Two HD' }));
    const drawer = await screen.findByRole('dialog', { name: 'تعديل القناة' });

    // The importers' placeholder is a platform, and `ChannelPatch` has no `kind` yet (A-R1-5).
    expect(within(drawer).getByLabelText('القمر')).toBeDisabled();
    expect(
      within(drawer).getByText('هذه القناة أُنشئت كمنصة، وتحويلها إلى قناة على قمر غير متاح بعد.'),
    ).toBeInTheDocument();

    await userEvent.click(within(drawer).getByRole('checkbox', { name: 'إظهار في صفحات المباريات' }));
    await userEvent.click(within(drawer).getByRole('button', { name: 'حفظ' }));

    await waitFor(() => expect(sent).not.toBeNull());
    expect(sent).toMatchObject({ show_in_match: true });
    expect(sent).not.toHaveProperty('satellite_id');
    expect(sent).not.toHaveProperty('frequency');
  });

  it('refuses a channel with no name, with the field error and without sending', async () => {
    const patches: string[] = [];
    renderPage();
    await waitForRows();

    server.use(
      mswHttp.patch('*/admin/api/channels/:id', async ({ request }) => {
        patches.push(request.url);
        return HttpResponse.json(envelope(channelDetail()), { headers: { ETag: '"ch-502"' } });
      }),
    );

    await userEvent.click(screen.getByRole('button', { name: 'تعديل beIN SPORTS 1' }));
    const drawer = await screen.findByRole('dialog', { name: 'تعديل القناة' });
    await userEvent.clear(within(drawer).getByLabelText('اسم المطابقة'));
    await userEvent.click(within(drawer).getByRole('button', { name: 'حفظ' }));

    expect(await within(drawer).findByText('هذا الحقل مطلوب')).toBeInTheDocument();
    expect(patches).toHaveLength(0);
  });

  it('opens the conflict dialog on a stale edit and sends nothing on a second save', async () => {
    let patches = 0;
    renderPage();
    await waitForRows();

    server.use(
      mswHttp.patch('*/admin/api/channels/:id', () => {
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

    await userEvent.click(screen.getByRole('button', { name: 'تعديل beIN SPORTS 1' }));
    const drawer = await screen.findByRole('dialog', { name: 'تعديل القناة' });
    const displayName = within(drawer).getByLabelText('اسم العرض');
    await userEvent.clear(displayName);
    await userEvent.type(displayName, 'beIN SPORTS 1 ME');

    server.use(
      mswHttp.get('*/admin/api/channels/:id', () =>
        HttpResponse.json(envelope(channelDetail({ display_name: 'beIN SPORTS 1 HD 2' })), {
          headers: { ETag: '"ch-502"' },
        }),
      ),
    );
    await userEvent.click(within(drawer).getByRole('button', { name: 'حفظ' }));

    const dialog = await screen.findByRole('alertdialog', { name: /عدّل سارة هذا العنصر/ });
    await userEvent.click(within(dialog).getByRole('button', { name: 'اعرض التغييرات' }));
    expect(within(dialog).getByText('beIN SPORTS 1 HD 2')).toBeInTheDocument();

    await userEvent.click(within(drawer).getByRole('button', { name: 'حفظ' }));
    expect(patches).toBe(1);
  });

  it('copies a channel onto another satellite as a new carriage', async () => {
    let sent: Record<string, unknown> | null = null;
    renderPage();
    await waitForRows();

    server.use(
      mswHttp.post('*/admin/api/channels', async ({ request }) => {
        sent = (await request.json()) as Record<string, unknown>;
        return HttpResponse.json(envelope(channelDetail({ id: 601 })), { status: 201 });
      }),
    );

    await userEvent.click(screen.getByRole('button', { name: 'إضافة beIN SPORTS 1 على قمر آخر' }));
    const drawer = await screen.findByRole('dialog', { name: 'قناة جديدة' });
    expect(within(drawer).getByLabelText('اسم المطابقة')).toHaveValue('beIN SPORTS 1');
    await userEvent.selectOptions(within(drawer).getByLabelText('القمر'), '2');
    await userEvent.type(within(drawer).getByLabelText('التردد · MHz'), '12188');
    await userEvent.type(within(drawer).getByLabelText('التردد · symbol rate'), '27500');
    await userEvent.click(within(drawer).getByRole('button', { name: 'حفظ' }));

    await waitFor(() => expect(sent).not.toBeNull());
    expect(sent).toMatchObject({
      name: 'beIN SPORTS 1',
      display_name: 'beIN SPORTS 1 HD',
      kind: 'satellite',
      satellite_id: 2,
      frequency: { mhz: 12188, pol: 'H', sr: 27500 },
    });
  });
});
