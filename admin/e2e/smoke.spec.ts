import { expect, test, type APIRequestContext, type Page, type Request } from '@playwright/test';

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
// It never reads the E2E_* credentials: only the Prism fixture account signs in, so a mock run can't
// reach a real API with real credentials (A-R1-2). Live mode runs from a WireGuard peer only and
// touches nothing but the dedicated test match: the one match dated E2E_MATCH_DATE whose stadium
// starts with E2E_MATCH_MARKER. Credentials, host and marker come from the environment, and a missing
// one fails the run instead of skipping it; nothing here deletes or edits another match.
//
// The session lives in memory only (FR-034), so every move between screens goes through the router —
// a hard `page.goto` would reload the app and throw the editor back to /login.

const target = process.env.E2E_TARGET ?? 'mock';
if (target !== 'mock' && target !== 'live') {
  throw new Error(`E2E_TARGET must be "mock" or "live", got "${target}"`);
}
const live = target === 'live';

/** A live-mode variable: required and non-blank, so a missing one fails instead of skipping. */
function required(name: string): string {
  const value = (process.env[name] ?? '').trim();
  if (value === '') throw new Error(`E2E_TARGET=live needs ${name}`);
  return value;
}

// Prism accepts any credentials; these are the fixture account the mock run signs in with.
const MOCK_EMAIL = 'e2e@madar.test';
const MOCK_PASSWORD = 'e2e-password';
const MOCK_MARKER = 'MADAR-E2E';

const email = live ? required('E2E_EMAIL') : MOCK_EMAIL;
const password = live ? required('E2E_PASSWORD') : MOCK_PASSWORD;
const marker = live ? required('E2E_MATCH_MARKER') : MOCK_MARKER;
const publicApi = live ? required('E2E_PUBLIC_API') : '';
const matchDate = process.env.E2E_MATCH_DATE ?? '2000-01-01';

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
 * The editor shows a skeleton until the match loads, so the field is awaited, and a row whose editor
 * fails to load fails the run rather than counting as unmarked (A-R1-1).
 */
async function findMarkedMatch(page: Page, ids: readonly number[]): Promise<number> {
  const matches: { id: number; stadium: string }[] = [];
  for (const id of ids) {
    await openEditor(page, id);
    const stadium = page.getByTestId('match-stadium');
    await expect(stadium).toBeVisible();
    const value = await stadium.inputValue();
    if (value.startsWith(marker)) matches.push({ id, stadium: value });
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

/** Every PATCH to a match from here on, so a test can prove which match was written, or none. */
function recordPatches(page: Page): Request[] {
  const patches: Request[] = [];
  page.on('request', (intercepted) => {
    if (intercepted.method() === 'PATCH' && intercepted.url().includes('/admin/api/matches/')) {
      patches.push(intercepted);
    }
  });
  return patches;
}

/** Sets the open match's stadium and saves it; the toast confirms and no conflict dialog opens. */
async function saveStadium(page: Page, id: number, stadium: string): Promise<void> {
  await openEditor(page, id);
  await page.getByTestId('match-stadium').fill(stadium);
  await page.getByRole('button', { name: copy.save, exact: true }).click();
  await expect(page.getByRole('status')).toContainText(toastCopy.saved);
  await expect(page.getByRole('dialog')).toHaveCount(0);
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

  const patches = recordPatches(page);
  await saveStadium(page, matchId, nextStadium);
  expect(patches).toHaveLength(1);
  expect(patches[0]?.headers()['if-match']).toBeTruthy();

  if (live) {
    const elapsed = await waitForPublic(request, matchId, nextStadium);
    console.log(`edit-to-/v1: ${elapsed.toFixed(1)} s`);
  }
});

// The live guard, proven on the mock (A-R1-1, contracts/e2e-smoke.md step 3). Prism lists one match
// and answers every detail with the same one, so the list is widened to three ids and each detail
// gets its own id and stadium. Zero or two marked rows must abort before any PATCH; one marked row
// must be the only match written.
test.describe('the live run edits only the one marked match', () => {
  test.skip(live, 'stubs Prism; the live run is the test above');
  // The last pickDay leaves a list refetch in its route handler; let it end with the page.
  test.afterEach(async ({ page }) => {
    await page.unrouteAll({ behavior: 'ignoreErrors' });
  });

  const IDS = [48213, 48214, 48215] as const;

  async function stubMatches(page: Page, stadiums: Readonly<Record<number, string>>): Promise<void> {
    await page.route(/\/admin\/api\/matches\?/, async (route) => {
      const response = await route.fetch();
      const body = (await response.json()) as { data: Record<string, unknown>[] };
      const first = body.data[0];
      if (first === undefined) throw new Error('Prism listed no match to copy');
      await route.fulfill({ response, json: { ...body, data: IDS.map((id) => ({ ...first, id })) } });
    });
    await page.route(/\/admin\/api\/matches\/(\d+)$/, async (route) => {
      if (route.request().method() !== 'GET') return route.fallback();
      const id = Number(/\/matches\/(\d+)$/.exec(route.request().url())?.[1]);
      const response = await route.fetch();
      const body = (await response.json()) as { data: Record<string, unknown> };
      await route.fulfill({ response, json: { ...body, data: { ...body.data, id, stadium: stadiums[id] ?? 'استاد القاهرة' } } });
    });
  }

  async function listStubbed(page: Page): Promise<number[]> {
    await signIn(page);
    await openMatches(page);
    await pickDay(page);
    const ids = await listedIds(page);
    expect(ids).toEqual([...IDS]);
    return ids;
  }

  for (const [label, stadiums] of [
    ['no marked match', {}],
    ['two marked matches', { 48213: `${marker} a`, 48215: `${marker} b` }],
  ] as const) {
    test(`${label}: the run aborts and writes nothing`, async ({ page }) => {
      await stubMatches(page, stadiums);
      const patches = recordPatches(page);
      const ids = await listStubbed(page);
      await expect(findMarkedMatch(page, ids)).rejects.toThrow(/needs exactly one match/);
      expect(patches).toHaveLength(0);
    });
  }

  test('one marked match: it is the one edited', async ({ page }) => {
    await stubMatches(page, { 48214: `${marker} old` });
    const patches = recordPatches(page);
    const ids = await listStubbed(page);
    const matchId = await findMarkedMatch(page, ids);
    expect(matchId).toBe(48214);
    expect(patches).toHaveLength(0);
    await saveStadium(page, matchId, `${marker} new`);
    expect(patches.map((patch) => new URL(patch.url()).pathname)).toEqual(['/admin/api/matches/48214']);
  });
});
