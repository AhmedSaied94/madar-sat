import { screen, waitFor, within } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { HttpResponse, http as mswHttp } from 'msw';
import type { ReactElement, ReactNode } from 'react';
import { describe, expect, it } from 'vitest';

import { ToastProvider } from '../../components/Toast/Toast';
import { renderRtl } from '../../test/render';
import { server } from '../../test/server';
import { CompetitionsPage } from './CompetitionsPage';

const envelope = (data: unknown): Record<string, unknown> => ({ success: true, data, error: null, meta: {} });

const competitions = [
  { id: 12, sport: 'football', name: 'الدوري المصري الممتاز', logo: null, logo_asset_id: null, priority: 1, etag: '"c-12"' },
  { id: 40, sport: 'football', name: 'دوري أبطال آسيا 2', logo: null, logo_asset_id: null, priority: 2, etag: '"c-40"' },
  { id: 55, sport: 'football', name: 'كأس مصر', logo: null, logo_asset_id: null, priority: 3, etag: '"c-55"' },
];

/** The server's current version of each row: a list row's `etag`, the detail `ETag` and the order check. */
let live: Record<number, string> = {};
/** Every `GET /competitions/{id}` the page made. */
let detailReads: string[] = [];

function serve(): void {
  live = Object.fromEntries(competitions.map((competition) => [competition.id, competition.etag]));
  detailReads = [];
  server.use(
    mswHttp.get('*/admin/api/competitions', () =>
      HttpResponse.json(envelope(competitions.map((competition) => ({ ...competition, etag: live[competition.id] })))),
    ),
    mswHttp.get('*/admin/api/competitions/:id', ({ params }) => {
      const id = Number(params['id']);
      detailReads.push(String(id));
      const row = competitions.find((competition) => competition.id === id);
      return HttpResponse.json(envelope({ ...row, etag: live[id] }), { headers: { ETag: live[id] ?? '"x"' } });
    }),
  );
}

interface OrderBody {
  items: { id: number; if_match: string }[];
}

/** `PUT /competitions/order` as the API does it: one stale `if_match` rejects the whole order (409). */
function serveOrder(): { puts: OrderBody[]; applied: number[][] } {
  const seen = { puts: [] as OrderBody[], applied: [] as number[][] };
  server.use(
    mswHttp.put('*/admin/api/competitions/order', async ({ request }) => {
      const body = (await request.json()) as OrderBody;
      seen.puts.push(body);
      const stale = body.items.filter((item) => live[item.id] !== item.if_match).map((item) => item.id);
      if (stale.length > 0) {
        return HttpResponse.json(
          {
            success: false,
            data: null,
            error: { code: 'edit_conflict', message: 'x' },
            meta: { stale_ids: stale, changed_by: { kind: 'admin', name: 'سارة' }, changed_at: '2026-11-01T09:30:00Z' },
          },
          { status: 409 },
        );
      }
      seen.applied.push(body.items.map((item) => item.id));
      return HttpResponse.json(envelope({ updated: [] }));
    }),
  );
  return seen;
}

async function keyboardReorder(): Promise<void> {
  const handle = screen.getAllByRole('button', { name: /إعادة الترتيب$/ })[0];
  if (!handle) throw new Error('expected a handle');
  handle.focus();
  await userEvent.keyboard('[Space]');
  await userEvent.keyboard('[ArrowDown]');
  await userEvent.keyboard('[Space]');
}

function Providers({ children }: { children: ReactNode }): ReactElement {
  return <ToastProvider>{children}</ToastProvider>;
}

function renderPage() {
  serve();
  return renderRtl(<CompetitionsPage />, { wrapper: Providers });
}

describe('CompetitionsPage (A6)', () => {
  it('lists the competitions in their priority order, each with an editor', async () => {
    renderPage();

    expect(await screen.findByText('الدوري المصري الممتاز')).toBeInTheDocument();
    const items = screen.getAllByRole('listitem');
    expect(items).toHaveLength(3);
    expect(items[0]).toHaveTextContent('1');
    expect(items[0]).toHaveTextContent('الدوري المصري الممتاز');
    expect(items[2]).toHaveTextContent('كأس مصر');
    expect(screen.getByRole('button', { name: 'تعديل كأس مصر' })).toBeInTheDocument();
  });

  it('saves the new order under the versions the list was rendered with, reading no row at save time', async () => {
    renderPage();
    await screen.findByText('الدوري المصري الممتاز');
    const seen = serveOrder();
    expect(detailReads).toHaveLength(0);

    await keyboardReorder();

    await waitFor(() => expect(seen.puts).toHaveLength(1));
    expect(seen.puts[0]).toEqual({
      items: [
        { id: 40, if_match: '"c-40"' },
        { id: 12, if_match: '"c-12"' },
        { id: 55, if_match: '"c-55"' },
      ],
    });
    expect(seen.applied).toEqual([[40, 12, 55]]);
    // A-R1-1: the `etag` of each list row is the version; no `GET /competitions/{id}` per row.
    expect(detailReads).toHaveLength(0);
  });

  it('opens the conflict dialog and overwrites nothing when the list is older than the server', async () => {
    renderPage();
    await screen.findByText('الدوري المصري الممتاز');
    const seen = serveOrder();

    // Another editor saved competition 12 after this page rendered its list (version 1 -> 2).
    live[12] = '"c-12-v2"';

    await keyboardReorder();

    await waitFor(() => expect(seen.puts).toHaveLength(1));
    // The PUT carried the version the row was rendered with, so the server refuses it and keeps its order.
    expect(seen.puts[0]?.items[1]).toEqual({ id: 12, if_match: '"c-12"' });
    expect(seen.applied).toEqual([]);

    const dialog = await screen.findByRole('alertdialog', { name: /عدّل سارة هذا العنصر/ });
    expect(dialog).toBeInTheDocument();
    expect(detailReads).toHaveLength(0);
  });

  it('opens the conflict dialog when the order it saw is stale, and reloads', async () => {
    let listReads = 0;
    renderPage();
    await screen.findByText('الدوري المصري الممتاز');
    listReads = 0;

    server.use(
      mswHttp.get('*/admin/api/competitions', () => {
        listReads += 1;
        return HttpResponse.json(envelope([competitions[1], competitions[0], competitions[2]]));
      }),
      mswHttp.put('*/admin/api/competitions/order', () =>
        HttpResponse.json(
          {
            success: false,
            data: null,
            error: { code: 'edit_conflict', message: 'x' },
            meta: { stale_ids: [12], changed_by: { kind: 'admin', name: 'سارة' }, changed_at: '2026-11-01T09:30:00Z' },
          },
          { status: 409 },
        ),
      ),
    );

    const handle = screen.getAllByRole('button', { name: /إعادة الترتيب$/ })[0];
    if (!handle) throw new Error('expected a handle');
    handle.focus();
    await userEvent.keyboard('[Space]');
    await userEvent.keyboard('[ArrowDown]');
    await userEvent.keyboard('[Space]');

    const dialog = await screen.findByRole('alertdialog', { name: /عدّل سارة هذا العنصر/ });
    await userEvent.click(within(dialog).getByRole('button', { name: 'إعادة التحميل' }));

    await waitFor(() => expect(listReads).toBeGreaterThan(0));
  });

  it('refuses a competition with no name, with the field error and without sending', async () => {
    const patches: string[] = [];
    renderPage();
    await screen.findByText('الدوري المصري الممتاز');

    server.use(
      mswHttp.patch('*/admin/api/competitions/:id', async ({ request }) => {
        patches.push(request.url);
        return HttpResponse.json(envelope(competitions[0]), { headers: { ETag: '"c-12b"' } });
      }),
    );

    await userEvent.click(screen.getByRole('button', { name: 'تعديل كأس مصر' }));
    const drawer = await screen.findByRole('dialog', { name: 'تعديل البطولة' });
    await userEvent.clear(within(drawer).getByLabelText('اسم البطولة'));
    await userEvent.click(within(drawer).getByRole('button', { name: 'حفظ' }));

    // The message is Zod's, through the admin's Arabic error map: never the schema's English.
    expect(await within(drawer).findByText('هذا الحقل مطلوب')).toBeInTheDocument();
    expect(patches).toHaveLength(0);
  });

  it('opens the conflict dialog on a stale edit and sends nothing on a second save', async () => {
    let patches = 0;
    renderPage();
    await screen.findByText('الدوري المصري الممتاز');

    server.use(
      mswHttp.patch('*/admin/api/competitions/:id', () => {
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

    await userEvent.click(screen.getByRole('button', { name: 'تعديل كأس مصر' }));
    const drawer = await screen.findByRole('dialog', { name: 'تعديل البطولة' });
    const name = within(drawer).getByLabelText('اسم البطولة');
    await userEvent.clear(name);
    await userEvent.type(name, 'اسمي');

    server.use(
      mswHttp.get('*/admin/api/competitions/:id', () =>
        HttpResponse.json(envelope({ ...competitions[2], name: 'كأس مصر الجديد' }), { headers: { ETag: '"c-55b"' } }),
      ),
    );
    await userEvent.click(within(drawer).getByRole('button', { name: 'حفظ' }));

    const dialog = await screen.findByRole('alertdialog', { name: /عدّل سارة هذا العنصر/ });
    await userEvent.click(within(dialog).getByRole('button', { name: 'اعرض التغييرات' }));
    expect(within(dialog).getByText('كأس مصر الجديد')).toBeInTheDocument();

    // Save is answered by the dialog: my older version never travels under their newer ETag (A-R1-2).
    await userEvent.click(within(drawer).getByRole('button', { name: 'حفظ' }));
    expect(patches).toBe(1);
  });
});
