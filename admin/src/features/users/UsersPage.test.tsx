import { screen, waitFor, within } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { http, HttpResponse } from 'msw';
import { describe, expect, it } from 'vitest';

import { renderRtl } from '../../test/render';
import { server } from '../../test/server';
import { envelope, Providers, refusal, restoreAs } from '../../test/signedIn';
import { UsersPage } from './UsersPage';

// A16 (contract admin-screens "A16: users", board "Users"): the accounts with their status and last
// login, a drawer for a new one, the temporary password shown once and then gone from the DOM and the
// cache, role changes, reset and deactivate behind `ConfirmDialog`, and the server's two refusals said
// in the drawer.

interface Row {
  id: number;
  email: string;
  name: string;
  role: 'admin' | 'editor';
  is_active: boolean;
  locked_for_s: number | null;
  last_login_at: string | null;
  must_change_password: boolean;
}

const admin: Row = {
  id: 1,
  email: 'mohamed@example.com',
  name: 'محمد علي',
  role: 'admin',
  is_active: true,
  locked_for_s: null,
  last_login_at: '2026-11-06T09:12:00Z',
  must_change_password: false,
};

const active: Row = {
  id: 4,
  email: 'sara@example.com',
  name: 'سارة حسن',
  role: 'editor',
  is_active: true,
  locked_for_s: null,
  last_login_at: '2026-11-06T09:00:00Z',
  must_change_password: false,
};

const locked: Row = {
  id: 5,
  email: 'youssef@example.com',
  name: 'يوسف عمر',
  role: 'editor',
  is_active: true,
  locked_for_s: 660,
  last_login_at: '2026-11-05T20:40:00Z',
  must_change_password: false,
};

const disabled: Row = {
  id: 6,
  email: 'nour@example.com',
  name: 'نور كمال',
  role: 'editor',
  is_active: false,
  locked_for_s: null,
  last_login_at: '2026-09-12T10:00:00Z',
  must_change_password: false,
};

interface Served {
  patches: { url: string; body: Record<string, unknown>; ifMatch: string | null }[];
  creates: Record<string, unknown>[];
  resets: { url: string; ifMatch: string | null }[];
}

/** The list and its three writes, keeping the ETag the client must echo. */
function serve(
  options: { rows?: Row[]; etag?: string; resetTemporary?: string; createTemporary?: string } = {},
): Served {
  const served: Served = { patches: [], creates: [], resets: [] };
  const rows = options.rows ?? [admin, active, locked, disabled];
  const etag = options.etag ?? '"users-1"';

  server.use(
    http.get('*/admin/api/users', () => HttpResponse.json(envelope(rows), { headers: { ETag: etag } })),
    http.post('*/admin/api/users', async ({ request }) => {
      const body = (await request.json()) as Record<string, unknown>;
      served.creates.push(body);
      return HttpResponse.json(
        envelope({ user: { ...active, id: 7, email: body['email'], name: body['name'], role: body['role'] }, temporary_password: options.createTemporary ?? 'k7Q-rv2m-X9tp' }),
        { status: 201, headers: { ETag: '"users-2"', 'Cache-Control': 'no-store' } },
      );
    }),
    http.patch('*/admin/api/users/:id', async ({ request, params }) => {
      const body = (await request.json()) as Record<string, unknown>;
      served.patches.push({ url: String(params['id']), body, ifMatch: request.headers.get('If-Match') });
      return HttpResponse.json(envelope({ ...active, ...body }), { headers: { ETag: '"users-2"' } });
    }),
    http.post('*/admin/api/users/:id/reset-password', ({ request, params }) => {
      served.resets.push({ url: String(params['id']), ifMatch: request.headers.get('If-Match') });
      return HttpResponse.json(
        envelope({ user: active, temporary_password: options.resetTemporary ?? 'r2T-bv8n-Q1wm' }),
        { headers: { ETag: '"users-2"', 'Cache-Control': 'no-store' } },
      );
    }),
  );

  return served;
}

function renderUsers() {
  restoreAs('admin');
  return renderRtl(<UsersPage />, { route: '/users', wrapper: Providers });
}

const rowOf = async (name: string): Promise<HTMLElement> => (await screen.findByText(name)).closest('tr') as HTMLElement;

describe('A16 the accounts', () => {
  it('renders the board’s columns', async () => {
    serve();
    renderUsers();

    await screen.findByText('محمد علي');

    expect(screen.getByRole('columnheader', { name: 'المستخدم' })).toBeInTheDocument();
    expect(screen.getByRole('columnheader', { name: 'الدور' })).toBeInTheDocument();
    expect(screen.getByRole('columnheader', { name: 'الحالة' })).toBeInTheDocument();
    expect(screen.getByRole('columnheader', { name: 'آخر دخول' })).toBeInTheDocument();
    expect(screen.getByRole('columnheader', { name: 'التحقق بخطوتين' })).toBeInTheDocument();
  });

  it('shows the three statuses, the locked one in minutes', async () => {
    serve();
    renderUsers();

    expect(within(await rowOf('محمد علي')).getByText('نشط')).toBeInTheDocument();
    expect(within(await rowOf('سارة حسن')).getByText('نشط')).toBeInTheDocument();
    expect(within(await rowOf('يوسف عمر')).getByText('مقفل مؤقتاً · 11 د')).toBeInTheDocument();
    expect(within(await rowOf('نور كمال')).getByText('معطّل')).toBeInTheDocument();
    // The board's TOTP mark is the «V2» chip; a deactivated account shows a dash instead.
    expect(within(await rowOf('محمد علي')).getByText('V2')).toBeInTheDocument();
    expect(within(await rowOf('نور كمال')).getByText('—')).toBeInTheDocument();
  });

  it('creates an account and shows its temporary password once, with a copy button', async () => {
    const served = serve();
    renderUsers();

    await screen.findByText('محمد علي');
    await userEvent.click(screen.getByRole('button', { name: 'مستخدم جديد' }));

    const drawer = await screen.findByRole('dialog');
    await userEvent.type(within(drawer).getByLabelText('الاسم'), 'ليلى منصور');
    await userEvent.type(within(drawer).getByLabelText('البريد الإلكتروني'), 'laila@example.com');
    await userEvent.click(within(drawer).getByRole('radio', { name: 'محرر' }));
    await userEvent.click(within(drawer).getByRole('button', { name: 'إنشاء الحساب' }));

    await waitFor(() => expect(served.creates).toHaveLength(1));
    expect(served.creates[0]).toEqual({ name: 'ليلى منصور', email: 'laila@example.com', role: 'editor' });

    const password = await screen.findByText('k7Q-rv2m-X9tp');
    expect(password).toBeInTheDocument();
    expect(screen.getByRole('button', { name: 'نسخ' })).toBeInTheDocument();
  });

  it('leaves no trace of the temporary password after the drawer closes, in the DOM or the cache', async () => {
    serve();
    const { queryClient } = renderUsers();

    await screen.findByText('محمد علي');
    await userEvent.click(screen.getByRole('button', { name: 'مستخدم جديد' }));
    const drawer = await screen.findByRole('dialog');
    await userEvent.type(within(drawer).getByLabelText('الاسم'), 'ليلى منصور');
    await userEvent.type(within(drawer).getByLabelText('البريد الإلكتروني'), 'laila@example.com');
    await userEvent.click(within(drawer).getByRole('button', { name: 'إنشاء الحساب' }));

    await screen.findByText('k7Q-rv2m-X9tp');
    await userEvent.click(screen.getByRole('button', { name: 'إغلاق' }));

    await waitFor(() => expect(screen.queryByText('k7Q-rv2m-X9tp')).not.toBeInTheDocument());
    // Nothing in React Query's cache holds it either: it is state of the drawer, not of the server.
    const cached = JSON.stringify(queryClient.getQueryCache().getAll().map((query) => query.state.data));
    expect(cached).not.toContain('k7Q-rv2m-X9tp');
  });

  it('changes a role, echoing the version it read', async () => {
    const served = serve();
    renderUsers();

    await screen.findByText('سارة حسن');
    await userEvent.click(within(await rowOf('سارة حسن')).getByRole('button', { name: 'خيارات' }));
    await userEvent.click(await screen.findByRole('menuitem', { name: 'تعديل' }));

    const drawer = await screen.findByRole('dialog');
    await userEvent.click(within(drawer).getByRole('radio', { name: 'مدير' }));
    await userEvent.click(within(drawer).getByRole('button', { name: 'حفظ' }));

    await waitFor(() => expect(served.patches).toHaveLength(1));
    expect(served.patches[0]).toMatchObject({ url: '4', body: { role: 'admin' }, ifMatch: '"users-1"' });
  });

  it('resets a password through ConfirmDialog and shows the new one once', async () => {
    const served = serve();
    renderUsers();

    await screen.findByText('يوسف عمر');
    await userEvent.click(within(await rowOf('يوسف عمر')).getByRole('button', { name: 'خيارات' }));
    await userEvent.click(await screen.findByRole('menuitem', { name: 'إعادة تعيين كلمة المرور' }));

    const confirm = await screen.findByRole('alertdialog');
    expect(within(confirm).getByText(/كلمة مرور مؤقتة جديدة/)).toBeInTheDocument();
    await userEvent.click(within(confirm).getByRole('button', { name: 'إعادة تعيين' }));

    await waitFor(() => expect(served.resets).toHaveLength(1));
    expect(served.resets[0]).toEqual({ url: '5', ifMatch: '"users-1"' });
    expect(await screen.findByText('r2T-bv8n-Q1wm')).toBeInTheDocument();
  });

  it('deactivates an active account through ConfirmDialog, then reactivates a disabled one', async () => {
    const served = serve();
    renderUsers();

    await screen.findByText('يوسف عمر');
    await userEvent.click(within(await rowOf('يوسف عمر')).getByRole('button', { name: 'خيارات' }));
    await userEvent.click(await screen.findByRole('menuitem', { name: 'تعطيل' }));
    const confirm = await screen.findByRole('alertdialog');
    await userEvent.click(within(confirm).getByRole('button', { name: 'تعطيل' }));

    await waitFor(() => expect(served.patches.at(-1)).toMatchObject({ body: { is_active: false } }));

    await screen.findByText('نور كمال');
    await userEvent.click(within(await rowOf('نور كمال')).getByRole('button', { name: 'خيارات' }));
    await userEvent.click(await screen.findByRole('menuitem', { name: 'إعادة تنشيط' }));

    await waitFor(() => expect(served.patches.at(-1)).toMatchObject({ url: '6', body: { is_active: true } }));
  });

  it('says cannot_change_self in the drawer for the signed-in account', async () => {
    serve();
    renderUsers();

    await screen.findByText('محمد علي');
    await userEvent.click(within(await rowOf('محمد علي')).getByRole('button', { name: 'خيارات' }));
    await userEvent.click(await screen.findByRole('menuitem', { name: 'تعديل' }));

    const drawer = await screen.findByRole('dialog');
    expect(within(drawer).getByText('لا يمكنك تغيير دورك أو تعطيل حسابك')).toBeInTheDocument();
    expect(within(drawer).getByRole('button', { name: 'تعطيل' })).toBeDisabled();
  });

  it('says cannot_change_self when the server refuses a demotion', async () => {
    serve();
    server.use(
      http.patch('*/admin/api/users/:id', () => HttpResponse.json(refusal('cannot_change_self'), { status: 409 })),
    );
    renderUsers();

    await screen.findByText('محمد علي');
    await userEvent.click(within(await rowOf('محمد علي')).getByRole('button', { name: 'خيارات' }));
    await userEvent.click(await screen.findByRole('menuitem', { name: 'تعديل' }));
    const drawer = await screen.findByRole('dialog');
    await userEvent.click(within(drawer).getByRole('radio', { name: 'محرر' }));
    await userEvent.click(within(drawer).getByRole('button', { name: 'حفظ' }));

    expect(await screen.findByText('لا يمكنك تغيير دورك أو تعطيل حسابك')).toBeInTheDocument();
  });

  it('says last_admin when the server refuses the last active admin', async () => {
    serve({ rows: [admin] });
    server.use(
      http.patch('*/admin/api/users/:id', () => HttpResponse.json(refusal('last_admin'), { status: 409 })),
    );
    renderUsers();

    await screen.findByText('محمد علي');
    await userEvent.click(within(await rowOf('محمد علي')).getByRole('button', { name: 'خيارات' }));
    await userEvent.click(await screen.findByRole('menuitem', { name: 'تعطيل' }));
    const confirm = await screen.findByRole('alertdialog');
    await userEvent.click(within(confirm).getByRole('button', { name: 'تعطيل' }));

    expect(await screen.findByText('لا يمكن تعطيل آخر مدير نشط. أضف مديراً آخر أولاً')).toBeInTheDocument();
  });

  it('shows ConflictDialog when the version moved under it', async () => {
    serve();
    server.use(
      http.patch('*/admin/api/users/:id', () =>
        HttpResponse.json(
          refusal('edit_conflict', { current_etag: '"users-9"', changed_by: { kind: 'admin', name: 'سارة حسن' }, changed_at: '2026-11-06T18:00:00Z' }),
          { status: 409 },
        ),
      ),
    );
    renderUsers();

    await screen.findByText('سارة حسن');
    await userEvent.click(within(await rowOf('سارة حسن')).getByRole('button', { name: 'خيارات' }));
    await userEvent.click(await screen.findByRole('menuitem', { name: 'تعديل' }));
    const drawer = await screen.findByRole('dialog');
    await userEvent.click(within(drawer).getByRole('radio', { name: 'مدير' }));
    await userEvent.click(within(drawer).getByRole('button', { name: 'حفظ' }));

    expect(await screen.findByText(/حُفظت نسخة أحدث من/)).toBeInTheDocument();
    expect(screen.getByRole('button', { name: 'إعادة التحميل' })).toBeInTheDocument();
  });

  it('refuses the screen to an editor', async () => {
    serve();
    restoreAs('editor');
    renderRtl(<UsersPage />, { route: '/users', wrapper: Providers });

    expect(await screen.findByText('صلاحيتك لا تسمح بهذا الإجراء')).toBeInTheDocument();
    expect(screen.queryByRole('table')).not.toBeInTheDocument();
  });
});
