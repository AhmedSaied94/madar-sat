/**
 * The PWA's service-worker decisions, with no browser globals (research R12).
 *
 * `sw.js` wires the events (install, fetch, activate) to these functions; keeping the
 * choices here means the whole failover order is tested with `node --test app/test_web/`,
 * without a browser and without a dependency.
 *
 * The order is SD §5.2's: a release file comes from the cache, then the mirror (3 s), then
 * the app's own origin (Firebase); the shell and navigations are network-first with the
 * cached copy as the fallback, so an installed app opens offline.
 */

/** How long the mirror has to answer a release file before the own origin is tried. */
export const MIRROR_TIMEOUT_MS = 3000;

/** One cache per release hash: `madar-r-<hash>` (data-model "Release layout"). */
export const RELEASE_CACHE_PREFIX = 'madar-r-';

/** The shell's cache (index.html and the files the bootstrap needs). */
export const SHELL_CACHE = 'madar-shell-v1';

/** A hashed release folder: 16 lowercase hex characters (stage_web_release.sh). */
const RELEASE_PATH = /^\/r\/([0-9a-f]{16})\//;

/**
 * The files that stay at the site's root (data-model "Release layout"). Everything else
 * lives under `r/<hash>/` and is cache-first.
 */
const SHELL_FILES = new Set([
  '/',
  '/index.html',
  '/flutter_bootstrap.js',
  '/manifest.json',
  '/favicon.png',
  '/sw.js',
  '/release.json',
  '/firebase-config.js',
  '/drift_worker.js',
]);

/** The shell files that may sit in the cache: `sw.js` and `release.json` never do, because
 * a new release is discovered through them. */
const UNCACHED_SHELL = new Set(['/sw.js', '/release.json']);

/** The cache name for a release hash. */
export function cacheNameFor(hash) {
  return `${RELEASE_CACHE_PREFIX}${hash}`;
}

/** The release hash a request path belongs to, or null. */
export function releaseHashOf(pathname) {
  const match = RELEASE_PATH.exec(pathname);
  return match ? match[1] : null;
}

/** Whether a path is one of the shell files at the root. */
export function isShell(pathname) {
  return SHELL_FILES.has(pathname) || pathname.startsWith('/icons/');
}

/**
 * `release.json` as `{hash, mirror}`, or null when the file is missing or malformed. The
 * mirror is empty on a preview build, where the release is served from the app's origin.
 */
export function parseRelease(value) {
  if (!value || typeof value !== 'object') return null;
  const hash = typeof value.hash === 'string' && /^[0-9a-f]{16}$/.test(value.hash) ? value.hash : null;
  if (!hash) return null;
  const mirror = typeof value.mirror === 'string' && /^https:\/\/[^/]+$/.test(value.mirror)
    ? value.mirror
    : '';
  return { hash, mirror };
}

/**
 * What the worker does with a request: `{kind: 'release', hash}`, `{kind: 'shell'}` for a
 * navigation or a shell file, or null when it must keep out of the way (the API, media,
 * Firebase's messaging worker).
 */
export function planFor({ pathname, mode }) {
  const hash = releaseHashOf(pathname);
  if (hash) return { kind: 'release', hash };
  if (mode === 'navigate' || isShell(pathname)) return { kind: 'shell' };
  return null;
}

/**
 * Answers one request, or returns null when the worker must not intercept it.
 *
 * [cachesImpl], [fetchImpl] and [timeoutMs] are injected so the tests drive every branch:
 * a cache hit, a mirror that answers, a mirror that fails, a mirror that is too slow.
 */
export async function serve({
  pathname,
  mode,
  ownOrigin,
  release,
  cachesImpl,
  fetchImpl,
  timeoutMs = MIRROR_TIMEOUT_MS,
}) {
  const plan = planFor({ pathname, mode });
  if (!plan) return null;
  const origin = ownOrigin.replace(/\/$/, '');

  if (plan.kind === 'release') {
    const cacheName = cacheNameFor(plan.hash);
    const cache = await cachesImpl.open(cacheName);
    const key = `${origin}${pathname}`;
    const cached = await cache.match(key);
    if (cached) return cached;

    const attempts = [];
    if (release && release.mirror) {
      attempts.push({ url: `${release.mirror}${pathname}`, limit: timeoutMs });
    }
    // The app's own origin is the last resort and is never abandoned on a timer: if the
    // mirror is down, this is the answer the first load still needs.
    attempts.push({ url: key, limit: null });

    let lastError = null;
    for (const attempt of attempts) {
      try {
        const response = await withTimeout(() => fetchImpl(attempt.url), attempt.limit);
        if (response && response.ok) {
          // Both the mirror's answer and the own origin's land under one key, so the next
          // open reads the same entry whichever served it.
          await cache.put(key, response.clone());
          return response;
        }
        lastError = null;
      } catch (error) {
        lastError = error;
      }
    }
    if (lastError) throw lastError;
    return null;
  }

  // The shell, and every navigation: network first, so a new release reaches the app, with
  // the cached copy as the offline fallback. A route that was never cached opens the cached
  // index.html, which is the app itself.
  const cache = await cachesImpl.open(SHELL_CACHE);
  const key = `${origin}${pathname}`;
  try {
    const response = await fetchImpl(key);
    if (response && response.ok && !UNCACHED_SHELL.has(pathname)) {
      await cache.put(key, response.clone());
    }
    return response;
  } catch (error) {
    const cached =
      (await cache.match(key)) ??
      (mode === 'navigate' ? await cache.match(`${origin}/index.html`) : null);
    if (cached) return cached;
    throw error;
  }
}

/**
 * The release caches to drop on activation: every `madar-r-*` other than [current] and
 * [previous] (the previous one is what an offline open of the old shell needs).
 */
export function cachesToDelete(names, { current, previous }) {
  const keep = new Set([SHELL_CACHE]);
  if (current) keep.add(cacheNameFor(current));
  if (previous) keep.add(cacheNameFor(previous));
  return names.filter((name) => name.startsWith(RELEASE_CACHE_PREFIX) && !keep.has(name));
}

/**
 * [work] raced against [limit]; a mirror that has not answered by then is abandoned so the
 * own origin gets its turn within the first load's budget (research R11). A null limit
 * waits for the answer however long it takes.
 */
async function withTimeout(work, limit) {
  if (limit === null || limit === undefined) return work();
  let timer;
  try {
    return await Promise.race([
      work(),
      new Promise((_, reject) => {
        timer = setTimeout(() => reject(new Error(`timed out after ${limit} ms`)), limit);
      }),
    ]);
  } finally {
    if (timer !== undefined) clearTimeout(timer);
  }
}
