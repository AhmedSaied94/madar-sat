import { defineConfig, devices, type PlaywrightTestConfig } from '@playwright/test';

// The D4 admin smoke test (spec 004, contracts/e2e-smoke.md).
//
// E2E_TARGET=mock (default) runs the UI against Prism and the Vite dev server, both started here, so
// CI needs nothing else. E2E_TARGET=live talks to the deployed admin over WireGuard: no servers are
// started, the base URL is E2E_BASE_URL and Caddy's internal root arrives through NODE_EXTRA_CA_CERTS,
// never `ignoreHTTPSErrors`.
const live = process.env.E2E_TARGET === 'live';
const liveBaseUrl = process.env.E2E_BASE_URL ?? '';

if (live && liveBaseUrl === '') {
  throw new Error('E2E_TARGET=live needs E2E_BASE_URL, e.g. https://10.8.0.1');
}

const mockServer: PlaywrightTestConfig['webServer'] = [
  {
    command: 'pnpm prism',
    // A path that answers 200 with no parameters: Playwright treats 4xx as "not up yet", and the
    // matches list needs a date range. 127.0.0.1, not localhost: Prism binds IPv4 only.
    url: 'http://127.0.0.1:4010/admin/api/competitions',
    reuseExistingServer: process.env.CI === undefined,
    timeout: 120_000,
  },
  {
    command: 'pnpm dev',
    url: 'http://localhost:5173',
    reuseExistingServer: process.env.CI === undefined,
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
    baseURL: live ? liveBaseUrl : 'http://localhost:5173',
    trace: 'retain-on-failure',
  },
  projects: [{ name: 'chromium', use: { ...devices['Desktop Chrome'] } }],
  ...(live ? {} : { webServer: mockServer }),
};

export default defineConfig(config);
