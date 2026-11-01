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

  it('asks with the usage count before deleting, then removes the commentator', async () => {
    let deleted: number | null = null;
    renderPage();
    const card = await screen.findByTestId('commentator-3');

    server.use(
      mswHttp.delete('*/admin/api/commentators/:id', ({ params }) => {
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
});
