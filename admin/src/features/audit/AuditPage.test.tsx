import { screen, waitFor, within } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { http, HttpResponse } from 'msw';
import type { ReactElement } from 'react';
import { useLocation } from 'react-router-dom';
import { afterEach, describe, expect, it, vi } from 'vitest';

import { renderRtl } from '../../test/render';
import { server } from '../../test/server';
import { envelope, Providers, restoreAs } from '../../test/signedIn';
import { AuditPage } from './AuditPage';

// A17 (contract admin-screens "A17: audit", board "Audit"): the log on one side, the selected entry's
// diff on the other — قبل / بعد in columns, any other shape shown raw and never thrown on — with links
// to the entity and to the push it produced, and no restore action (FR-045).

function LocationProbe(): ReactElement {
  const { pathname, search } = useLocation();
  return (
    <output data-testid="location" hidden>
      {`${pathname}${search}`}
    </output>
  );
}

interface Entry {
  id: number;
  created_at: string;
  actor: { kind: 'admin' | 'importer' | 'system'; id: number | null; name: string | null };
  entity: string;
  entity_id: number;
  action: string;
  summary_fields: string[];
  has_notification: boolean;
}

const frequencyChange: Entry = {
  id: 7711,
  created_at: '2026-11-06T17:00:00Z',
  actor: { kind: 'admin', id: 3, name: 'محمد علي' },
  entity: 'channels',
  entity_id: 5512,
  action: 'update',
  summary_fields: ['frequency_mhz'],
  has_notification: true,
};

const passwordReset: Entry = {
  id: 7712,
  created_at: '2026-11-06T16:00:00Z',
  actor: { kind: 'admin', id: 1, name: 'سارة حسن' },
  entity: 'admin_users',
  entity_id: 5,
  action: 'reset_password',
  summary_fields: ['password'],
  has_notification: false,
};

const systemImport: Entry = {
  id: 7713,
  created_at: '2026-11-06T15:00:00Z',
  actor: { kind: 'importer', id: null, name: 'ysscores' },
  entity: 'matches',
  entity_id: 48213,
  action: 'import',
  summary_fields: ['status'],
  has_notification: false,
};

const frequencyDiff = {
  frequency: [
    { mhz: 11766, pol: 'H', sr: 27500 },
    { mhz: 11013, pol: 'H', sr: 27500 },
  ],
  locked_fields: [[], ['frequency']],
};

interface Served {
  lists: URL[];
  details: string[];
  channels: string[];
}

const sourceHealth = (name: string): Record<string, unknown> => ({
  name,
  kind: 'scraper',
  is_enabled: true,
  breaker: 'closed',
  breaker_opened_at: null,
  consecutive_failures: 0,
  paused: false,
  last_success_at: null,
  last_run: null,
  items_24h: [],
  error_rate_24h: null,
  running: false,
  live: null,
});

function serve(options: { rows?: Entry[]; diff?: unknown; notification?: unknown } = {}): Served {
  const served: Served = { lists: [], details: [], channels: [] };
  const rows = options.rows ?? [frequencyChange, passwordReset, systemImport];
  const diff = 'diff' in options ? options.diff : frequencyDiff;
  const notification =
    'notification' in options
      ? options.notification
      : { id: 9012, type: 'frequency_changed', status: 'sent', sent: 1233, failed: 7 };

  server.use(
    http.get('*/admin/api/audit', ({ request }) => {
      served.lists.push(new URL(request.url));
      return HttpResponse.json(envelope(rows, { next_cursor: null }));
    }),
    http.get('*/admin/api/audit/:id', ({ params }) => {
      served.details.push(String(params['id']));
      const row = rows.find((entry) => String(entry.id) === String(params['id'])) ?? rows[0];
      if (!row) throw new Error('the fixture has no entry to serve');
      return HttpResponse.json(envelope({ ...row, diff, notification: row.has_notification ? notification : null }));
    }),
    http.get('*/admin/api/sources', () =>
      HttpResponse.json(envelope([sourceHealth('ysscores'), sourceHealth('livesoccertv')])),
    ),
    http.get('*/admin/api/channels/:id', ({ params }) => {
      served.channels.push(String(params['id']));
      return HttpResponse.json(envelope(null), { status: 404 });
    }),
  );

  return served;
}

function renderAudit(route = '/audit') {
  restoreAs('admin');
  return renderRtl(
    <>
      <AuditPage />
      <LocationProbe />
    </>,
    { route, wrapper: Providers },
  );
}

describe('A17 the audit log', () => {
  it('reads the filters from the URL and sends them to the server', async () => {
    const served = serve();
    renderAudit('/audit?entity=channels&admin_user_id=3&from=2026-10-30&to=2026-11-06');

    await waitFor(() => expect(served.lists.length).toBeGreaterThan(0));

    expect(served.lists[0]?.searchParams.get('entity')).toBe('channels');
    expect(served.lists[0]?.searchParams.get('admin_user_id')).toBe('3');
    expect(served.lists[0]?.searchParams.get('from')).toBe('2026-10-30');
    expect(served.lists[0]?.searchParams.get('to')).toBe('2026-11-06');
    expect(screen.getByLabelText('النوع')).toHaveValue('channels');
  });

  it('writes a changed filter back into the URL', async () => {
    serve();
    renderAudit();

    await screen.findByText(/محمد علي/);
    await userEvent.selectOptions(screen.getByLabelText('النوع'), 'admin_users');

    expect(screen.getByTestId('location')).toHaveTextContent('/audit?entity=admin_users');
  });

  // A-R1-3: the server stores each service's ENTITY (backend/app/services/admin/*.py) and filters by
  // equality, so every choice must send exactly that name.
  it.each([
    ['قناة', 'channels'],
    ['مباراة', 'matches'],
    ['فريق', 'teams'],
    ['بطولة', 'competitions'],
    ['قمر', 'satellites'],
    ['معلق', 'commentators'],
    ['حقوق بث', 'rights_holder'],
    ['مستخدم', 'admin_users'],
  ])('filters «%s» by the server’s entity name %s (A-R1-3)', async (label, entity) => {
    const served = serve();
    renderAudit();

    await screen.findByText(/محمد علي/);
    await userEvent.selectOptions(screen.getByLabelText('النوع'), within(screen.getByLabelText('النوع')).getByRole('option', { name: label }));

    await waitFor(() => expect(served.lists.at(-1)?.searchParams.get('entity')).toBe(entity));
  });

  it('names a server-shaped entry’s entity in Arabic (A-R1-3)', async () => {
    serve();
    renderAudit();

    const row = (await screen.findByText(/محمد علي/)).closest('button') as HTMLElement;
    expect(row).toHaveTextContent('قناة');
    const imported = within(screen.getByRole('list')).getByText(/ysscores/).closest('button') as HTMLElement;
    expect(imported).toHaveTextContent('مباراة');
  });

  it('opens the channel’s editor from «فتح القناة» (A-R1-3)', async () => {
    const served = serve();
    renderAudit();

    const detail = await screen.findByTestId('audit-detail');
    await userEvent.click(await within(detail).findByRole('button', { name: 'فتح القناة' }));

    await waitFor(() => expect(served.channels).toContain('5512'));
    // The editor opens in place; nothing navigates to a route the app doesn't have.
    expect(screen.getByTestId('location')).toHaveTextContent(/^\/audit$/);
  });

  it('links a match entry to its editor (A-R1-3)', async () => {
    serve({ rows: [systemImport] });
    renderAudit();

    const detail = await screen.findByTestId('audit-detail');
    expect(await within(detail).findByRole('link', { name: 'فتح المباراة' })).toHaveAttribute('href', '/matches/48213');
    expect(within(detail).queryByRole('button', { name: 'فتح القناة' })).not.toBeInTheDocument();
  });

  it('lists the actor and the entity, with an importer named instead of a person', async () => {
    serve();
    renderAudit();

    expect(await screen.findByText(/محمد علي/)).toBeInTheDocument();
    expect(screen.getByText(/سارة حسن/)).toBeInTheDocument();
    expect(within(screen.getByRole('list')).getByText(/ysscores/)).toBeInTheDocument();
  });

  it('opens the first entry and shows its diff in قبل / بعد columns', async () => {
    const served = serve();
    renderAudit();

    await waitFor(() => expect(served.details.length).toBeGreaterThan(0));

    const detail = await screen.findByTestId('audit-detail');
    expect(within(detail).getByText('قبل')).toBeInTheDocument();
    expect(within(detail).getByText('بعد')).toBeInTheDocument();
    expect(within(detail).getByTestId('diff-before')).toHaveTextContent('11766');
    expect(within(detail).getByTestId('diff-after')).toHaveTextContent('11013');
    expect(within(detail).getByText(/channels\/5512/)).toBeInTheDocument();
  });

  it('shows {"password": "changed"} raw on both sides, without throwing', async () => {
    const served = serve({ diff: { password: 'changed' } });
    renderAudit();

    await waitFor(() => expect(served.details.length).toBeGreaterThan(0));
    const detail = await screen.findByTestId('audit-detail');
    expect(within(detail).getByTestId('diff-before')).toHaveTextContent('changed');
    expect(within(detail).getByTestId('diff-after')).toHaveTextContent('changed');
  });

  it('links to the push with its counts when the entry produced one', async () => {
    const served = serve();
    renderAudit();

    await waitFor(() => expect(served.details.length).toBeGreaterThan(0));
    const detail = await screen.findByTestId('audit-detail');

    expect(within(detail).getByText(/1,233/)).toBeInTheDocument();
    expect(within(detail).getByText(/1,240/)).toBeInTheDocument();
    expect(within(detail).getByRole('link', { name: 'صندوق الإرسال' })).toHaveAttribute('href', '/notifications');
  });

  describe('the period, in Cairo days (A-R1-4)', () => {
    afterEach(() => {
      vi.useRealTimers();
    });

    // 2026-11-09 12:00 in Cairo (UTC+2 since DST ended on 29 October).
    const NOW = new Date('2026-11-09T10:00:00Z');

    it.each([
      ['اليوم', '2026-11-08T22:00:00.000Z'],
      ['آخر 7 أيام', '2026-11-02T22:00:00.000Z'],
      // 2026-10-11 was still summer time in Cairo (UTC+3).
      ['آخر 30 يوماً', '2026-10-10T21:00:00.000Z'],
    ])('«%s» runs from %s to the end of today', async (label, from) => {
      vi.useFakeTimers({ toFake: ['Date'] });
      vi.setSystemTime(NOW);
      const served = serve();
      renderAudit();

      await screen.findByText(/محمد علي/);
      await userEvent.selectOptions(screen.getByLabelText('الفترة'), within(screen.getByLabelText('الفترة')).getByRole('option', { name: label }));

      await waitFor(() => expect(served.lists.at(-1)?.searchParams.get('from')).toBe(from));
      expect(served.lists.at(-1)?.searchParams.get('to')).toBe('2026-11-09T22:00:00.000Z');
    });

    it('«الكل» sends no bounds', async () => {
      const served = serve();
      renderAudit('/audit?period=today');

      await screen.findByText(/محمد علي/);
      await userEvent.selectOptions(screen.getByLabelText('الفترة'), within(screen.getByLabelText('الفترة')).getByRole('option', { name: 'الكل' }));

      await waitFor(() => expect(served.lists.at(-1)?.searchParams.has('from')).toBe(false));
      expect(served.lists.at(-1)?.searchParams.has('to')).toBe(false);
    });
  });

  describe('the importer filter (A-R1-5)', () => {
    it('sends the importer as `source`, kept in the URL', async () => {
      const served = serve();
      renderAudit();

      await screen.findByText(/محمد علي/);
      await userEvent.selectOptions(await screen.findByLabelText('المستورد'), await screen.findByRole('option', { name: 'ysscores' }));

      await waitFor(() => expect(served.lists.at(-1)?.searchParams.get('source')).toBe('ysscores'));
      expect(served.lists.at(-1)?.searchParams.has('admin_user_id')).toBe(false);
      expect(screen.getByTestId('location')).toHaveTextContent('/audit?source=ysscores');
    });

    it('reads it back from the URL', async () => {
      const served = serve();
      renderAudit('/audit?source=livesoccertv');

      await waitFor(() => expect(served.lists.length).toBeGreaterThan(0));
      expect(served.lists[0]?.searchParams.get('source')).toBe('livesoccertv');
      expect(await screen.findByLabelText('المستورد')).toHaveValue('livesoccertv');
    });

    it('clears the importer when a user is chosen, and the user when an importer is', async () => {
      const served = serve();
      renderAudit('/audit?source=ysscores');

      await screen.findByText(/محمد علي/);
      const user = screen.getByLabelText('المستخدم');
      const firstAdmin = await waitFor(() => {
        const option = within(user).getAllByRole('option')[1];
        if (!option) throw new Error('no admin option yet');
        return option;
      });
      await userEvent.selectOptions(user, firstAdmin);

      await waitFor(() => expect(served.lists.at(-1)?.searchParams.has('admin_user_id')).toBe(true));
      expect(served.lists.at(-1)?.searchParams.has('source')).toBe(false);
      expect(screen.getByLabelText('المستورد')).toHaveValue('');

      await userEvent.selectOptions(screen.getByLabelText('المستورد'), screen.getByRole('option', { name: 'livesoccertv' }));
      await waitFor(() => expect(served.lists.at(-1)?.searchParams.get('source')).toBe('livesoccertv'));
      expect(served.lists.at(-1)?.searchParams.has('admin_user_id')).toBe(false);
      expect(screen.getByLabelText('المستخدم')).toHaveValue('');
    });
  });

  it('offers no restore action (FR-045)', async () => {
    serve();
    renderAudit();

    await screen.findByTestId('audit-detail');

    expect(screen.queryByRole('button', { name: /استرجاع/ })).not.toBeInTheDocument();
  });

  it('refuses the screen to an editor', async () => {
    serve();
    restoreAs('editor');
    renderRtl(<AuditPage />, { route: '/audit', wrapper: Providers });

    expect(await screen.findByText('صلاحيتك لا تسمح بهذا الإجراء')).toBeInTheDocument();
  });
});
