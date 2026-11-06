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
            etag: '"sat-2"',
          },
        ]),
      ),
    ),
  );
}

type Row = Record<string, unknown>;

interface SeenPatch {
  id: number;
  ifMatch: string | null;
  body: Row;
}

const absent = (row: Row, field: string): boolean => row[field] === null || row[field] === undefined;

/** `kind_errors` (backend/app/services/admin/channels.py): what a channel of this kind must and must not have. */
function kindErrors(before: Row, after: Row): string[] {
  const errors: string[] = [];
  if (after['kind'] === 'platform') {
    for (const field of ['satellite_id', 'frequency', 'frequency_note', 'beam']) {
      if (!absent(after, field)) errors.push(`${field}:not_allowed`);
    }
  } else {
    for (const field of ['satellite_id', 'access']) {
      if (absent(after, field)) errors.push(`${field}:required`);
    }
  }
  // A channel moved onto `satellite` also has to say where to tune.
  if (after['kind'] === 'satellite' && before['kind'] !== 'satellite' && absent(after, 'frequency') && absent(after, 'frequency_note')) {
    errors.push('frequency:required');
  }
  return errors;
}

/** An in-memory channels API: a PATCH is applied only when the kind rules above hold, else 422. */
function serveStore(): { patches: SeenPatch[]; stored: Map<number, Row> } {
  const stored = new Map<number, Row>([
    [501, { ...bein }],
    [777, { ...placeholder }],
  ]);
  const patches: SeenPatch[] = [];
  server.use(
    mswHttp.get('*/admin/api/channels', () => HttpResponse.json(envelope([...stored.values()]))),
    mswHttp.get('*/admin/api/channels/:id', ({ params }) => {
      const id = Number(params['id']);
      return HttpResponse.json(envelope({ ...stored.get(id), locked_fields: [] }), {
        headers: { ETag: `"ch-${String(id)}"` },
      });
    }),
    mswHttp.patch('*/admin/api/channels/:id', async ({ params, request }) => {
      const id = Number(params['id']);
      const body = (await request.json()) as Row;
      patches.push({ id, ifMatch: request.headers.get('If-Match'), body });
      const before = stored.get(id) ?? {};
      const after: Row = { ...before, ...body };
      // Putting a placeholder on match pages completes it (research R13, R18).
      if (body['show_in_match'] === true) after['placeholder_source'] = null;
      const errors = kindErrors(before, after);
      if (errors.length > 0) {
        return HttpResponse.json(
          { success: false, data: null, error: { code: 'validation_error', message: 'x' }, meta: { errors } },
          { status: 422 },
        );
      }
      stored.set(id, after);
      return HttpResponse.json(envelope({ ...after, locked_fields: [] }), { headers: { ETag: `"ch-${String(id)}-b"` } });
    }),
  );
  return { patches, stored };
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

  it('completes a platform placeholder as a satellite channel in one save', async () => {
    renderPage();
    await waitForRows();
    const api = serveStore();

    await userEvent.click(screen.getByRole('button', { name: 'تعديل Al Kass Two HD' }));
    const drawer = await screen.findByRole('dialog', { name: 'تعديل القناة' });

    // The importers' placeholder is a `platform`; `ChannelPatch.kind` now lets the editor change that (A-R1-5).
    expect(within(drawer).getByLabelText('القمر')).toBeEnabled();
    expect(within(drawer).queryByText(/غير متاح بعد/)).not.toBeInTheDocument();

    await userEvent.selectOptions(within(drawer).getByLabelText('القمر'), '2');
    await userEvent.type(within(drawer).getByLabelText('التردد · MHz'), '12188');
    await userEvent.type(within(drawer).getByLabelText('التردد · symbol rate'), '27500');
    await userEvent.click(within(drawer).getByRole('checkbox', { name: 'إظهار في صفحات المباريات' }));
    await userEvent.click(within(drawer).getByRole('button', { name: 'حفظ' }));

    await waitFor(() => expect(api.patches).toHaveLength(1));
    // The kind travels with the satellite, the frequency and an explicit access (an importer leaves it null).
    expect(api.patches[0]).toEqual({
      id: 777,
      ifMatch: '"ch-777"',
      body: {
        kind: 'satellite',
        satellite_id: 2,
        access: 'free',
        frequency: { mhz: 12188, pol: 'H', sr: 27500 },
        show_in_match: true,
      },
    });
    // The API accepted it: the channel is a satellite channel now, in the list with its readout.
    expect(api.stored.get(777)).toMatchObject({ kind: 'satellite', satellite_id: 2, placeholder_source: null });
    await waitFor(() => {
      const row = within(screen.getByRole('table')).getByText('Al Kass Two HD').closest('tr');
      if (!row) throw new Error('expected the channel row');
      expect(within(row).getByTestId('frequency-readout')).toHaveTextContent('12188');
      expect(row).not.toHaveTextContent('يحتاج استكمال');
    });
  });

  it('refuses to make a placeholder a satellite channel without a frequency, and sends nothing', async () => {
    renderPage();
    await waitForRows();
    const api = serveStore();

    await userEvent.click(screen.getByRole('button', { name: 'تعديل Al Kass Two HD' }));
    const drawer = await screen.findByRole('dialog', { name: 'تعديل القناة' });
    await userEvent.selectOptions(within(drawer).getByLabelText('القمر'), '2');
    await userEvent.click(within(drawer).getByRole('button', { name: 'حفظ' }));

    // The API would answer 422 `frequency required` (it also refuses it with "show on match pages" off),
    // so the form says it on the field, in Arabic, before anything is sent.
    expect(
      await within(drawer).findByText('أدخل التردد ومعدل الترميز لتحويل القناة إلى قناة على قمر'),
    ).toBeInTheDocument();
    expect(api.patches).toHaveLength(0);
  });

  it('keeps a placeholder a platform when no satellite is chosen, sending only what changed', async () => {
    renderPage();
    await waitForRows();
    const api = serveStore();

    await userEvent.click(screen.getByRole('button', { name: 'تعديل Al Kass Two HD' }));
    const drawer = await screen.findByRole('dialog', { name: 'تعديل القناة' });
    await userEvent.click(within(drawer).getByRole('checkbox', { name: 'إظهار في صفحات المباريات' }));
    await userEvent.click(within(drawer).getByRole('button', { name: 'حفظ' }));

    await waitFor(() => expect(api.patches).toHaveLength(1));
    // No satellite, no frequency and no `kind`: the channel stays the platform it was.
    expect(api.patches[0]?.body).toEqual({ show_in_match: true });
    expect(api.stored.get(777)).toMatchObject({ kind: 'platform', satellite_id: null, placeholder_source: null });
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

// A8's «سجل التردد» (contract admin-screens "A8: frequency history", board "Channels"): the last
// changes under the frequency, in edit mode only, each readout dark and LTR — the board's
// «20 أكتوبر · 11766 H → 11013 H · محمد علي».
describe('A8 frequency history', () => {
  const history = [
    {
      id: 55,
      old: '11766 H 27500',
      new: '11013 H 27500',
      source: 'admin',
      actor: 'محمد علي',
      detected_at: '2026-10-20T09:30:00Z',
    },
    {
      id: 54,
      old: '11843 H 27500',
      new: '11766 H 27500',
      source: 'admin',
      actor: 'سارة حسن',
      detected_at: '2026-09-02T11:00:00Z',
    },
  ];

  /** The A8 page with the drawer's own read added. */
  function renderWithHistory(rows: readonly Record<string, unknown>[]): URL[] {
    const asked: URL[] = [];
    renderPage();
    server.use(
      mswHttp.get('*/admin/api/channels/:id/frequency-changes', ({ request, params }) => {
        asked.push(new URL(request.url));
        expect(params['id']).toBe('501');
        return HttpResponse.json(envelope(rows));
      }),
    );
    return asked;
  }

  it('shows each change with its old and new readout, and who saved it', async () => {
    const asked = renderWithHistory(history);
    await waitForRows();

    await userEvent.click(screen.getByRole('button', { name: 'تعديل beIN SPORTS 1' }));
    const drawer = await screen.findByRole('dialog', { name: 'تعديل القناة' });

    expect(await within(drawer).findByText('سجل التردد')).toBeInTheDocument();
    expect(asked).toHaveLength(1);

    const readouts = within(drawer).getAllByRole('img');
    // Two changes, each with its old and new readout, all of them the dark LTR well.
    expect(readouts).toHaveLength(4);
    expect(readouts[0]).toHaveAccessibleName(/11766/);
    expect(readouts[1]).toHaveAccessibleName(/11013/);
    expect(readouts[2]).toHaveAccessibleName(/11843/);
    expect(readouts[3]).toHaveAccessibleName(/11766/);
    for (const readout of readouts) expect(readout).toHaveAttribute('dir', 'ltr');

    const first = readouts[0]?.closest('[data-history-id]') as HTMLElement | null;
    if (!first) throw new Error('expected a history row');
    expect(first).toHaveTextContent('محمد علي');
    expect(within(first).getByText('سارة حسن')).toBeInTheDocument();
  });

  it('says so in one line when the frequency never changed', async () => {
    renderWithHistory([]);
    await waitForRows();

    await userEvent.click(screen.getByRole('button', { name: 'تعديل beIN SPORTS 1' }));
    const drawer = await screen.findByRole('dialog', { name: 'تعديل القناة' });

    expect(await within(drawer).findByText('لم يتغيّر تردد هذه القناة بعد')).toBeInTheDocument();
  });

  it('is not in a new channel’s drawer', async () => {
    renderWithHistory(history);
    await waitForRows();

    await userEvent.click(screen.getByRole('button', { name: 'قناة جديدة' }));
    const drawer = await screen.findByRole('dialog', { name: 'قناة جديدة' });

    expect(within(drawer).queryByText('سجل التردد')).not.toBeInTheDocument();
  });
});
