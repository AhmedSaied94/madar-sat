import { readFileSync } from 'node:fs';

import react from '@vitejs/plugin-react';
import type { Plugin } from 'vite';
import { configDefaults, defineConfig } from 'vitest/config';

// index.html carries the production CSP. React Fast Refresh needs an inline preamble,
// so the dev server drops the CSP meta; `vite build` keeps it.
const devWithoutCsp = (): Plugin => ({
  name: 'madar-dev-without-csp',
  apply: 'serve',
  transformIndexHtml: (html) => html.replace(/\s*<meta http-equiv="Content-Security-Policy"[^>]*>/, ''),
});

interface OpenApiSpec {
  paths?: Record<string, Record<string, { responses?: Record<string, { content?: Record<string, { examples?: Record<string, unknown> }> }> }>>;
}

// Prism looks for a named example only in the response it was asked for, so `?mock=<example>` must also
// send that example's status (`Prefer: code=429, example=account_locked`). The statuses come from the spec:
// { "POST /admin/api/auth/login": { "account_locked": 429, ... } }.
function mockExampleStatuses(): Record<string, Record<string, number>> {
  const spec = JSON.parse(readFileSync(new URL('../backend/openapi/admin.json', import.meta.url), 'utf8')) as OpenApiSpec;
  const statuses: Record<string, Record<string, number>> = {};
  for (const [path, operations] of Object.entries(spec.paths ?? {})) {
    // `adminHttp` keys an operation by its template, `PATCH /admin/api/matches/{}`, so a literal
    // `{match_id}` from the spec is normalised to it here (A-R2-4).
    const template = path.replace(/\{[^}]+\}/g, '{}');
    for (const [method, operation] of Object.entries(operations)) {
      for (const [status, response] of Object.entries(operation.responses ?? {})) {
        for (const example of Object.keys(response.content?.['application/json']?.examples ?? {})) {
          (statuses[`${method.toUpperCase()} ${template}`] ??= {})[example] = Number(status);
        }
      }
    }
  }
  return statuses;
}

export default defineConfig(({ command, mode }) => ({
  plugins: [react(), devWithoutCsp()],
  define: {
    __MOCK_EXAMPLE_STATUSES__: JSON.stringify(command === 'serve' ? mockExampleStatuses() : {}),
  },
  server: {
    // The proxy keeps the browser on localhost, so the cookies stay host-only and the admin API needs
    // no CORS (research R23). `changeOrigin` rewrites `Host` to 10.8.0.1, Caddy's only site address: with
    // `Host: localhost:5173` the request matches no site and Caddy answers nothing (A-R2-13).
    proxy:
      mode === 'wg'
        ? { '/admin/api': { target: 'https://10.8.0.1', secure: true, changeOrigin: true } }
        : { '/admin/api': 'http://localhost:4010' },
  },
  test: {
    environment: 'jsdom',
    setupFiles: ['./src/test/setup.ts'],
    css: false,
    restoreMocks: true,
    // Playwright owns e2e/; Vitest must not collect its specs.
    exclude: [...configDefaults.exclude, 'e2e/**', 'playwright-report/**', 'test-results/**'],
    // Node ≥ 25 ships its own Web Storage global, which hides jsdom's localStorage/sessionStorage.
    execArgv: ['--no-experimental-webstorage'],
  },
}));
