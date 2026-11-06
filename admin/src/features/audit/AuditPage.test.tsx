import { screen, waitFor, within } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { http, HttpResponse } from 'msw';
import type { ReactElement } from 'react';
import { useLocation } from 'react-router-dom';
import { describe, expect, it } from 'vitest';

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
  entity: 'channel',
  entity_id: 5512,
  action: 'update',
  summary_fields: ['frequency_mhz'],
  has_notification: true,
};

const passwordReset: Entry = {
  id: 7712,
  created_at: '2026-11-06T16:00:00Z',
  actor: { kind: 'admin', id: 1, name: 'سارة حسن' },
  entity: 'admin_user',
  entity_id: 5,
  action: 'reset_password',
  summary_fields: ['password'],
  has_notification: false,
};

const systemImport: Entry = {
  id: 7713,
  created_at: '2026-11-06T15:00:00Z',
  actor: { kind: 'importer', id: null, name: 'ysscores' },
  entity: 'match',
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
}

function serve(options: { rows?: Entry[]; diff?: unknown; notification?: unknown } = {}): Served {
  const served: Served = { lists: [], details: [] };
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
    renderAudit('/audit?entity=channel&admin_user_id=3&from=2026-10-30&to=2026-11-06');

    await waitFor(() => expect(served.lists.length).toBeGreaterThan(0));

    expect(served.lists[0]?.searchParams.get('entity')).toBe('channel');
    expect(served.lists[0]?.searchParams.get('admin_user_id')).toBe('3');
    expect(served.lists[0]?.searchParams.get('from')).toBe('2026-10-30');
    expect(served.lists[0]?.searchParams.get('to')).toBe('2026-11-06');
    expect(screen.getByLabelText('النوع')).toHaveValue('channel');
  });

  it('writes a changed filter back into the URL', async () => {
    serve();
    renderAudit();

    await screen.findByText(/محمد علي/);
    await userEvent.selectOptions(screen.getByLabelText('النوع'), 'admin_user');

    expect(screen.getByTestId('location')).toHaveTextContent('/audit?entity=admin_user');
  });

  it('lists the actor and the entity, with an importer named instead of a person', async () => {
    serve();
    renderAudit();

    expect(await screen.findByText(/محمد علي/)).toBeInTheDocument();
    expect(screen.getByText(/سارة حسن/)).toBeInTheDocument();
    expect(screen.getByText(/ysscores/)).toBeInTheDocument();
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
    expect(within(detail).getByText(/channel\/5512/)).toBeInTheDocument();
  });

  it('shows {"password": "changed"} raw on both sides, without throwing', async () => {
    serve({ diff: { password: 'changed' } });
    renderAudit();

    const detail = await screen.findByTestId('audit-detail');
    expect(within(detail).getByTestId('diff-before')).toHaveTextContent('changed');
    expect(within(detail).getByTestId('diff-after')).toHaveTextContent('changed');
  });

  it('links to the push with its counts when the entry produced one', async () => {
    serve();
    renderAudit();

    const detail = await screen.findByTestId('audit-detail');

    expect(within(detail).getByText(/1,233/)).toBeInTheDocument();
    expect(within(detail).getByText(/1,240/)).toBeInTheDocument();
    expect(within(detail).getByRole('link', { name: 'صندوق الإرسال' })).toHaveAttribute('href', '/notifications');
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
