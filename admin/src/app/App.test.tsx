import { screen, waitFor } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { http, HttpResponse } from 'msw';
import type { ReactElement, ReactNode } from 'react';
import { createMemoryRouter, RouterProvider } from 'react-router-dom';
import { describe, expect, it } from 'vitest';

import { ToastProvider } from '../components/Toast/Toast';
import { SessionProvider } from '../features/auth/session';
import { renderRtl } from '../test/render';
import { server } from '../test/server';
import { appRoutes } from './App';

function Providers({ children }: { children: ReactNode }): ReactElement {
  return (
    <SessionProvider>
      <ToastProvider>{children}</ToastProvider>
    </SessionProvider>
  );
}

const loginOk = () =>
  HttpResponse.json({
    success: true,
    data: {
      access_token: 'header.payload.signature',
      token_type: 'Bearer',
      expires_in: 900,
      admin: { id: 1, email: 'admin@example.com', name: 'محمد علي', role: 'admin' },
    },
    error: null,
    meta: {},
  });

/** The app's own routes in a memory data router (A4 needs `useBlocker`, which a data router provides). */
function renderApp(route: string) {
  return renderRtl(<RouterProvider router={createMemoryRouter(appRoutes, { initialEntries: [route] })} />, {
    withRouter: false,
    wrapper: Providers,
  });
}

async function signIn(): Promise<void> {
  await userEvent.type(await screen.findByLabelText('البريد الإلكتروني'), 'admin@example.com');
  await userEvent.type(screen.getByLabelText('كلمة المرور'), 'correct-horse');
  await userEvent.click(screen.getByRole('button', { name: 'دخول' }));
}

describe('App routes', () => {
  it('sends a visitor without a session to /login', async () => {
    renderApp('/matches');

    expect(await screen.findByRole('heading', { name: 'سجل دخول للوحة التحكم' })).toBeInTheDocument();
    expect(screen.queryByRole('navigation', { name: 'القائمة الرئيسية' })).not.toBeInTheDocument();
  });

  it('keeps A4 behind the session guard too', async () => {
    renderApp('/matches/new');

    expect(await screen.findByRole('heading', { name: 'سجل دخول للوحة التحكم' })).toBeInTheDocument();
  });

  it('waits for the refresh cookie on a reload, and stays on the page instead of going to /login', async () => {
    server.use(http.post('*/admin/api/auth/refresh', loginOk));
    renderApp('/matches');

    // Before the restore settles the guard waits; it never shows the login form.
    expect(screen.getByText('جارٍ استعادة الجلسة')).toHaveAttribute('role', 'status');
    expect(screen.queryByRole('heading', { name: 'سجل دخول للوحة التحكم' })).not.toBeInTheDocument();

    const nav = await screen.findByRole('navigation', { name: 'القائمة الرئيسية' });
    expect(nav).toBeInTheDocument();
    expect(screen.getByRole('link', { name: /المباريات/ })).toHaveAttribute('aria-current', 'page');
  });

  it('opens the A3 screen on /matches after login, and returns to /login on logout', async () => {
    server.use(http.post('*/admin/api/auth/login', loginOk));
    renderApp('/matches');

    await signIn();

    const nav = await screen.findByRole('navigation', { name: 'القائمة الرئيسية' });
    expect(nav).toBeInTheDocument();
    expect(screen.getByRole('link', { name: /المباريات/ })).toHaveAttribute('aria-current', 'page');
    expect(screen.getByRole('banner')).toHaveTextContent('محمد علي');

    await userEvent.click(screen.getByRole('button', { name: 'تسجيل الخروج' }));
    expect(screen.getByRole('heading', { name: 'سجل دخول للوحة التحكم' })).toBeInTheDocument();
  });

  it('shows the placeholder on a section that arrives on a later day', async () => {
    server.use(http.post('*/admin/api/auth/login', loginOk));
    renderApp('/audit');

    await signIn();

    expect(await screen.findByRole('heading', { name: 'هذا القسم قيد البناء' })).toBeInTheDocument();
  });

  it('clears the query cache on sign-out, so a second editor never sees the first one’s data', async () => {
    server.use(http.post('*/admin/api/auth/login', loginOk));
    const { queryClient } = renderApp('/matches');

    await signIn();
    await screen.findByRole('navigation', { name: 'القائمة الرئيسية' });
    await waitFor(() => expect(queryClient.getQueryCache().getAll().length).toBeGreaterThan(0));

    await userEvent.click(screen.getByRole('button', { name: 'تسجيل الخروج' }));

    // The cached matches, lists and their versions go with the session (A-R2-10).
    await waitFor(() => expect(queryClient.getQueryCache().getAll()).toHaveLength(0));
  });
});
