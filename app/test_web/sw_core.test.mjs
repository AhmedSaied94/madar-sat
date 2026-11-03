// The service worker's decisions (research R12): cache → mirror (3 s) → own origin for a
// release file, network-first with a cached fallback for the shell and navigations.
//
// Node's built-in runner, no dependency: `node --test app/test_web/` (B2's app.yml step).
import assert from 'node:assert/strict';
import { test } from 'node:test';

import {
  MIRROR_TIMEOUT_MS,
  SHELL_CACHE,
  cacheNameFor,
  cachesToDelete,
  parseRelease,
  planFor,
  releaseHashOf,
  serve,
} from '../web/sw_core.mjs';

const HASH = '0123456789abcdef';
const OTHER = 'fedcba9876543210';
const ORIGIN = 'https://madar-sat.web.app';
const MIRROR = 'https://app.198.51.100.7.sslip.io';

/** A Cache implementation good enough for the worker: a map of URL → Response. */
function fakeCache(store = new Map()) {
  return {
    store,
    async match(key) {
      const response = store.get(String(key));
      return response ? response.clone() : undefined;
    },
    async put(key, response) {
      store.set(String(key), response);
    },
  };
}

/** A CacheStorage over a name → fakeCache map, recording what was opened. */
function fakeCaches(caches = new Map()) {
  return {
    caches,
    opened: [],
    async open(name) {
      this.opened.push(name);
      if (!caches.has(name)) caches.set(name, fakeCache());
      return caches.get(name);
    },
    async keys() {
      return [...caches.keys()];
    },
  };
}

/** A Response with a body, so clone() is meaningful. */
function response(body = 'ok', { status = 200 } = {}) {
  return new Response(body, { status });
}

/** A fetch that answers [from] a url → Response map and records every URL it was asked for. */
function fakeFetch(from = new Map()) {
  const calls = [];
  const fetchImpl = async (url) => {
    calls.push(url);
    if (from.has(url)) return from.get(url).clone();
    throw new TypeError(`failed to fetch ${url}`);
  };
  fetchImpl.calls = calls;
  return fetchImpl;
}

test('the mirror is the second source and the own origin the third', () => {
  const plan = planFor({ pathname: `/r/${HASH}/main.dart.js`, mode: 'cors' });
  assert.deepEqual(plan, { kind: 'release', hash: HASH });
  assert.equal(releaseHashOf(`/r/${HASH}/canvaskit/canvaskit.wasm`), HASH);
  assert.equal(releaseHashOf('/main.dart.js'), null, 'an unhashed file is not a release path');
});

test('a request the worker must not intercept has no plan', () => {
  assert.equal(planFor({ pathname: '/v1/matches', mode: 'cors' }), null);
  assert.equal(planFor({ pathname: '/api', mode: 'cors' }), null);
  assert.equal(planFor({ pathname: '/firebase-messaging-sw.js', mode: 'cors' }), null);
});

test('a cached release file is answered without a fetch', async () => {
  const caches = fakeCaches();
  const cache = await caches.open(cacheNameFor(HASH));
  await cache.put(`${ORIGIN}/r/${HASH}/main.dart.js`, response('cached'));
  const fetchImpl = fakeFetch();

  const answer = await serve({
    pathname: `/r/${HASH}/main.dart.js`,
    mode: 'cors',
    ownOrigin: ORIGIN,
    release: { hash: HASH, mirror: MIRROR },
    cachesImpl: caches,
    fetchImpl,
  });

  assert.equal(await answer.text(), 'cached');
  assert.deepEqual(fetchImpl.calls, [], 'the network was never used');
});

test('a cache miss asks the mirror first, and caches its answer under the hash', async () => {
  const caches = fakeCaches();
  const fetchImpl = fakeFetch(
    new Map([
      [`${MIRROR}/r/${HASH}/main.dart.js`, response('mirror')],
      [`${ORIGIN}/r/${HASH}/main.dart.js`, response('origin')],
    ]),
  );

  const answer = await serve({
    pathname: `/r/${HASH}/main.dart.js`,
    mode: 'cors',
    ownOrigin: ORIGIN,
    release: { hash: HASH, mirror: MIRROR },
    cachesImpl: caches,
    fetchImpl,
  });

  assert.equal(await answer.text(), 'mirror');
  assert.deepEqual(fetchImpl.calls, [`${MIRROR}/r/${HASH}/main.dart.js`]);
  const cache = await caches.open(cacheNameFor(HASH));
  const stored = await cache.match(`${ORIGIN}/r/${HASH}/main.dart.js`);
  assert.ok(stored, `cached under ${cacheNameFor(HASH)}`);
  assert.equal(await stored.text(), 'mirror');
});

test('a failing mirror falls back to the same path on the own origin', async () => {
  // The map has the own origin's copy only, so the mirror throws.
  const fetchImpl = fakeFetch(
    new Map([[`${ORIGIN}/r/${HASH}/main.dart.js`, response('origin')]]),
  );

  const answer = await serve({
    pathname: `/r/${HASH}/main.dart.js`,
    mode: 'cors',
    ownOrigin: ORIGIN,
    release: { hash: HASH, mirror: MIRROR },
    cachesImpl: fakeCaches(),
    fetchImpl,
  });

  assert.equal(await answer.text(), 'origin');
  assert.deepEqual(fetchImpl.calls, [
    `${MIRROR}/r/${HASH}/main.dart.js`,
    `${ORIGIN}/r/${HASH}/main.dart.js`,
  ]);
});

test('a mirror slower than the timeout is abandoned for the own origin', async () => {
  const slow = async (url) => {
    if (url.startsWith(MIRROR)) {
      await new Promise((resolve) => setTimeout(resolve, 200));
      return response('mirror');
    }
    return response('origin');
  };

  const answer = await serve({
    pathname: `/r/${HASH}/main.dart.js`,
    mode: 'cors',
    ownOrigin: ORIGIN,
    release: { hash: HASH, mirror: MIRROR },
    cachesImpl: fakeCaches(),
    fetchImpl: slow,
    timeoutMs: 5,
  });

  assert.equal(await answer.text(), 'origin');
  assert.ok(MIRROR_TIMEOUT_MS >= 1000, 'the shipped budget is the 3 s of research R12');
});

test('a preview build has no mirror, so the release comes from the own origin', async () => {
  const caches = fakeCaches();
  const fetchImpl = fakeFetch(
    new Map([[`${ORIGIN}/r/${HASH}/main.dart.js`, response('origin')]]),
  );

  const answer = await serve({
    pathname: `/r/${HASH}/main.dart.js`,
    mode: 'cors',
    ownOrigin: ORIGIN,
    release: { hash: HASH, mirror: '' },
    cachesImpl: caches,
    fetchImpl,
  });

  assert.equal(await answer.text(), 'origin');
  assert.deepEqual(fetchImpl.calls, [`${ORIGIN}/r/${HASH}/main.dart.js`]);
});

test('a navigation is network first', async () => {
  const caches = fakeCaches();
  await (await caches.open(SHELL_CACHE)).put(`${ORIGIN}/index.html`, response('cached shell'));
  const fetchImpl = fakeFetch(new Map([[`${ORIGIN}/match/12`, response('fresh')]]));

  const answer = await serve({
    pathname: '/match/12',
    mode: 'navigate',
    ownOrigin: ORIGIN,
    release: { hash: HASH, mirror: MIRROR },
    cachesImpl: caches,
    fetchImpl,
  });

  assert.equal(await answer.text(), 'fresh', 'the network answered first');
});

test('an offline navigation falls back to the cached index.html', async () => {
  const caches = fakeCaches();
  await (await caches.open(SHELL_CACHE)).put(`${ORIGIN}/index.html`, response('cached shell'));

  const answer = await serve({
    pathname: '/match/12',
    mode: 'navigate',
    ownOrigin: ORIGIN,
    release: { hash: HASH, mirror: MIRROR },
    cachesImpl: caches,
    fetchImpl: fakeFetch(),
  });

  assert.equal(await answer.text(), 'cached shell');
});

test('a shell file is cached, sw.js and release.json are not', async () => {
  const caches = fakeCaches();
  const fetchImpl = fakeFetch(
    new Map([
      [`${ORIGIN}/flutter_bootstrap.js`, response('bootstrap')],
      [`${ORIGIN}/sw.js`, response('worker')],
      [`${ORIGIN}/release.json`, response('{"hash":"0123456789abcdef"}')],
    ]),
  );
  const options = {
    mode: 'no-cors',
    ownOrigin: ORIGIN,
    release: { hash: HASH, mirror: MIRROR },
    cachesImpl: caches,
    fetchImpl,
  };

  await serve({ ...options, pathname: '/flutter_bootstrap.js' });
  await serve({ ...options, pathname: '/sw.js' });
  await serve({ ...options, pathname: '/release.json' });

  const cache = await caches.open(SHELL_CACHE);
  assert.ok(await cache.match(`${ORIGIN}/flutter_bootstrap.js`));
  assert.equal(await cache.match(`${ORIGIN}/sw.js`), undefined, 'a new release must be found');
  assert.equal(await cache.match(`${ORIGIN}/release.json`), undefined);
});

test('activation keeps the current and previous release caches only', () => {
  const names = [
    SHELL_CACHE,
    cacheNameFor(HASH),
    cacheNameFor(OTHER),
    `${cacheNameFor('aaaaaaaaaaaaaaaa')}`,
  ];

  assert.deepEqual(cachesToDelete(names, { current: HASH, previous: OTHER }), [
    cacheNameFor('aaaaaaaaaaaaaaaa'),
  ]);
  assert.deepEqual(cachesToDelete(names, { current: HASH, previous: null }), [
    cacheNameFor(OTHER),
    cacheNameFor('aaaaaaaaaaaaaaaa'),
  ]);
});

test('release.json is read only when it names a hash', () => {
  assert.deepEqual(parseRelease({ hash: HASH, mirror: MIRROR, built_at: 'ignored' }), {
    hash: HASH,
    mirror: MIRROR,
  });
  assert.deepEqual(parseRelease({ hash: HASH, mirror: '' }), { hash: HASH, mirror: '' });
  assert.equal(parseRelease({ hash: 'not-a-hash', mirror: MIRROR }), null);
  // A mirror that is not a bare https origin is ignored rather than trusted: the release
  // then comes from the app's own origin, which always works.
  assert.deepEqual(parseRelease({ hash: HASH, mirror: 'http://insecure.example' }), {
    hash: HASH,
    mirror: '',
  });
  assert.equal(parseRelease(null), null);
});
