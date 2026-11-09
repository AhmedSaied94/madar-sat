import { fireEvent, screen, waitFor, within } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { http, HttpResponse } from 'msw';
import { describe, expect, it } from 'vitest';

import { renderRtl } from '../../test/render';
import { server } from '../../test/server';
import { envelope, Providers, refusal, restoreAs } from '../../test/signedIn';
import { Composer } from './Composer';

// A15's composer (contract admin-screens "Composer", board "Notifications"): the two counters, the
// deep-link target the server turns into a route, the five audiences with their reach, the Cairo
// send time, both previews, the confirmation before «كل الأجهزة», and the test send that reports
// what the outbox row actually did.

const team = (id: number, name: string) => ({ id, name, logo: null });

const matches = [
  {
    id: 48213,
    match_date: '2026-11-06',
    kickoff_at: '2026-11-06T18:00:00Z',
    time_tbd: false,
    status: 'scheduled',
    estimated: false,
    score: null,
    competition: { id: 12, name: 'الدوري الإنجليزي', logo: null, priority: 1, stage: 'الجولة 11' },
    home: team(101, 'ليفربول'),
    away: team(102, 'تشيلسي'),
    channel_count: 4,
    broadcaster_count: 0,
    missing_channels: false,
    commentator: null,
    sources: ['ysscores'],
    locked: false,
    etag: '"row-48213"',
  },
  {
    id: 48214,
    match_date: '2026-11-06',
    kickoff_at: '2026-11-06T20:00:00Z',
    time_tbd: false,
    status: 'scheduled',
    estimated: false,
    score: null,
    competition: { id: 14, name: 'الدوري الإيطالي', logo: null, priority: 2, stage: 'الجولة 11' },
    home: team(201, 'ميلان'),
    away: team(202, 'بولونيا'),
    channel_count: 2,
    broadcaster_count: 0,
    missing_channels: false,
    commentator: null,
    sources: ['ysscores'],
    locked: false,
    etag: '"row-48214"',
  },
];

const teams = [
  { id: 101, name: 'ليفربول', country: 'إنجلترا', logo: null, primary_competition: null, competitions: [] },
  { id: 102, name: 'تشيلسي', country: 'إنجلترا', logo: null, primary_competition: null, competitions: [] },
];

const competitions = [
  { id: 12, sport: 'football', name: 'الدوري الإنجليزي', logo: null, logo_asset_id: null, priority: 1, etag: '"c-12"' },
  { id: 14, sport: 'football', name: 'الدوري الإيطالي', logo: null, logo_asset_id: null, priority: 2, etag: '"c-14"' },
];

const channels = [
  {
    id: 5512,
    kind: 'satellite',
    name: 'beIN SPORTS 1',
    display_name: 'beIN SPORTS 1',
    logo_asset_id: null,
    logo: null,
    category: 'sports',
    country: null,
    satellite_id: 2,
    frequency: { mhz: 11013, pol: 'H', sr: 27500 },
    frequency_note: null,
    access: 'encrypted',
    provider: 'beIN',
    package: null,
    beam: 'wide',
    show_in_match: true,
    sort_order: 1,
    hidden_by_name: false,
    placeholder_source: null,
  },
];

const device = { device_id: 812, platform: 'android', app_version: '0.6.0+60', has_push_token: true };

const outboxRow = {
  id: 9016,
  type: 'announcement',
  status: 'pending',
  error: null,
  target: { kind: 'all', label: null, id: null },
  is_test: true,
  is_correction: false,
  recipients: 0,
  sent: 0,
  failed: 0,
  due_at: '2026-11-06T21:00:00Z',
  sent_at: null,
  created_at: '2026-11-06T20:00:00Z',
  etag: '"00000000000000000000000000009016"',
};

interface Served {
  posts: Record<string, unknown>[];
  tests: Record<string, unknown>[];
  reach: URL[];
  devicePuts: { body: Record<string, unknown>; ifMatch: string | null }[];
  deviceReads: number;
}

/** Everything the composer reads and writes, so a test can assert what reached the API. */
function serve(
  overrides: {
    device?: unknown;
    reachDevices?: number;
    conflict?: boolean;
    testRefused?: string;
    /** What the outbox says the test row did, when the composer reads it back (A-R1-8). */
    testOutcome?: { status: string; error: string | null; sent?: number; failed?: number };
  } = {},
): Served {
  const served: Served = { posts: [], tests: [], reach: [], devicePuts: [], deviceReads: 0 };
  let savedDevice: unknown = 'device' in overrides ? overrides.device : device;

  server.use(
    http.get('*/admin/api/matches', () => HttpResponse.json(envelope(matches, { next_cursor: null }))),
    http.get('*/admin/api/teams', () => HttpResponse.json(envelope(teams))),
    http.get('*/admin/api/competitions', () => HttpResponse.json(envelope(competitions))),
    http.get('*/admin/api/channels', () => HttpResponse.json(envelope(channels))),
    http.get('*/admin/api/notifications/reach', ({ request }) => {
      served.reach.push(new URL(request.url));
      return HttpResponse.json(envelope({ devices: overrides.reachDevices ?? 48200 }));
    }),
    http.get('*/admin/api/notifications/test-device', () => {
      served.deviceReads += 1;
      return HttpResponse.json(envelope(savedDevice), { headers: { ETag: '"dev-1"' } });
    }),
    http.put('*/admin/api/notifications/test-device', async ({ request }) => {
      const body = (await request.json()) as Record<string, unknown>;
      served.devicePuts.push({ body, ifMatch: request.headers.get('If-Match') });
      if (overrides.conflict === true) {
        return HttpResponse.json(refusal('edit_conflict', { current_etag: '"dev-2"' }), { status: 409 });
      }
      // The saved device answers the next read, as the real API does once the write commits.
      savedDevice = device;
      return HttpResponse.json(envelope(device), { headers: { ETag: '"dev-2"' } });
    }),
    http.post('*/admin/api/notifications/announcements', async ({ request }) => {
      served.posts.push((await request.json()) as Record<string, unknown>);
      return HttpResponse.json(envelope(outboxRow), { status: 201, headers: { ETag: '"outbox-9016"' } });
    }),
    http.post('*/admin/api/notifications/test', async ({ request }) => {
      served.tests.push((await request.json()) as Record<string, unknown>);
      if (overrides.testRefused !== undefined) {
        return HttpResponse.json(refusal(overrides.testRefused), { status: 422 });
      }
      // The real API answers with the row as queued: nothing has been sent yet.
      return HttpResponse.json(envelope(outboxRow), { status: 201 });
    }),
    http.get('*/admin/api/notifications', () => {
      const { status, error, ...counts } = overrides.testOutcome ?? { status: 'pending', error: null };
      // The row's own counts when the test gives them; else what its status usually means.
      const sent = counts.sent ?? (status === 'sent' ? 1 : 0);
      const failed = counts.failed ?? (status === 'failed' ? 1 : 0);
      return HttpResponse.json(
        envelope([{ ...outboxRow, status, error, recipients: 1, sent, failed }], { next_cursor: null }),
      );
    }),
  );

  return served;
}

function renderComposer() {
  restoreAs('admin');
  return renderRtl(<Composer />, { route: '/notifications', wrapper: Providers });
}

const TITLE = 'ليفربول × تشيلسي الليلة 11:00 م';
const BODY = 'على beIN SPORTS 1 · نايل سات وبدر — اضغط لعرض القنوات والترددات';

async function fill(): Promise<void> {
  await userEvent.type(screen.getByLabelText('العنوان'), TITLE);
  await userEvent.type(screen.getByLabelText('النص'), BODY);
}

describe('the composer', () => {
  it('counts the title to 65 and the body to 180, live', async () => {
    serve();
    renderComposer();

    expect(screen.getByText('0/65')).toBeInTheDocument();
    expect(screen.getByText('0/180')).toBeInTheDocument();
    expect(screen.getByLabelText('العنوان')).toHaveAttribute('maxlength', '65');
    expect(screen.getByLabelText('النص')).toHaveAttribute('maxlength', '180');

    await userEvent.type(screen.getByLabelText('العنوان'), 'ا'.repeat(65));
    await userEvent.type(screen.getByLabelText('النص'), 'ب'.repeat(180));

    expect(screen.getByText('65/65')).toBeInTheDocument();
    expect(screen.getByText('180/180')).toBeInTheDocument();
  });

  it('previews the title and body on both platforms, updating as you type', async () => {
    serve();
    renderComposer();

    await userEvent.type(screen.getByLabelText('العنوان'), 'عنوان');

    const previews = screen.getByRole('complementary', { name: 'معاينة' });
    expect(within(previews).getByText('Android')).toBeInTheDocument();
    expect(within(previews).getByText('iPhone (PWA مثبّت)')).toBeInTheDocument();
    expect(screen.getAllByText('عنوان')).toHaveLength(2);

    await userEvent.type(screen.getByLabelText('النص'), 'نص');

    expect(screen.getAllByText('عنوان')).toHaveLength(2);
    expect(screen.getAllByText(/نص/).length).toBeGreaterThanOrEqual(2);
  });

  it('sends an announcement to all devices after confirming the reach', async () => {
    const served = serve({ reachDevices: 48200 });
    renderComposer();

    await fill();
    await waitFor(() => expect(screen.getByText(/48,200/)).toBeInTheDocument());
    await userEvent.click(screen.getByRole('button', { name: 'إرسال الآن' }));

    const dialog = await screen.findByRole('alertdialog');
    expect(within(dialog).getByText(/48,200/)).toBeInTheDocument();
    await userEvent.click(within(dialog).getByRole('button', { name: 'إرسال' }));

    await waitFor(() => expect(served.posts).toHaveLength(1));
    expect(served.posts[0]).toMatchObject({
      title: TITLE,
      body: BODY,
      target: { type: 'none', id: null },
      audience: { kind: 'all', id: null },
      send_at: null,
    });
  });

  it('asks the reach endpoint again, for the audience it picked', async () => {
    const served = serve({ reachDevices: 6310 });
    renderComposer();

    await userEvent.click(screen.getByRole('radio', { name: 'مباراة' }));
    await userEvent.click(await screen.findByRole('button', { name: /ليفربول × تشيلسي/ }));

    await waitFor(() => expect(served.reach.at(-1)?.searchParams.get('kind')).toBe('match'));
    expect(served.reach.at(-1)?.searchParams.get('id')).toBe('48213');
    expect(await screen.findByText(/6,310/)).toBeInTheDocument();
  });

  it('sends each audience kind the server understands', async () => {
    const served = serve();

    // team: a picker, and free text that names no team is not an audience.
    renderComposer();
    await fill();
    await userEvent.click(screen.getByRole('radio', { name: 'فريق' }));
    await userEvent.type(screen.getByLabelText('الفريق'), 'ليف');
    expect(screen.getByRole('button', { name: 'إرسال الآن' })).toBeDisabled();
    await userEvent.click(await screen.findByRole('option', { name: /ليفربول/ }));
    await userEvent.click(screen.getByRole('button', { name: 'إرسال الآن' }));

    await waitFor(() => expect(served.posts).toHaveLength(1));
    expect(served.posts[0]).toMatchObject({ audience: { kind: 'team', id: 101 } });
  });

  it('sends a competition audience', async () => {
    const served = serve();
    renderComposer();

    await fill();
    await userEvent.click(screen.getByRole('radio', { name: 'بطولة' }));
    await userEvent.selectOptions(screen.getByLabelText('البطولة'), '12');
    await userEvent.click(screen.getByRole('button', { name: 'إرسال الآن' }));

    await waitFor(() => expect(served.posts).toHaveLength(1));
    expect(served.posts[0]).toMatchObject({ audience: { kind: 'competition', id: 12 } });
  });

  it('turns a picked match into the route the server builds', async () => {
    const served = serve();
    renderComposer();

    await fill();
    await userEvent.click(screen.getByRole('button', { name: 'اختر مباراة' }));
    await userEvent.click(await screen.findByRole('button', { name: /ليفربول × تشيلسي/ }));

    expect(await screen.findByText('/match/48213')).toBeInTheDocument();

    await userEvent.click(screen.getByRole('button', { name: 'إرسال الآن' }));

    const dialog = await screen.findByRole('alertdialog');
    await userEvent.click(within(dialog).getByRole('button', { name: 'إرسال' }));

    await waitFor(() => expect(served.posts).toHaveLength(1));
    expect(served.posts[0]).toMatchObject({ target: { type: 'match', id: 48213 } });
  });

  it('turns a picked channel into the channel route, for the announcement and the test (A-R1-7)', async () => {
    const served = serve();
    renderComposer();

    await fill();
    await userEvent.click(screen.getByRole('button', { name: 'اختر قناة' }));
    const pick = await screen.findAllByRole('button', { name: 'اختيار' });
    await userEvent.click(pick[0] as HTMLElement);

    expect(await screen.findByText('/channel/5512')).toBeInTheDocument();
    expect(screen.getByText('beIN SPORTS 1')).toBeInTheDocument();

    await userEvent.click(screen.getByRole('button', { name: 'إرسال تجريبي لجهازي' }));
    await waitFor(() => expect(served.tests).toHaveLength(1));
    expect(served.tests[0]).toMatchObject({ target: { type: 'channel', id: 5512 } });

    await userEvent.click(screen.getByRole('button', { name: 'إرسال الآن' }));
    const dialog = await screen.findByRole('alertdialog');
    await userEvent.click(within(dialog).getByRole('button', { name: 'إرسال' }));

    await waitFor(() => expect(served.posts).toHaveLength(1));
    expect(served.posts[0]).toMatchObject({ target: { type: 'channel', id: 5512 } });
  });

  it('clears a channel deep link back to none', async () => {
    const served = serve();
    renderComposer();

    await fill();
    await userEvent.click(screen.getByRole('button', { name: 'اختر قناة' }));
    const pick = await screen.findAllByRole('button', { name: 'اختيار' });
    await userEvent.click(pick[0] as HTMLElement);
    await userEvent.click(await screen.findByRole('button', { name: 'إزالة الرابط' }));

    expect(screen.queryByText('/channel/5512')).not.toBeInTheDocument();
    await userEvent.click(screen.getByRole('button', { name: 'إرسال الآن' }));
    await userEvent.click(within(await screen.findByRole('alertdialog')).getByRole('button', { name: 'إرسال' }));
    await waitFor(() => expect(served.posts).toHaveLength(1));
    expect(served.posts[0]).toMatchObject({ target: { type: 'none', id: null } });
  });

  it('refuses a scheduled time in the past, and sends the Cairo instant for one in the future', async () => {
    const served = serve();
    renderComposer();

    await fill();
    await userEvent.click(screen.getByRole('button', { name: 'مجدول' }));

    const when = screen.getByLabelText('الموعد بتوقيت القاهرة');
    fireEvent.change(when, { target: { value: '2020-01-01T10:00' } });
    await userEvent.click(screen.getByRole('button', { name: 'جدولة الإرسال' }));

    expect(await screen.findByText('اختر موعداً بعد الآن')).toBeInTheDocument();
    expect(served.posts).toHaveLength(0);

    fireEvent.change(when, { target: { value: '2031-01-01T10:00' } });
    await userEvent.click(screen.getByRole('button', { name: 'جدولة الإرسال' }));

    const dialog = await screen.findByRole('alertdialog');
    await userEvent.click(within(dialog).getByRole('button', { name: 'إرسال' }));

    await waitFor(() => expect(served.posts).toHaveLength(1));
    expect(served.posts[0]).toMatchObject({ send_at: '2031-01-01T08:00:00.000Z' });
  });

  it('names the saved test device, with its platform in an LTR island', async () => {
    serve();
    renderComposer();

    const island = (await screen.findByText(/0\.6\.0\+60/)).closest('bdi') as HTMLElement;
    expect(island).toHaveAttribute('dir', 'ltr');
    expect(within(island).getByText('Android')).toBeInTheDocument();
  });

  it('reports a queued test send as queued, never as sent (A-R1-8)', async () => {
    const served = serve({ testOutcome: { status: 'pending', error: null } });
    renderComposer();

    await fill();
    await userEvent.click(screen.getByRole('button', { name: 'إرسال تجريبي لجهازي' }));

    await waitFor(() => expect(served.tests).toHaveLength(1));
    expect(served.tests[0]).toMatchObject({ title: TITLE, body: BODY });
    const result = await screen.findByTestId('test-result');
    expect(result).toHaveTextContent('التجريبي في صندوق الإرسال');
    expect(result).not.toHaveTextContent('أُرسل التجريبي');
    expect(within(result).getByText('Android').closest('bdi')).toHaveAttribute('dir', 'ltr');
  });

  it('reports a test send as sent once its outbox row says so (A-R1-8)', async () => {
    serve({ testOutcome: { status: 'sent', error: null } });
    renderComposer();

    await fill();
    await userEvent.click(screen.getByRole('button', { name: 'إرسال تجريبي لجهازي' }));

    const result = await screen.findByTestId('test-result');
    await waitFor(() => expect(result).toHaveTextContent('أُرسل التجريبي إلى'));
    expect(within(result).getByText('Android').closest('bdi')).toHaveAttribute('dir', 'ltr');
  });

  it('reports a failed test send with the push service’s reason (A-R1-8)', async () => {
    serve({ testOutcome: { status: 'failed', error: 'FCM 503' } });
    renderComposer();

    await fill();
    await userEvent.click(screen.getByRole('button', { name: 'إرسال تجريبي لجهازي' }));

    const result = await screen.findByTestId('test-result');
    await waitFor(() => expect(result).toHaveTextContent('فشل الإرسال التجريبي'));
    expect(within(result).getByText('FCM 503').closest('bdi')).toHaveAttribute('dir', 'ltr');
    expect(result).not.toHaveTextContent('أُرسل التجريبي');
  });

  it.each([
    ['rejected by the push service', 1],
    ['dropped as a stale token', 0],
  ])('reports a finished test send that reached nobody (%s) as not delivered (A-R2-1)', async (_case, failed) => {
    // The dispatcher marks a row sent once it has walked the audience, whatever its counts.
    serve({ testOutcome: { status: 'sent', error: null, sent: 0, failed } });
    renderComposer();

    await fill();
    await userEvent.click(screen.getByRole('button', { name: 'إرسال تجريبي لجهازي' }));

    const result = await screen.findByTestId('test-result');
    await waitFor(() => expect(result).toHaveTextContent('لم يصل التجريبي إلى'));
    expect(result).not.toHaveTextContent('أُرسل التجريبي');
    expect(within(result).getByText('Android').closest('bdi')).toHaveAttribute('dir', 'ltr');
  });

  it('gives the reason of a finished test send that reached nobody, when the row has one (A-R2-1)', async () => {
    serve({ testOutcome: { status: 'sent', error: 'FCM INVALID_ARGUMENT', sent: 0, failed: 1 } });
    renderComposer();

    await fill();
    await userEvent.click(screen.getByRole('button', { name: 'إرسال تجريبي لجهازي' }));

    const result = await screen.findByTestId('test-result');
    await waitFor(() => expect(result).toHaveTextContent('لم يصل التجريبي إلى'));
    expect(within(result).getByText('FCM INVALID_ARGUMENT').closest('bdi')).toHaveAttribute('dir', 'ltr');
  });

  it('asks for a device id when none is saved, and saves one with If-Match', async () => {
    const served = serve({ device: null });
    renderComposer();

    await fill();
    const id = await screen.findByLabelText('معرّف الجهاز');
    await userEvent.type(id, '812');
    await userEvent.click(screen.getByRole('button', { name: 'حفظ الجهاز' }));

    await waitFor(() => expect(served.devicePuts).toHaveLength(1));
    expect(served.devicePuts[0]).toEqual({ body: { device_id: 812 }, ifMatch: '"dev-1"' });
    expect(await screen.findByText(/0\.6\.0\+60/)).toBeInTheDocument();
  });

  it('reloads the saved device after an edit conflict instead of resending blind', async () => {
    const served = serve({ device: null, conflict: true });
    renderComposer();

    await fill();
    const id = await screen.findByLabelText('معرّف الجهاز');
    await userEvent.type(id, '812');
    await userEvent.click(screen.getByRole('button', { name: 'حفظ الجهاز' }));

    await waitFor(() => expect(served.devicePuts).toHaveLength(1));
    // The refusal re-reads the device, so the next save carries their version (contract admin-api).
    await waitFor(() => expect(served.deviceReads).toBeGreaterThan(1));
  });

  it('reports the server’s refusal of a test send instead of claiming it arrived', async () => {
    serve({ testRefused: 'test_device_no_token' });
    renderComposer();

    await fill();
    await userEvent.click(screen.getByRole('button', { name: 'إرسال تجريبي لجهازي' }));

    expect(await screen.findByText('الجهاز المحفوظ بلا رمز إشعار. أعد تسجيل الجهاز')).toBeInTheDocument();
    expect(screen.queryByText(/أُرسل التجريبي/)).not.toBeInTheDocument();
    expect(screen.queryByTestId('test-result')).not.toBeInTheDocument();
  });

  it('keeps send disabled until both title and body have something', async () => {
    serve();
    renderComposer();

    expect(screen.getByRole('button', { name: 'إرسال الآن' })).toBeDisabled();
    await userEvent.type(screen.getByLabelText('العنوان'), TITLE);
    expect(screen.getByRole('button', { name: 'إرسال الآن' })).toBeDisabled();
    await userEvent.type(screen.getByLabelText('النص'), BODY);
    expect(screen.getByRole('button', { name: 'إرسال الآن' })).toBeEnabled();
  });
});
