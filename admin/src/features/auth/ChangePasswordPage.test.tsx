import { screen } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { http, HttpResponse } from 'msw';
import type { ReactElement, ReactNode } from 'react';
import { createMemoryRouter, RouterProvider } from 'react-router-dom';
import { describe, expect, it } from 'vitest';

import { ToastProvider } from '../../components/Toast/Toast';
import { SessionProvider } from '../../features/auth/session';
import { renderRtl } from '../../test/render';
import { server } from '../../test/server';
import { ADMIN, envelope, refusal } from '../../test/signedIn';
import { appRoutes } from '../../app/App';

// The forced step (contract admin-screens "Change password"): a flagged account can't use the admin
// until it changes its password, and a `403 password_change_required` on any request leads there too.
// `auth/refresh` and `auth/me` keep working meanwhile, which is what stops a 403 on refresh from
// ending the session.

function Providers({ children }: { children: ReactNode }): ReactElement {
  return (
    <SessionProvider>
      <ToastProvider>{children}</ToastProvider>
    </SessionProvider>
  );
}

function renderApp(route: string) {
  return renderRtl(<RouterProvider router={createMemoryRouter(appRoutes, { initialEntries: [route] })} />, {
    withRouter: false,
    wrapper: Providers,
  });
}

const session = (admin: Record<string, unknown>): Record<string, unknown> =>
  envelope({
    access_token: 'header.payload.signature',
    token_type: 'Bearer',
    expires_in: 900,
    admin: { ...ADMIN, role: 'admin', ...admin },
  });

const serveRefresh = (admin: Record<string, unknown> = {}): void => {
  server.use(http.post('*/admin/api/auth/refresh', () => HttpResponse.json(session(admin))));
};

const serveLogin = (admin: Record<string, unknown> = {}): void => {
  server.use(http.post('*/admin/api/auth/login', () => HttpResponse.json(session(admin))));
};

const serveChangePassword = (): void => {
  server.use(http.post('*/admin/api/auth/change-password', () => HttpResponse.json(session({}))));
};

async function fillPasswords(current: string, next: string): Promise<void> {
  await userEvent.type(await screen.findByLabelText('كلمة المرور الحالية'), current);
  await userEvent.type(screen.getByLabelText('كلمة المرور الجديدة'), next);
  await userEvent.type(screen.getByLabelText('تأكيد كلمة المرور الجديدة'), next);
  await userEvent.click(screen.getByRole('button', { name: 'حفظ كلمة المرور' }));
}

describe('the forced password change', () => {
  it('stops at the form after a login that carries the flag, with nothing else rendered', async () => {
    serveLogin({ must_change_password: true });
    renderApp('/feeds');

    await userEvent.type(await screen.findByLabelText('البريد الإلكتروني'), 'admin@example.com');
    await userEvent.type(screen.getByLabelText('كلمة المرور'), 'correct-horse');
    await userEvent.click(screen.getByRole('button', { name: 'دخول' }));

    expect(await screen.findByRole('heading', { name: 'تغيير كلمة المرور' })).toBeInTheDocument();
    expect(screen.queryByRole('navigation', { name: 'القائمة الرئيسية' })).not.toBeInTheDocument();
    expect(screen.queryByRole('heading', { name: 'هذا القسم قيد البناء' })).not.toBeInTheDocument();
  });

  it('leads there when any request answers 403 password_change_required', async () => {
    serveRefresh();
    server.use(http.get('*/admin/api/sources', () => HttpResponse.json(refusal('password_change_required'), { status: 403 })));
    renderApp('/sources');

    expect(await screen.findByRole('heading', { name: 'تغيير كلمة المرور' })).toBeInTheDocument();
    expect(screen.queryByRole('navigation', { name: 'القائمة الرئيسية' })).not.toBeInTheDocument();
  });

  it('returns to the app after the change, in place of the form', async () => {
    serveRefresh({ must_change_password: true });
    serveChangePassword();
    renderApp('/feeds');

    await fillPasswords('correct-horse', 'another-horse-battery');

    expect(await screen.findByRole('heading', { name: 'هذا القسم قيد البناء' })).toBeInTheDocument();
    expect(screen.queryByRole('heading', { name: 'تغيير كلمة المرور' })).not.toBeInTheDocument();
  });

  it('refuses a new password under 12 characters without calling the server', async () => {
    let called = 0;
    serveRefresh({ must_change_password: true });
    server.use(
      http.post('*/admin/api/auth/change-password', () => {
        called += 1;
        return HttpResponse.json(session({}));
      }),
    );
    renderApp('/feeds');

    await fillPasswords('correct-horse', 'short');

    expect(await screen.findByText(/12 حرفاً على الأقل/)).toBeInTheDocument();
    expect(called).toBe(0);
  });

  it('refuses a confirmation that differs', async () => {
    serveRefresh({ must_change_password: true });
    renderApp('/feeds');

    await userEvent.type(await screen.findByLabelText('كلمة المرور الحالية'), 'correct-horse');
    await userEvent.type(screen.getByLabelText('كلمة المرور الجديدة'), 'another-horse-battery');
    await userEvent.type(screen.getByLabelText('تأكيد كلمة المرور الجديدة'), 'another-horse-batterz');
    await userEvent.click(screen.getByRole('button', { name: 'حفظ كلمة المرور' }));

    expect(await screen.findByText('كلمتا المرور غير متطابقتين')).toBeInTheDocument();
  });

  it('shows the Arabic copy of password_unchanged', async () => {
    serveRefresh({ must_change_password: true });
    server.use(
      http.post('*/admin/api/auth/change-password', () =>
        HttpResponse.json(refusal('password_unchanged'), { status: 422 }),
      ),
    );
    renderApp('/feeds');

    await fillPasswords('correct-horse', 'correct-horse');

    expect(await screen.findByText('كلمة المرور الجديدة مثل الحالية. اختر كلمة أخرى')).toBeInTheDocument();
  });

  it('shows the Arabic copy of invalid_credentials', async () => {
    serveRefresh({ must_change_password: true });
    server.use(
      http.post('*/admin/api/auth/change-password', () => HttpResponse.json(refusal('invalid_credentials'), { status: 401 })),
    );
    renderApp('/feeds');

    await fillPasswords('wrong-horse', 'another-horse-battery');

    expect(await screen.findByText('إيميل أو باسوورد غلط')).toBeInTheDocument();
  });

  it('keeps the session when the refresh answers with a flagged account', async () => {
    let refreshed = 0;
    server.use(
      http.post('*/admin/api/auth/refresh', () => {
        refreshed += 1;
        return HttpResponse.json(session({ must_change_password: true }));
      }),
    );
    renderApp('/feeds');

    await screen.findByRole('heading', { name: 'تغيير كلمة المرور' });

    // The restore ran and was not treated as a refusal, so the editor is still signed in — the form,
    // not the login page, is what a refresh lands on (contract: auth/refresh stays exempt).
    expect(refreshed).toBe(1);
    expect(screen.queryByRole('heading', { name: 'سجل دخول للوحة التحكم' })).not.toBeInTheDocument();
  });
});
