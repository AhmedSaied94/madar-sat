import { screen, waitFor, within } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { HttpResponse, http as mswHttp } from 'msw';
import type { ReactElement, ReactNode } from 'react';
import { describe, expect, it } from 'vitest';

import { ToastProvider } from '../../components/Toast/Toast';
import { renderRtl } from '../../test/render';
import { server } from '../../test/server';
import { CommentatorsPage } from './CommentatorsPage';

const envelope = (data: unknown): Record<string, unknown> => ({ success: true, data, error: null, meta: {} });

const people = [
  {
    id: 3,
    name: 'محمد بركات',
    photo: null,
    photo_asset_id: null,
    audio: 'https://media.example/barakat.mp3',
    audio_asset_id: 91,
    usage: { matches: 23, match_channels: 27 },
  },
  {
    id: 4,
    name: 'حفيظ دراجي',
    photo: null,
    photo_asset_id: null,
    audio: null,
    audio_asset_id: null,
    usage: { matches: 64, match_channels: 70 },
  },
];

function serve(): void {
  server.use(
    mswHttp.get('*/admin/api/commentators', () => HttpResponse.json(envelope(people))),
    mswHttp.get('*/admin/api/commentators/:id', ({ params }) => {
      const person = people.find((row) => row.id === Number(params['id']));
      return HttpResponse.json(envelope(person), { headers: { ETag: `"c-${String(params['id'])}"` } });
    }),
  );
}

function Providers({ children }: { children: ReactNode }): ReactElement {
  return <ToastProvider>{children}</ToastProvider>;
}

function renderPage() {
  serve();
  return renderRtl(<CommentatorsPage />, { wrapper: Providers });
}

describe('CommentatorsPage (A10)', () => {
  it('shows a card per commentator with their usage and a player only where a clip exists', async () => {
    renderPage();

    const card = await screen.findByTestId('commentator-3');
    expect(card).toHaveTextContent('محمد بركات');
    expect(card).toHaveTextContent('23 مباراة');
    expect(within(card).getByRole('button', { name: 'تشغيل المقطع' })).toBeInTheDocument();

    const quiet = screen.getByTestId('commentator-4');
    expect(within(quiet).queryByRole('button', { name: 'تشغيل المقطع' })).not.toBeInTheDocument();
    expect(within(quiet).getByText('بلا صوت')).toBeInTheDocument();
  });

  it('deletes an unused commentator under the version it read first', async () => {
    let deleted: number | null = null;
    let ifMatch: string | null = null;
    renderPage();
    const card = await screen.findByTestId('commentator-3');

    server.use(
      mswHttp.delete('*/admin/api/commentators/:id', ({ params, request }) => {
        ifMatch = request.headers.get('If-Match');
        // The backend answers 428 before it looks at anything else (contract `admin-api` D2).
        if (ifMatch === null) {
          return HttpResponse.json(
            {
              success: false,
              data: null,
              error: { code: 'precondition_required', message: 'If-Match required' },
              meta: {},
            },
            { status: 428 },
          );
        }
        deleted = Number(params['id']);
        return new HttpResponse(null, { status: 204 });
      }),
    );

    await userEvent.click(within(card).getByRole('button', { name: 'خيارات محمد بركات' }));
    await userEvent.click(within(card).getByRole('menuitem', { name: 'حذف' }));

    const dialog = await screen.findByRole('alertdialog', { name: 'حذف «محمد بركات»؟' });
    expect(dialog).toHaveTextContent('يُستخدم في 23 مباراة');
    await userEvent.click(within(dialog).getByRole('button', { name: 'حذف' }));

    await waitFor(() => expect(deleted).toBe(3));
    expect(ifMatch).toBe('"c-3"');
  });

  it('shows the usage count when the server refuses to delete a commentator in use', async () => {
    renderPage();
    const card = await screen.findByTestId('commentator-3');

    server.use(
      mswHttp.delete('*/admin/api/commentators/:id', () =>
        HttpResponse.json(
          {
            success: false,
            data: null,
            error: { code: 'in_use', message: 'in use' },
            meta: { matches: 23 },
          },
          { status: 409 },
        ),
      ),
    );

    await userEvent.click(within(card).getByRole('button', { name: 'خيارات محمد بركات' }));
    await userEvent.click(within(card).getByRole('menuitem', { name: 'حذف' }));
    const dialog = await screen.findByRole('alertdialog', { name: 'حذف «محمد بركات»؟' });
    await userEvent.click(within(dialog).getByRole('button', { name: 'حذف' }));

    expect(await screen.findByText(/لم يُحذف: يُستخدم في 23 مباراة/)).toBeInTheDocument();
  });

  it('renames a commentator under the version it loaded', async () => {
    let sent: Record<string, unknown> | null = null;
    let ifMatch: string | null = null;
    renderPage();
    const card = await screen.findByTestId('commentator-3');

    server.use(
      mswHttp.patch('*/admin/api/commentators/:id', async ({ request }) => {
        ifMatch = request.headers.get('If-Match');
        sent = (await request.json()) as Record<string, unknown>;
        return HttpResponse.json(envelope(people[0]), { headers: { ETag: '"c-3b"' } });
      }),
    );

    await userEvent.click(within(card).getByRole('button', { name: 'خيارات محمد بركات' }));
    await userEvent.click(within(card).getByRole('menuitem', { name: 'تعديل' }));

    const drawer = await screen.findByRole('dialog', { name: 'تعديل المعلق' });
    const name = within(drawer).getByLabelText('اسم المعلق');
    await userEvent.clear(name);
    await userEvent.type(name, 'محمد بركات الشهير');
    await userEvent.click(within(drawer).getByRole('button', { name: 'حفظ' }));

    await waitFor(() => expect(sent).not.toBeNull());
    expect(sent).toEqual({ name: 'محمد بركات الشهير' });
    expect(ifMatch).toBe('"c-3"');
  });

  it('refuses a nameless commentator with the field error, and sends nothing', async () => {
    const patches: string[] = [];
    renderPage();
    const card = await screen.findByTestId('commentator-3');

    server.use(
      mswHttp.patch('*/admin/api/commentators/:id', async ({ request }) => {
        patches.push(request.url);
        return HttpResponse.json(envelope(people[0]), { headers: { ETag: '"c-3b"' } });
      }),
    );

    await userEvent.click(within(card).getByRole('button', { name: 'خيارات محمد بركات' }));
    await userEvent.click(within(card).getByRole('menuitem', { name: 'تعديل' }));
    const drawer = await screen.findByRole('dialog', { name: 'تعديل المعلق' });

    await userEvent.clear(within(drawer).getByLabelText('اسم المعلق'));
    await userEvent.click(within(drawer).getByRole('button', { name: 'حفظ' }));

    expect(await within(drawer).findByText('هذا الحقل مطلوب')).toBeInTheDocument();
    expect(patches).toHaveLength(0);
  });

  it('opens the conflict dialog on a stale edit and sends nothing on a second save', async () => {
    let patches = 0;
    renderPage();
    const card = await screen.findByTestId('commentator-3');

    server.use(
      mswHttp.patch('*/admin/api/commentators/:id', () => {
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

    await userEvent.click(within(card).getByRole('button', { name: 'خيارات محمد بركات' }));
    await userEvent.click(within(card).getByRole('menuitem', { name: 'تعديل' }));
    const drawer = await screen.findByRole('dialog', { name: 'تعديل المعلق' });
    const name = within(drawer).getByLabelText('اسم المعلق');
    await userEvent.clear(name);
    await userEvent.type(name, 'اسمي');

    server.use(
      mswHttp.get('*/admin/api/commentators/:id', () =>
        HttpResponse.json(envelope({ ...people[0], name: 'محمد بركات الجديد' }), { headers: { ETag: '"c-3c"' } }),
      ),
    );
    await userEvent.click(within(drawer).getByRole('button', { name: 'حفظ' }));

    const dialog = await screen.findByRole('alertdialog', { name: /عدّل سارة هذا العنصر/ });
    await userEvent.click(within(dialog).getByRole('button', { name: 'اعرض التغييرات' }));
    expect(within(dialog).getByText('محمد بركات الجديد')).toBeInTheDocument();

    await userEvent.click(within(drawer).getByRole('button', { name: 'حفظ' }));
    expect(patches).toBe(1);
  });
});
