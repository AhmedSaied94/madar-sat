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
  { id: 12, sport: 'football', name: 'الدوري المصري الممتاز', logo: null, logo_asset_id: null, priority: 1 },
  { id: 40, sport: 'football', name: 'دوري أبطال آسيا 2', logo: null, logo_asset_id: null, priority: 2 },
  { id: 55, sport: 'football', name: 'كأس مصر', logo: null, logo_asset_id: null, priority: 3 },
];

const etags: Record<number, string> = { 12: '"c-12"', 40: '"c-40"', 55: '"c-55"' };

function serve(): void {
  server.use(
    mswHttp.get('*/admin/api/competitions', () => HttpResponse.json(envelope(competitions))),
    mswHttp.get('*/admin/api/competitions/:id', ({ params }) => {
      const id = Number(params['id']);
      const row = competitions.find((competition) => competition.id === id);
      return HttpResponse.json(envelope(row), { headers: { ETag: etags[id] ?? '"x"' } });
    }),
  );
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

  it('saves the new order with each row version when the keyboard moves a row', async () => {
    let sent: Record<string, unknown> | null = null;
    renderPage();
    await screen.findByText('الدوري المصري الممتاز');

    server.use(
      mswHttp.put('*/admin/api/competitions/order', async ({ request }) => {
        sent = (await request.json()) as Record<string, unknown>;
        return HttpResponse.json(envelope({ updated: [] }));
      }),
    );

    const handle = screen.getAllByRole('button', { name: /إعادة الترتيب$/ })[0];
    if (!handle) throw new Error('expected a handle');
    handle.focus();
    await userEvent.keyboard('[Space]');
    await userEvent.keyboard('[ArrowDown]');
    await userEvent.keyboard('[Space]');

    await waitFor(() => expect(sent).not.toBeNull());
    expect(sent).toMatchObject({
      items: [
        { id: 40, if_match: '"c-40"' },
        { id: 12, if_match: '"c-12"' },
        { id: 55, if_match: '"c-55"' },
      ],
    });
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
