import { defineConfig, devices, type PlaywrightTestConfig } from '@playwright/test';

// The D4 admin smoke test (spec 004, contracts/e2e-smoke.md).
//
// E2E_TARGET=mock (default) runs the UI against Prism and the Vite dev server, both started here, so
// CI needs nothing else. E2E_TARGET=live talks to the deployed admin over WireGuard: no servers are
// started, the base URL is E2E_BASE_URL and Caddy's internal root arrives through NODE_EXTRA_CA_CERTS,
// never `ignoreHTTPSErrors`.
const target = process.env.E2E_TARGET ?? 'mock';
if (target !== 'mock' && target !== 'live') {
  throw new Error(`E2E_TARGET must be "mock" or "live", got "${target}"`);
}
const live = target === 'live';
const liveBaseUrl = process.env.E2E_BASE_URL ?? '';

if (live && liveBaseUrl === '') {
  throw new Error('E2E_TARGET=live needs E2E_BASE_URL, e.g. https://10.8.0.1');
}

// Mock mode never reuses a running server (A-R1-2): a `pnpm dev:wg` on :5173 proxies to the deployed
// API, so the mock run starts its own Vite in the default (Prism) mode on a port of its own, and
// fails if Prism's port is taken instead of talking to whatever holds it.
const MOCK_PORT = 5179;
const mockServer: PlaywrightTestConfig['webServer'] = [
  {
    command: 'pnpm prism',
    // A path that answers 200 with no parameters: Playwright treats 4xx as "not up yet", and the
    // matches list needs a date range. 127.0.0.1, not localhost: Prism binds IPv4 only.
    url: 'http://127.0.0.1:4010/admin/api/competitions',
    reuseExistingServer: false,
    timeout: 120_000,
  },
  {
    command: `pnpm exec vite --mode development --port ${MOCK_PORT} --strictPort`,
    url: `http://localhost:${MOCK_PORT}`,
    reuseExistingServer: false,
    timeout: 120_000,
  },
];

const config: PlaywrightTestConfig = {
  testDir: './e2e',
  // One editor and one test match: the runs must not overlap.
  fullyParallel: false,
  workers: 1,
  retries: 0,
  timeout: 120_000,
  reporter: [['list'], ['html', { outputFolder: 'playwright-report', open: 'never' }]],
  use: {
    baseURL: live ? liveBaseUrl : `http://localhost:${MOCK_PORT}`,
    trace: 'retain-on-failure',
  },
  projects: [{ name: 'chromium', use: { ...devices['Desktop Chrome'] } }],
  ...(live ? {} : { webServer: mockServer }),
};

export default defineConfig(config);
