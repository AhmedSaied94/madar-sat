// The PWA's service worker (research R12, contracts/web-release.md).
//
// It routes files only: the API and the media host are never cached here, because cached
// match data is drift's job (constitution II). The decisions live in `sw_core.mjs`, which
// `node --test app/test_web/` covers; this file wires the browser's events to them.
//
// `tool/stage_web_release.sh` stamps the hash and the mirror below, so a new release ships
// a different `sw.js` and the browser installs the new worker on the next open. The core is
// imported under the same hash, so a release never mixes a new worker with an old core,
// whatever the host's cache headers say.
import {
  cacheNameFor,
  cachesToDelete,
  parseRelease,
  serve,
} from './sw_core.mjs?h=__RELEASE_HASH__';

/** This release, stamped at staging; the placeholders mean the file was never staged. */
const RELEASE = {
  hash: '__RELEASE_HASH__',
  mirror: '__MIRROR_BASE__',
};

const stamped = RELEASE.hash !== '' && !RELEASE.hash.startsWith('__');
const OWN_ORIGIN = self.location.origin;

/** The previous hash, so an offline open of the old shell still finds its files. */
let previousHash = null;

/** `release.json` read once per worker: a new release ships a new `sw.js`. */
let releasePromise = null;
function release() {
  releasePromise ??= (async () => {
    try {
      const response = await fetch('/release.json', { cache: 'no-store' });
      return response.ok ? parseRelease(await response.json()) : null;
    } catch (error) {
      return null;
    }
  })();
  return releasePromise;
}

self.addEventListener('install', (event) => {
  event.waitUntil(
    (async () => {
      const discovered = await release();
      previousHash = discovered && discovered.hash !== RELEASE.hash ? RELEASE.hash : null;
      if (stamped) await caches.open(cacheNameFor(RELEASE.hash));
    })(),
  );
});

self.addEventListener('activate', (event) => {
  event.waitUntil(
    (async () => {
      const names = await caches.keys();
      await Promise.all(
        cachesToDelete(names, {
          current: stamped ? RELEASE.hash : null,
          previous: previousHash,
        }).map((name) => caches.delete(name)),
      );
      await self.clients.claim();
    })(),
  );
});

self.addEventListener('fetch', (event) => {
  const request = event.request;
  if (request.method !== 'GET') return;
  const url = new URL(request.url);
  // A release file may be asked for on the mirror by the bootstrap, before this worker
  // controls the page; both origins are ours to route.
  if (url.origin !== OWN_ORIGIN && !url.pathname.startsWith('/r/')) return;

  event.respondWith(
    (async () => {
      const known = (await release()) ?? (stamped ? RELEASE : null);
      const answer = await serve({
        pathname: url.pathname,
        mode: request.mode,
        ownOrigin: OWN_ORIGIN,
        release: known,
        cachesImpl: caches,
        fetchImpl: (target) => fetch(target),
      });
      // Not a file this worker owns: the browser's own fetch, untouched.
      return answer ?? fetch(request);
    })(),
  );
});
