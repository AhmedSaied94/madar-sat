import { screen } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { http, HttpResponse } from 'msw';
import type { ReactElement, ReactNode } from 'react';
import { describe, expect, it } from 'vitest';

import { ToastProvider } from '../components/Toast/Toast';
import { SessionProvider } from '../features/auth/session';
import { renderRtl } from '../test/render';
import { server } from '../test/server';
import { AppRoutes } from './App';

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

describe('App routes', () => {
  it('sends a visitor without a session to /login', () => {
    renderRtl(<AppRoutes />, { route: '/matches', wrapper: Providers });

    expect(screen.getByRole('heading', { name: 'سجل دخول للوحة التحكم' })).toBeInTheDocument();
    expect(screen.queryByRole('navigation', { name: 'القائمة الرئيسية' })).not.toBeInTheDocument();
  });

  it('opens the A0 shell on the requested page after login, and returns to /login on logout', async () => {
    server.use(http.post('*/admin/api/auth/login', loginOk));
    renderRtl(<AppRoutes />, { route: '/matches', wrapper: Providers });

    await userEvent.type(screen.getByLabelText('البريد الإلكتروني'), 'admin@example.com');
    await userEvent.type(screen.getByLabelText('كلمة المرور'), 'correct-horse');
    await userEvent.click(screen.getByRole('button', { name: 'دخول' }));

    const nav = await screen.findByRole('navigation', { name: 'القائمة الرئيسية' });
    expect(nav).toBeInTheDocument();
    expect(screen.getByRole('link', { name: /المباريات/ })).toHaveAttribute('aria-current', 'page');
    expect(screen.getByRole('banner')).toHaveTextContent('محمد علي');
    expect(screen.getByRole('heading', { name: 'هذا القسم قيد البناء' })).toBeInTheDocument();

    await userEvent.click(screen.getByRole('button', { name: 'تسجيل الخروج' }));
    expect(screen.getByRole('heading', { name: 'سجل دخول للوحة التحكم' })).toBeInTheDocument();
  });
});
