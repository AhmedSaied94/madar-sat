import { screen, waitFor, within } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { http, HttpResponse } from 'msw';
import type { ReactElement } from 'react';
import { useLocation } from 'react-router-dom';
import { describe, expect, it } from 'vitest';

import { renderRtl } from '../../test/render';
import { server } from '../../test/server';
import { envelope, Providers, refusal, restoreAs, type Role } from '../../test/signedIn';
import { NotificationsPage } from './NotificationsPage';

/** Prints the router's current URL, so a filter that belongs in the URL can be asserted there. */
function LocationProbe(): ReactElement {
  const { pathname, search } = useLocation();
  return (
    <output data-testid="location" hidden>
      {`${pathname}${search}`}
    </output>
  );
}

// A15 (contract admin-screens "A15: the log", board "Notifications"): the outbox with its type, target,
// counts, time and status — the status carrying the reason in Arabic, or the push service's own text
// raw — filtered by type and status through the URL, paged by cursor, and read by editors while only
// admins get the composer.

interface Outbox {
  id: number;
  type: string;
  status: 'pending' | 'sent' | 'failed' | 'cancelled';
  error: string | null;
  target: { kind: string; label: string | null; id: number | null } | null;
  is_test: boolean;
  is_correction: boolean;
  recipients: number;
  sent: number;
  failed: number;
  due_at: string | null;
  sent_at: string | null;
  created_at: string;
  etag: string;
}

/** A row's own version (a quoted 32-hex hash, as `lock_and_check` computes it). */
const version = (id: number, n = 1): string => `"${String(id).padStart(4, '0')}${String(n).padStart(28, '0')}"`;

const goal: Outbox = {
  id: 9012,
  etag: version(9012),
  type: 'goal',
  status: 'sent',
  error: null,
  target: { kind: 'match_core', label: 'البنك الأهلي × المصري', id: 48213 },
  is_test: false,
  is_correction: false,
  recipients: 1904,
  sent: 1889,
  failed: 15,
  due_at: '2026-11-06T18:40:00Z',
  sent_at: '2026-11-06T18:40:09Z',
  created_at: '2026-11-06T18:40:00Z',
};

const pendingAnnouncement: Outbox = {
  ...goal,
  id: 9013,
  etag: version(9013),
  type: 'announcement',
  status: 'pending',
  target: { kind: 'all', label: null, id: null },
  recipients: 0,
  sent: 0,
  failed: 0,
  due_at: '2026-11-06T21:00:00Z',
  sent_at: null,
};

const failedGoal: Outbox = {
  ...goal,
  id: 9014,
  etag: version(9014),
  status: 'failed',
  error: 'FCM 503',
  recipients: 312,
  sent: 0,
  failed: 312,
  sent_at: null,
  target: { kind: 'match_core', label: 'غامبا أوساكا × بوريرام', id: 48214 },
};

const correction: Outbox = { ...goal, id: 9015, etag: version(9015), type: 'goal', is_correction: true };

const testSend: Outbox = {
  ...goal,
  id: 9016,
  etag: version(9016),
  type: 'announcement',
  is_test: true,
  target: { kind: 'match_core', label: 'ميلان × بولونيا', id: 48215 },
};

const cancelled: Outbox = {
  ...goal,
  id: 9017,
  etag: version(9017),
  type: 'announcement',
  status: 'cancelled',
  error: 'admin',
  recipients: 0,
  sent: 0,
  failed: 0,
  sent_at: null,
  target: { kind: 'all', label: null, id: null },
};

/** One page of rows, keyed by the cursor the client asked for. */
function serveLog(pages: Record<string, { rows: Outbox[]; next: string | null }>): void {
  server.use(
    http.get('*/admin/api/notifications', ({ request }) => {
      const cursor = new URL(request.url).searchParams.get('cursor') ?? '';
      const page = pages[cursor] ?? { rows: [], next: null };
      return HttpResponse.json(envelope(page.rows, { next_cursor: page.next }));
    }),
  );
}

function renderLog(role: Role = 'admin', route = '/notifications') {
  restoreAs(role);
  const result = renderRtl(<NotificationsPage />, { route, wrapper: Providers });
  return result;
}

const rowOf = async (text: string): Promise<HTMLElement> => (await screen.findByText(text)).closest('tr') as HTMLElement;

describe('A15 the log', () => {
  it('renders every column of the board', async () => {
    serveLog({ '': { rows: [goal], next: null } });
    renderLog();

    const row = await rowOf('البنك الأهلي × المصري');

    expect(screen.getByRole('columnheader', { name: 'النوع' })).toBeInTheDocument();
    expect(screen.getByRole('columnheader', { name: 'الهدف' })).toBeInTheDocument();
    expect(screen.getByRole('columnheader', { name: 'المستقبلون' })).toBeInTheDocument();
    expect(screen.getByRole('columnheader', { name: 'نجح' })).toBeInTheDocument();
    expect(screen.getByRole('columnheader', { name: 'فشل' })).toBeInTheDocument();
    expect(screen.getByRole('columnheader', { name: 'الوقت' })).toBeInTheDocument();
    expect(screen.getByRole('columnheader', { name: 'الحالة' })).toBeInTheDocument();

    expect(within(row).getByText('goal')).toBeInTheDocument();
    expect(within(row).getByText('1,904')).toBeInTheDocument();
    expect(within(row).getByText('1,889')).toBeInTheDocument();
    expect(within(row).getByText('15')).toBeInTheDocument();
    expect(within(row).getByText('أُرسل')).toBeInTheDocument();
  });

  it('says «جميع الأجهزة» for a row with no label, and marks a scheduled one', async () => {
    serveLog({ '': { rows: [pendingAnnouncement], next: null } });
    renderLog();

    const row = await rowOf('جميع الأجهزة');

    expect(within(row).getByText('announcement')).toBeInTheDocument();
    expect(within(row).getByText('مجدول')).toBeInTheDocument();
  });

  it('marks a correction and a test send', async () => {
    serveLog({ '': { rows: [correction, testSend], next: null } });
    renderLog();

    const corrected = await rowOf('البنك الأهلي × المصري');
    expect(within(corrected).getByText('تصحيح')).toBeInTheDocument();

    const tested = await rowOf('ميلان × بولونيا');
    expect(within(tested).getByText('تجريبي')).toBeInTheDocument();
  });

  it('writes each known reason in Arabic, and an unknown one raw in an LTR island', async () => {
    serveLog({
      '': {
        rows: [
          { ...goal, id: 9101, status: 'failed', error: 'late', target: { kind: 'match_core', label: 'متأخر', id: 1 } },
          { ...goal, id: 9102, status: 'cancelled', error: 'match_finished', target: { kind: 'match_core', label: 'انتهت', id: 2 } },
          { ...goal, id: 9103, status: 'cancelled', error: 'score_fell', target: { kind: 'match_core', label: 'انخفضت', id: 3 } },
          { ...goal, id: 9104, status: 'cancelled', error: 'no_net_change', target: { kind: 'match_core', label: 'بلا تغيير', id: 4 } },
          { ...goal, id: 9105, status: 'cancelled', error: 'type_off', target: { kind: 'match_core', label: 'متوقف', id: 5 } },
          { ...failedGoal, id: 9106, target: { kind: 'match_core', label: 'خدمة', id: 6 } },
        ],
        next: null,
      },
    });
    renderLog();

    expect(within(await rowOf('متأخر')).getByText('متأخر عن الموعد')).toBeInTheDocument();
    expect(within(await rowOf('انتهت')).getByText('انتهت المباراة')).toBeInTheDocument();
    expect(within(await rowOf('انخفضت')).getByText('انخفضت النتيجة')).toBeInTheDocument();
    expect(within(await rowOf('بلا تغيير')).getByText('لم يتغيّر شيء')).toBeInTheDocument();
    expect(within(await rowOf('متوقف')).getByText('نوع الإشعار متوقف')).toBeInTheDocument();

    // The push service's own text is never translated: it stays exactly as it came, in an LTR island.
    const raw = within(await rowOf('خدمة')).getByText('FCM 503');
    expect(raw).toHaveAttribute('dir', 'ltr');
  });

  it('shows «ملغى · أُلغي من الإدارة» for a cancelled announcement', async () => {
    serveLog({ '': { rows: [cancelled], next: null } });
    renderLog();

    const row = within(await rowOf('جميع الأجهزة'));
    expect(row.getByText('ملغى')).toBeInTheDocument();
    expect(row.getByText('أُلغي من الإدارة')).toBeInTheDocument();
  });

  it('reads the filters from the URL and sends them to the server', async () => {
    const asked: URLSearchParams[] = [];
    server.use(
      http.get('*/admin/api/notifications', ({ request }) => {
        asked.push(new URL(request.url).searchParams);
        return HttpResponse.json(envelope([goal], { next_cursor: null }));
      }),
    );
    renderLog('admin', '/notifications?type=goal&status=failed');

    await screen.findByText('البنك الأهلي × المصري');

    expect(asked[0]?.get('type')).toBe('goal');
    expect(asked[0]?.get('status')).toBe('failed');
    expect(screen.getByLabelText('النوع')).toHaveValue('goal');
    expect(screen.getByLabelText('الحالة')).toHaveValue('failed');
  });

  it('writes a changed filter back into the URL', async () => {
    const asked: URLSearchParams[] = [];
    server.use(
      http.get('*/admin/api/notifications', ({ request }) => {
        asked.push(new URL(request.url).searchParams);
        return HttpResponse.json(envelope([goal], { next_cursor: null }));
      }),
    );
    restoreAs('admin');
    renderRtl(
      <>
        <NotificationsPage />
        <LocationProbe />
      </>,
      { route: '/notifications', wrapper: Providers },
    );

    await screen.findByText('البنك الأهلي × المصري');
    await userEvent.selectOptions(screen.getByLabelText('الحالة'), 'sent');

    await screen.findByText('البنك الأهلي × المصري');
    expect(screen.getByTestId('location')).toHaveTextContent('/notifications?status=sent');
    expect(asked.at(-1)?.get('status')).toBe('sent');
  });

  it('pages by cursor and comes back', async () => {
    const asked: (string | null)[] = [];
    server.use(
      http.get('*/admin/api/notifications', ({ request }) => {
        const cursor = new URL(request.url).searchParams.get('cursor');
        asked.push(cursor);
        return cursor === 'page-2'
          ? HttpResponse.json(envelope([pendingAnnouncement], { next_cursor: null }))
          : HttpResponse.json(envelope([goal], { next_cursor: 'page-2' }));
      }),
    );
    renderLog();

    await screen.findByText('البنك الأهلي × المصري');
    await userEvent.click(screen.getByRole('button', { name: 'المزيد' }));

    expect(await screen.findByText('جميع الأجهزة')).toBeInTheDocument();
    expect(asked).toEqual([null, 'page-2']);

    await userEvent.click(screen.getByRole('button', { name: 'السابق' }));
    expect(await screen.findByText('البنك الأهلي × المصري')).toBeInTheDocument();
  });

  it('asks for a new page every 30 seconds', async () => {
    serveLog({ '': { rows: [goal], next: null } });
    const { queryClient } = renderLog();

    await screen.findByText('البنك الأهلي × المصري');

    const polling = queryClient
      .getQueryCache()
      .getAll()
      .map((query) => (query.options as { refetchInterval?: unknown }).refetchInterval)
      .filter((interval) => interval !== undefined);
    expect(polling).toContain(30_000);
  });

  it('shows the loading line while the first page is in flight', async () => {
    server.use(http.get('*/admin/api/notifications', () => new Promise<never>(() => undefined)));
    renderLog();

    expect(await screen.findByText('جارٍ التحميل')).toBeInTheDocument();
  });

  it('shows the empty state when the outbox has no rows', async () => {
    serveLog({ '': { rows: [], next: null } });
    renderLog();

    expect(await screen.findByRole('heading', { name: 'لا إشعارات بعد' })).toBeInTheDocument();
  });

  it('shows the error state with a retry when the read fails', async () => {
    server.use(
      http.get('*/admin/api/notifications', () => HttpResponse.json(refusal('internal_error'), { status: 500 })),
    );
    renderLog();

    expect(await screen.findByRole('heading', { name: 'حدث خطأ في الخادم. حاول مرة أخرى بعد قليل' })).toBeInTheDocument();
    expect(screen.getByRole('button', { name: 'إعادة المحاولة' })).toBeInTheDocument();
  });

  it('cancels a pending announcement with the row’s own version, not the list’s ETag (A-R1-1)', async () => {
    const cancelled: { url: string; ifMatch: string | null }[] = [];
    server.use(
      http.get('*/admin/api/notifications', () =>
        HttpResponse.json(envelope([pendingAnnouncement], { next_cursor: null }), { headers: { ETag: 'W/"outbox-1"' } }),
      ),
      http.post('*/admin/api/notifications/:id/cancel', ({ request, params }) => {
        const ifMatch = request.headers.get('If-Match');
        cancelled.push({ url: String(params['id']), ifMatch });
        // The server compares If-Match with the row's version and nothing else.
        if (ifMatch !== pendingAnnouncement.etag) return HttpResponse.json(refusal('edit_conflict'), { status: 409 });
        return HttpResponse.json(
          envelope({ ...pendingAnnouncement, status: 'cancelled', error: 'admin', etag: version(9013, 2) }),
          { headers: { ETag: version(9013, 2) } },
        );
      }),
    );
    restoreAs('admin');
    renderRtl(<NotificationsPage />, { route: '/notifications', wrapper: Providers });

    const row = within(await rowOf('جميع الأجهزة'));
    await userEvent.click(row.getByRole('button', { name: 'إلغاء الإعلان' }));
    const dialog = await screen.findByRole('alertdialog');
    await userEvent.click(within(dialog).getByRole('button', { name: 'إلغاء الإعلان' }));

    await waitFor(() => expect(cancelled).toHaveLength(1));
    expect(cancelled[0]).toEqual({ url: '9013', ifMatch: version(9013) });
    expect(await screen.findByText('أُلغي الإعلان')).toBeInTheDocument();
  });

  it('opens ConflictDialog when the cancel loses a race', async () => {
    server.use(
      http.get('*/admin/api/notifications', () =>
        HttpResponse.json(envelope([pendingAnnouncement], { next_cursor: null }), { headers: { ETag: '"outbox-1"' } }),
      ),
      http.post('*/admin/api/notifications/:id/cancel', () =>
        HttpResponse.json(
          refusal('edit_conflict', { changed_by: { kind: 'admin', name: 'سارة حسن' }, changed_at: '2026-11-06T18:00:00Z' }),
          { status: 409 },
        ),
      ),
    );
    restoreAs('admin');
    renderRtl(<NotificationsPage />, { route: '/notifications', wrapper: Providers });

    const row = within(await rowOf('جميع الأجهزة'));
    await userEvent.click(row.getByRole('button', { name: 'إلغاء الإعلان' }));
    const confirm = await screen.findByRole('alertdialog');
    await userEvent.click(within(confirm).getByRole('button', { name: 'إلغاء الإعلان' }));

    expect(await screen.findByText(/حُفظت نسخة أحدث من/)).toBeInTheDocument();
  });

  it('gives an editor the log and no composer', async () => {    serveLog({ '': { rows: [goal], next: null } });
    renderLog('editor');

    expect(await screen.findByText('البنك الأهلي × المصري')).toBeInTheDocument();
    expect(screen.queryByRole('heading', { name: 'إعلان جديد' })).not.toBeInTheDocument();
  });

  it('gives an admin the composer beside the log', async () => {
    serveLog({ '': { rows: [goal], next: null } });
    renderLog('admin');

    expect(await screen.findByRole('heading', { name: 'إعلان جديد' })).toBeInTheDocument();
  });
});
