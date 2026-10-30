import '@testing-library/jest-dom/vitest';

import { cleanup } from '@testing-library/react';
import { HttpResponse, http } from 'msw';
import { afterAll, afterEach, beforeAll, beforeEach, vi } from 'vitest';

import { server } from './server';

beforeAll(() => {
  server.listen({ onUnhandledRequest: 'error' });
});

// jsdom starts with no `madar_refresh` cookie, so restoring the session on load fails the way a
// signed-out browser does. A test that starts signed in overrides this with `server.use(...)`.
beforeEach(() => {
  server.use(
    http.post('*/admin/api/auth/refresh', () =>
      HttpResponse.json(
        { success: false, data: null, error: { code: 'refresh_invalid', message: 'no refresh cookie' }, meta: {} },
        { status: 401 },
      ),
    ),
  );
});

afterEach(() => {
  cleanup();
  server.resetHandlers();
  window.localStorage.clear();
  window.sessionStorage.clear();
  vi.useRealTimers();
});

afterAll(() => {
  server.close();
});

// jsdom has no matchMedia; components read prefers-reduced-motion through it.
if (!window.matchMedia) {
  Object.defineProperty(window, 'matchMedia', {
    writable: true,
    value: (query: string): MediaQueryList => ({
      matches: false,
      media: query,
      onchange: null,
      addListener: () => undefined,
      removeListener: () => undefined,
      addEventListener: () => undefined,
      removeEventListener: () => undefined,
      dispatchEvent: () => false,
    }),
  });
}
