import { HttpResponse, http } from 'msw';
import type { ReactElement, ReactNode } from 'react';

import { ToastProvider } from '../components/Toast/Toast';
import { SessionProvider } from '../features/auth/session';
import { server } from './server';

// The account every D6 screen renders inside, and the two wrappers a page needs to mount outside
// `App` (session + toasts). A test that starts signed in answers the reload's `auth/refresh` with
// `restoreAs`, so the shell renders without the login form.

/** The signed-in admin of the boards (A0: «محمد علي»). */
export const ADMIN = { id: 1, email: 'admin@example.com', name: 'محمد علي' } as const;

export type Role = 'admin' | 'editor';

/** A success envelope, as every admin route answers. */
export function envelope(data: unknown, meta: Record<string, unknown> = {}): Record<string, unknown> {
  return { success: true, data, error: null, meta };
}

/** A refusal envelope carrying only a code: `error.message` never reaches the screen. */
export function refusal(code: string, meta: Record<string, unknown> = {}): Record<string, unknown> {
  return { success: false, data: null, error: { code, message: 'x' }, meta };
}

/**
 * Restores the session from the refresh cookie as `role`. Extra admin fields such as
 * `must_change_password` go in `extra` (contract admin-api: `AdminUser` gains the flag).
 */
export function restoreAs(role: Role = 'admin', extra: Record<string, unknown> = {}): void {
  server.use(
    http.post('*/admin/api/auth/refresh', () =>
      HttpResponse.json(
        envelope({
          access_token: 'header.payload.signature',
          token_type: 'Bearer',
          expires_in: 900,
          admin: { ...ADMIN, role, ...extra },
        }),
      ),
    ),
  );
}

/** The providers a screen mounted on its own needs: the session and the toasts. */
export function Providers({ children }: { children: ReactNode }): ReactElement {
  return (
    <SessionProvider>
      <ToastProvider>{children}</ToastProvider>
    </SessionProvider>
  );
}
