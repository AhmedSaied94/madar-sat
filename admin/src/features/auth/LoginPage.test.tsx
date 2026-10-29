import { act, screen } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { delay, http, HttpResponse } from 'msw';
import { Route, Routes } from 'react-router-dom';
import { describe, expect, it, vi } from 'vitest';

// Orval's handlers answer with the spec's named examples (backend/openapi/admin.json), the same
// bodies Prism serves: login_ok (200), invalid_credentials (401), validation_error (422), account_locked (429).
import {
  getLoginAdminApiAuthLoginPostMockHandler200 as loginOk,
  getLoginAdminApiAuthLoginPostMockHandler401 as invalidCredentials,
  getLoginAdminApiAuthLoginPostMockHandler422 as validationError,
  getLoginAdminApiAuthLoginPostMockHandler429 as accountLocked,
  getLoginAdminApiAuthLoginPostResponseMock200 as loginOkBody,
  getLoginAdminApiAuthLoginPostResponseMock401 as invalidCredentialsBody,
  getLoginAdminApiAuthLoginPostResponseMock422 as validationErrorBody,
  getLoginAdminApiAuthLoginPostResponseMock429 as accountLockedBody,
} from '../../api/generated/admin.msw';
import { server } from '../../test/server';
import { renderRtl } from '../../test/render';
import { LoginPage } from './LoginPage';
import { SessionProvider } from './session';

const SERVER_MESSAGES = [invalidCredentialsBody(), validationErrorBody(), accountLockedBody()].map(
  (body) => body.error.message,
);

function renderLogin() {
  renderRtl(
    <Routes>
      <Route path="/login" element={<LoginPage />} />
      <Route path="/" element={<p>الصفحة الرئيسية</p>} />
    </Routes>,
    { route: '/login', wrapper: SessionProvider },
  );
}

async function submit(email = 'sara@example.com', password = 'correct-horse') {
  await userEvent.type(screen.getByLabelText('البريد الإلكتروني'), email);
  await userEvent.type(screen.getByLabelText('كلمة المرور'), password);
  await userEvent.click(screen.getByRole('button', { name: 'دخول' }));
}

function expectNoServerMessage() {
  for (const message of SERVER_MESSAGES) {
    expect(screen.queryByText(message, { exact: false })).not.toBeInTheDocument();
  }
}

describe('LoginPage (A1)', () => {
  it('renders the default state from the Login board', () => {
    renderLogin();

    expect(screen.getByRole('heading', { name: 'سجل دخول للوحة التحكم' })).toBeInTheDocument();
    expect(screen.getByRole('form', { name: 'تسجيل الدخول' })).toBeInTheDocument();
    expect(screen.getByLabelText('البريد الإلكتروني')).toHaveAttribute('dir', 'ltr');
    expect(screen.getByLabelText('كلمة المرور')).toHaveAttribute('type', 'password');
    expect(screen.getByRole('button', { name: 'دخول' })).toBeEnabled();
    expect(screen.getByText('متاح فقط عبر شبكة WireGuard')).toBeInTheDocument();
    expect(screen.queryByRole('alert')).not.toBeInTheDocument();
  });

  it('shows and hides the password', async () => {
    renderLogin();

    await userEvent.click(screen.getByRole('button', { name: 'إظهار كلمة المرور' }));
    expect(screen.getByLabelText('كلمة المرور')).toHaveAttribute('type', 'text');
    await userEvent.click(screen.getByRole('button', { name: 'إخفاء كلمة المرور' }));
    expect(screen.getByLabelText('كلمة المرور')).toHaveAttribute('type', 'password');
  });

  it('validates in Arabic before calling the API', async () => {
    renderLogin();

    await userEvent.type(screen.getByLabelText('البريد الإلكتروني'), 'not-an-email');
    await userEvent.click(screen.getByRole('button', { name: 'دخول' }));

    expect(await screen.findByText('أدخل بريداً إلكترونياً صحيحاً')).toBeInTheDocument();
    expect(screen.getByText('أدخل كلمة المرور')).toBeInTheDocument();
    expect(screen.getByLabelText('البريد الإلكتروني')).toHaveAttribute('aria-invalid', 'true');
  });

  it('shows the submitting state while the request is in flight', async () => {
    server.use(
      loginOk(async () => {
        await delay('infinite');
        return loginOkBody();
      }),
    );
    renderLogin();

    await submit();

    const button = await screen.findByRole('button', { name: 'جارٍ الدخول…' });
    expect(button).toBeDisabled();
    expect(button).toHaveAttribute('aria-busy', 'true');
  });

  it('signs in on login_ok, keeps the token out of browser storage, and leaves /login', async () => {
    const token = loginOkBody().data?.access_token;
    expect(token).toBeTruthy();
    server.use(loginOk());
    renderLogin();

    await submit();

    expect(await screen.findByText('الصفحة الرئيسية')).toBeInTheDocument();
    expect(window.localStorage).toHaveLength(0);
    expect(window.sessionStorage).toHaveLength(0);
    expect(document.cookie).not.toContain(token);
  });

  it('shows invalid_credentials with the attempts left, from error.code only', async () => {
    server.use(invalidCredentials());
    renderLogin();

    await submit();

    expect(await screen.findByRole('alert')).toHaveTextContent('إيميل أو باسوورد غلط');
    expect(screen.getByText('تبقّت 3 محاولات قبل الإيقاف المؤقت')).toBeInTheDocument();
    expect(screen.getByLabelText('البريد الإلكتروني')).toHaveAttribute('aria-invalid', 'true');
    expect(screen.getByRole('button', { name: 'دخول' })).toBeEnabled();
    expectNoServerMessage();
  });

  it('shows the lockout panel counting down from 14:32 and blocks sign-in', async () => {
    vi.useFakeTimers({ shouldAdvanceTime: true });
    server.use(accountLocked());
    renderLogin();

    await submit();

    const panel = await screen.findByRole('alert');
    expect(panel).toHaveTextContent('تم إيقاف الدخول مؤقتاً');
    expect(panel).toHaveTextContent('14:32');
    expect(screen.getByRole('button', { name: 'دخول' })).toBeDisabled();

    act(() => vi.advanceTimersByTime(1000));
    expect(screen.getByRole('alert')).toHaveTextContent('14:31');
    expectNoServerMessage();
  });

  it('shows validation_error in Arabic', async () => {
    server.use(validationError());
    renderLogin();

    await submit();

    expect(await screen.findByRole('alert')).toHaveTextContent('راجع البيانات المدخلة ثم حاول مرة أخرى');
    expectNoServerMessage();
  });

  it('maps a network failure to Arabic copy', async () => {
    server.use(http.post('*/admin/api/auth/login', () => HttpResponse.error()));
    renderLogin();

    await submit();

    expect(await screen.findByRole('alert')).toHaveTextContent('تعذّر الاتصال بالخادم');
  });
});
