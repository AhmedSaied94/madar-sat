import { expect, test, type APIRequestContext, type Page } from '@playwright/test';

import {
  editor as copy,
  login as loginCopy,
  matches as matchesCopy,
  navLabels,
  toast as toastCopy,
} from '../src/i18n/ar';

// The D4 admin smoke test (spec 004 T052, contracts/e2e-smoke.md): log in, edit one match's stadium
// under If-Match, and — against the deployed host — wait for the change on /v1.
//
// Mock mode (`E2E_TARGET=mock`, the default) proves the UI flow and the write contract against Prism.
// Live mode runs from a WireGuard peer only and touches nothing but the dedicated test match: the one
// match dated E2E_MATCH_DATE whose stadium starts with E2E_MATCH_MARKER. Credentials, host and marker
// come from the environment; nothing here deletes or edits another match.
//
// The session lives in memory only (FR-034), so every move between screens goes through the router —
// a hard `page.goto` would reload the app and throw the editor back to /login.

const live = process.env.E2E_TARGET === 'live';
const email = process.env.E2E_EMAIL ?? (live ? '' : 'e2e@madar.test');
const password = process.env.E2E_PASSWORD ?? (live ? '' : 'e2e-password');
const marker = process.env.E2E_MATCH_MARKER ?? 'MADAR-E2E';
const matchDate = process.env.E2E_MATCH_DATE ?? '2000-01-01';
const publicApi = process.env.E2E_PUBLIC_API ?? '';

const ROW_PREFIX = 'match-row-';

async function signIn(page: Page): Promise<void> {
  await page.goto('/login');
  await page.locator('input[autocomplete="username"]').fill(email);
  await page.locator('input[autocomplete="current-password"]').fill(password);
  await page.getByRole('button', { name: loginCopy.submit, exact: true }).click();
  // The guard sends a signed-in editor to the landing page; an error banner keeps the login.
  await page.waitForURL((url) => !url.pathname.startsWith('/login'));
}

async function openMatches(page: Page): Promise<void> {
  await page.getByRole('link', { name: navLabels.matches }).click();
  await page.waitForURL((url) => url.pathname === '/matches');
}

/** A3 for the test match's Cairo day (contract, step 2). */
async function pickDay(page: Page): Promise<void> {
  await page.getByLabel(matchesCopy.pickDate).fill(matchDate);
}

/** The ids A3 lists, in the table's own order. */
async function listedIds(page: Page): Promise<number[]> {
  const rows = page.locator(`[data-testid^="${ROW_PREFIX}"]`);
  await expect(rows.first()).toBeVisible();
  return rows.evaluateAll((elements, prefix) =>
    elements
      .map((element) => Number(element.getAttribute('data-testid')?.slice(prefix.length)))
      .filter((id) => Number.isInteger(id) && id > 0),
  ROW_PREFIX);
}

/** Opens a row's editor the way a keyboard editor does: focus the row, press Enter (A3's own key). */
async function openEditor(page: Page, id: number): Promise<void> {
  const row = page.getByTestId(`${ROW_PREFIX}${id}`);
  await row.focus();
  await row.press('Enter');
  await page.waitForURL((url) => url.pathname === `/matches/${id}`);
}

/**
 * The live test match: exactly one row on E2E_MATCH_DATE whose stadium starts with the marker. The
 * list row carries no stadium, so each row's editor is opened and read — none of that edits anything.
 */
async function findMarkedMatch(page: Page, ids: readonly number[]): Promise<number> {
  const matches: { id: number; stadium: string }[] = [];
  for (const id of ids) {
    await openEditor(page, id);
    const stadium = page.getByTestId('match-stadium');
    if (await stadium.isVisible().catch(() => false)) {
      const value = await stadium.inputValue();
      if (value.startsWith(marker)) matches.push({ id, stadium: value });
    }
    await openMatches(page);
    await pickDay(page);
  }
  if (matches.length !== 1) {
    const seen = matches.map((match) => `${match.id}: ${match.stadium}`).join('; ') || 'none';
    throw new Error(
      `the live run needs exactly one match whose stadium starts with "${marker}" on ${matchDate}, found ${matches.length} (${seen})`,
    );
  }
  const found = matches[0];
  if (found === undefined) throw new Error('unreachable: exactly one match was found above');
  return found.id;
}

/** Polls the public API until the stored stadium is the one saved; returns the elapsed seconds. */
async function waitForPublic(request: APIRequestContext, id: number, expected: string): Promise<number> {
  const started = Date.now();
  let last: string | null = null;
  while (Date.now() - started < 60_000) {
    const response = await request.get(`${publicApi}/v1/matches/${id}`);
    const body = (await response.json()) as { data?: { stadium?: string | null } };
    last = body.data?.stadium ?? null;
    if (last === expected) return (Date.now() - started) / 1000;
    await new Promise((resolve) => setTimeout(resolve, 5_000));
  }
  throw new Error(`the edit was not visible on /v1 within 60 s (last stadium: ${last ?? 'none'})`);
}

test('an editor saves a match stadium and the change reaches /v1', async ({ page, request }) => {
  test.skip(
    live && (email === '' || password === '' || publicApi === ''),
    'live mode needs E2E_EMAIL, E2E_PASSWORD and E2E_PUBLIC_API',
  );

  const runId = new Date().toISOString();
  const nextStadium = `${marker} ${runId}`;

  await signIn(page);
  await openMatches(page);
  // The test match is dated in the past, so it is not on today's tab (contract, step 2).
  if (live) await pickDay(page);

  const ids = await listedIds(page);
  if (ids.length === 0) throw new Error(`A3 listed no match to edit on ${matchDate}`);
  const matchId = live ? await findMarkedMatch(page, ids) : ids[0];
  if (matchId === undefined) throw new Error('A3 listed no match to edit');

  const patches: Record<string, string>[] = [];
  page.on('request', (intercepted) => {
    if (intercepted.method() === 'PATCH' && intercepted.url().includes('/admin/api/matches/')) {
      patches.push(intercepted.headers());
    }
  });

  await openEditor(page, matchId);
  await page.getByTestId('match-stadium').fill(nextStadium);
  await page.getByRole('button', { name: copy.save, exact: true }).click();

  await expect(page.getByRole('status')).toContainText(toastCopy.saved);
  await expect(page.getByRole('dialog')).toHaveCount(0);
  expect(patches).toHaveLength(1);
  expect(patches[0]?.['if-match']).toBeTruthy();

  if (live) {
    const elapsed = await waitForPublic(request, matchId, nextStadium);
    console.log(`edit-to-/v1: ${elapsed.toFixed(1)} s`);
  }
});
