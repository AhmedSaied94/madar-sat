import { screen, waitFor, within } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { HttpResponse, http as mswHttp } from 'msw';
import type { ReactElement, ReactNode } from 'react';
import { describe, expect, it } from 'vitest';

import { ToastProvider } from '../../components/Toast/Toast';
import { renderRtl } from '../../test/render';
import { server } from '../../test/server';
import { UnresolvedQueue } from './UnresolvedQueue';

const envelope = (data: unknown, meta: Record<string, unknown> = {}): Record<string, unknown> => ({
  success: true,
  data,
  error: null,
  meta,
});

const rows = [
  {
    id: 91,
    source: 'livesoccertv',
    kind: 'team',
    name: 'Nasaf Qarshi',
    context: { match_id: 48213, home: 'ناساف', away: 'الكويت', competition: 'دوري أبطال آسيا 2' },
    seen_count: 4,
    last_seen_at: '2026-11-04T10:00:00Z',
    state: 'open',
    etag: '"n-91"',
    suggestions: [{ id: 101, name: 'ناساف', detail: 'دوري أبطال آسيا 2', confidence: 92, exact: false }],
  },
  {
    id: 92,
    source: 'yallakora',
    kind: 'team',
    name: 'Al Ahli',
    context: { match_id: 48214, home: 'الشحانية', away: 'الأهلي', competition: 'الدوري القطري' },
    seen_count: 2,
    last_seen_at: '2026-11-04T09:00:00Z',
    state: 'open',
    etag: '"n-92"',
    suggestions: [
      { id: 201, name: 'الأهلي', detail: 'الدوري القطري', confidence: 100, exact: true },
      { id: 202, name: 'الأهلي', detail: 'الدوري السعودي', confidence: 100, exact: true },
      { id: 203, name: 'الأهلي', detail: 'الدوري المصري', confidence: 100, exact: true },
    ],
  },
  {
    id: 93,
    source: 'livesoccertv',
    kind: 'channel',
    name: 'beIN SPORTS 2 MENA',
    context: { match_id: 48215, home: 'النهضة', away: 'الريان' },
    seen_count: 1,
    last_seen_at: '2026-11-04T08:00:00Z',
    state: 'open',
    etag: '"n-93"',
    suggestions: [],
  },
];

/** Answers the list with `rows` (or the given set) and answers by URL for the filter assertions. */
function serve(overrides: Partial<{ rows: unknown[]; meta: Record<string, unknown>; etag: string }> = {}): void {
  server.use(
    mswHttp.get('*/admin/api/unresolved-names', ({ request }) => {
      const source = new URL(request.url).searchParams.get('source');
      const list = overrides.rows ?? rows;
      const filtered =
        source === null ? list : list.filter((row) => (row as { source: string }).source === source);
      return HttpResponse.json(envelope(filtered, { open_count: 14, ...overrides.meta }), {
        headers: { ETag: overrides.etag ?? '"names-1"' },
      });
    }),
  );
}

function Providers({ children }: { children: ReactNode }): ReactElement {
  return <ToastProvider>{children}</ToastProvider>;
}

function renderQueue() {
  serve();
  return renderRtl(<UnresolvedQueue />, { wrapper: Providers });
}

describe('UnresolvedQueue (A13)', () => {
  it('shows the queue count and one row per name with its kind, source, context and suggestion', async () => {
    renderQueue();

    const table = await screen.findByRole('table', { name: 'أسماء غير محلولة' });
    expect(table).toBeInTheDocument();

    const count = screen.getByTestId('unresolved-count');
    expect(count).toHaveTextContent('14');

    const first = screen.getByTestId('unresolved-91');
    expect(within(first).getByText('Nasaf Qarshi')).toHaveAttribute('dir', 'ltr');
    expect(within(first).getByText('فريق')).toBeInTheDocument();
    expect(within(first).getByText('livesoccertv')).toHaveAttribute('dir', 'ltr');
    expect(within(first).getByText('ناساف × الكويت · دوري أبطال آسيا 2')).toBeInTheDocument();
    expect(within(first).getByText('ناساف')).toBeInTheDocument();
    expect(within(first).getByText('92%')).toBeInTheDocument();

    const channel = screen.getByTestId('unresolved-93');
    expect(within(channel).getByText('قناة')).toBeInTheDocument();
    expect(within(channel).getByText('لا اقتراحات. أنشئ عنصراً جديداً أو تجاهل الاسم.')).toBeInTheDocument();
  });

  it('filters the list by source', async () => {
    renderQueue();
    await screen.findByTestId('unresolved-91');

    await userEvent.selectOptions(screen.getByLabelText('المصدر'), 'yallakora');

    await waitFor(() => {
      expect(screen.queryByTestId('unresolved-91')).not.toBeInTheDocument();
      expect(screen.getByTestId('unresolved-92')).toBeInTheDocument();
    });
  });

  it('shows the loading state until the list answers', async () => {
    let release: (() => void) | undefined;
    const gate = new Promise<void>((done) => {
      release = done;
    });
    server.use(
      mswHttp.get('*/admin/api/unresolved-names', async () => {
        await gate;
        return HttpResponse.json(envelope([], { open_count: 0 }));
      }),
    );
    renderRtl(<UnresolvedQueue />, { wrapper: Providers });

    expect(screen.getByText('جارٍ تحميل الأسماء غير المحلولة')).toBeInTheDocument();
    release?.();
    expect(await screen.findByText('لا أسماء غير محلولة الآن')).toBeInTheDocument();
  });

  it('shows the failed state when the list cannot be read', async () => {
    server.use(
      mswHttp.get('*/admin/api/unresolved-names', () =>
        HttpResponse.json(
          { success: false, data: null, error: { code: 'internal_error', message: 'boom' }, meta: {} },
          { status: 500 },
        ),
      ),
    );
    renderRtl(<UnresolvedQueue />, { wrapper: Providers });

    expect(await screen.findByText('حدث خطأ في الخادم. حاول مرة أخرى بعد قليل')).toBeInTheDocument();
  });

  it('maps a name to its suggestion, writing nothing before the save', async () => {
    const posts: { body: unknown; ifMatch: string | null }[] = [];
    renderQueue();
    const row = await screen.findByTestId('unresolved-91');

    server.use(
      mswHttp.post('*/admin/api/unresolved-names/:id/map', async ({ request }) => {
        posts.push({
          body: (await request.json()) as unknown,
          ifMatch: request.headers.get('If-Match'),
        });
        return HttpResponse.json(envelope({ ...rows[0], state: 'mapped' }));
      }),
    );

    await userEvent.click(within(row).getByRole('button', { name: 'ربط' }));

    const dialog = await screen.findByRole('dialog', { name: 'ربط «Nasaf Qarshi»' });
    const preset = within(dialog).getByRole('radio', { name: /ناساف/ });
    expect(preset).toBeChecked();
    expect(posts).toHaveLength(0);

    await userEvent.click(within(dialog).getByRole('button', { name: 'حفظ' }));

    await waitFor(() => expect(posts).toHaveLength(1));
    expect(posts[0]).toEqual({
      body: { target_id: 101, scope_to_competition: false, created: false },
      ifMatch: '"n-91"',
    });
    expect(await screen.findByText('تم الربط')).toBeInTheDocument();
  });

  it('offers the picker when several candidates share the name, and scopes the alias to the competition', async () => {
    const posts: unknown[] = [];
    renderQueue();
    const row = await screen.findByTestId('unresolved-92');

    expect(within(row).getByText('3 مرشحين بنفس الاسم')).toBeInTheDocument();

    server.use(
      mswHttp.post('*/admin/api/unresolved-names/:id/map', async ({ request }) => {
        posts.push(await request.json());
        return HttpResponse.json(envelope({ ...rows[1], state: 'mapped' }));
      }),
    );

    await userEvent.click(within(row).getByRole('button', { name: 'اختر الفريق' }));

    const dialog = await screen.findByRole('dialog', { name: 'ربط «Al Ahli»' });
    expect(within(dialog).getAllByRole('radio')).toHaveLength(3);
    expect(within(dialog).getByRole('checkbox', { name: 'حصر الربط على البطولة' })).toBeChecked();

    await userEvent.click(within(dialog).getByRole('radio', { name: /الدوري المصري/ }));
    await userEvent.click(within(dialog).getByRole('button', { name: 'حفظ' }));

    await waitFor(() => expect(posts).toHaveLength(1));
    expect(posts[0]).toEqual({ target_id: 203, scope_to_competition: true, created: false });
  });

  it('shows the alias-conflict copy when the name is already bound elsewhere', async () => {
    renderQueue();
    const row = await screen.findByTestId('unresolved-91');
    server.use(
      mswHttp.post('*/admin/api/unresolved-names/:id/map', () =>
        HttpResponse.json(
          {
            success: false,
            data: null,
            error: { code: 'alias_conflict', message: 'alias exists' },
            meta: {},
          },
          { status: 409 },
        ),
      ),
    );

    await userEvent.click(within(row).getByRole('button', { name: 'ربط' }));
    const dialog = await screen.findByRole('dialog', { name: 'ربط «Nasaf Qarshi»' });
    await userEvent.click(within(dialog).getByRole('button', { name: 'حفظ' }));

    expect(
      await within(dialog).findByText('هذا الاسم مرتبط بجهة أخرى. حدّث الصفحة ثم حاول مرة أخرى'),
    ).toBeInTheDocument();
    expect(dialog).toBeInTheDocument();
  });

  it('keeps the row open and says so when the version it read is stale', async () => {
    renderQueue();
    const row = await screen.findByTestId('unresolved-91');
    server.use(
      mswHttp.post('*/admin/api/unresolved-names/:id/map', () =>
        HttpResponse.json(
          {
            success: false,
            data: null,
            error: { code: 'edit_conflict', message: 'moved' },
            meta: { changed_by: { kind: 'admin', name: 'سارة حسن', at: '2026-11-04T10:05:00Z' } },
          },
          { status: 409 },
        ),
      ),
    );

    await userEvent.click(within(row).getByRole('button', { name: 'ربط' }));
    const dialog = await screen.findByRole('dialog', { name: 'ربط «Nasaf Qarshi»' });
    await userEvent.click(within(dialog).getByRole('button', { name: 'حفظ' }));

    expect(
      await within(dialog).findByText('عُدّل هذا العنصر من شخص آخر. راجع التغييرات قبل الحفظ'),
    ).toBeInTheDocument();
  });

  it('ignores a name under the version it read', async () => {
    let ifMatch: string | null = null;
    let ignored: number | null = null;
    renderQueue();
    const row = await screen.findByTestId('unresolved-93');

    server.use(
      mswHttp.post('*/admin/api/unresolved-names/:id/ignore', ({ params, request }) => {
        ifMatch = request.headers.get('If-Match');
        ignored = Number(params['id']);
        return HttpResponse.json(envelope({ ...rows[2], state: 'ignored' }));
      }),
    );

    await userEvent.click(within(row).getByRole('button', { name: 'تجاهل' }));

    await waitFor(() => expect(ignored).toBe(93));
    expect(ifMatch).toBe('"n-93"');
    expect(await screen.findByText('تم التجاهل')).toBeInTheDocument();
  });

  it('keeps a visible keyboard focus on every action', async () => {
    renderQueue();
    const row = await screen.findByTestId('unresolved-91');

    for (const name of ['ربط', 'جديد', 'تجاهل']) {
      const button = within(row).getByRole('button', { name });
      expect(button.className).toContain('focus-visible:ring-2');
      await userEvent.tab();
      expect(button.className).toContain('outline-none');
    }
  });
});
