// `sw.js` as the browser registers it (M-R1-1): `flutter_bootstrap.js` calls
// `navigator.serviceWorker.register('/sw.js')`, a classic worker, so the staged file must
// parse as a classic script. `tool/classic_sw.py` (run by the stage script) inlines the core.
//
// `node --test app/test_web/`; needs `python3`, as the stage script does.
import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { readFileSync } from 'node:fs';
import { test } from 'node:test';
import { fileURLToPath } from 'node:url';
import vm from 'node:vm';

const app = fileURLToPath(new URL('..', import.meta.url));
const HASH = '0123456789abcdef';
const ORIGIN = 'https://madar-sat.web.app';
const MIRROR = 'https://app.198.51.100.7.sslip.io';

function classicWorker() {
  const result = spawnSync('python3', ['tool/classic_sw.py', 'web/sw.js', 'web/sw_core.mjs'], {
    cwd: app,
    encoding: 'utf8',
  });
  assert.equal(result.status, 0, result.stderr);
  // What step 6 of the stage script does to it.
  return result.stdout.replaceAll('__RELEASE_HASH__', HASH).replaceAll('__MIRROR_BASE__', MIRROR);
}

/** A worker global scope with fake caches and fetch, recording the listeners. */
function workerScope(fetchImpl) {
  const listeners = new Map();
  const stores = new Map();
  const caches = {
    async open(name) {
      if (!stores.has(name)) stores.set(name, new Map());
      const store = stores.get(name);
      return {
        async match(key) {
          return store.get(String(key))?.clone();
        },
        async put(key, value) {
          store.set(String(key), value);
        },
      };
    },
    async keys() {
      return [...stores.keys()];
    },
    async delete(name) {
      return stores.delete(name);
    },
  };
  const self = {
    location: { origin: ORIGIN },
    clients: { claim: async () => {} },
    addEventListener(type, listener) {
      listeners.set(type, listener);
    },
  };
  const context = vm.createContext({
    self,
    caches,
    fetch: fetchImpl,
    URL,
    Response,
    Request,
    Headers,
    AbortController,
    setTimeout,
    clearTimeout,
    console,
  });
  return { context, listeners, stores };
}

test('the source sw.js is a module, which a classic registration cannot parse', () => {
  const source = readFileSync(new URL('../web/sw.js', import.meta.url), 'utf8');
  assert.throws(() => new vm.Script(source), SyntaxError);
});

test('the staged sw.js parses as a classic script and registers its three listeners', () => {
  const { context, listeners } = workerScope(async () => new Response('ok'));
  new vm.Script(classicWorker(), { filename: 'sw.js' }).runInContext(context);
  assert.deepEqual([...listeners.keys()].sort(), ['activate', 'fetch', 'install']);
});

test('the classic worker installs, activates and serves a release file through the core', async () => {
  const fetched = [];
  const fetchImpl = async (target) => {
    const url = String(target);
    fetched.push(url);
    if (url === '/release.json') {
      return new Response(JSON.stringify({ hash: HASH, mirror: MIRROR }), { status: 200 });
    }
    return new Response(`body of ${url}`, { status: 200 });
  };
  const { context, listeners, stores } = workerScope(fetchImpl);
  new vm.Script(classicWorker(), { filename: 'sw.js' }).runInContext(context);

  const lifecycle = async (type) => {
    const pending = [];
    listeners.get(type)({ waitUntil: (promise) => pending.push(promise) });
    await Promise.all(pending);
  };
  await lifecycle('install');
  await lifecycle('activate');
  assert.ok(stores.has(`madar-r-${HASH}`), 'install opens the release cache');

  let answer = null;
  listeners.get('fetch')({
    request: { method: 'GET', url: `${ORIGIN}/r/${HASH}/main.dart.js`, mode: 'cors' },
    respondWith: (promise) => {
      answer = promise;
    },
  });
  assert.ok(answer, 'the worker answers a release file');
  const response = await answer;
  assert.equal(await response.text(), `body of ${MIRROR}/r/${HASH}/main.dart.js`, 'the mirror first');
});

test('the inliner refuses module syntax it cannot inline', () => {
  const result = spawnSync(
    'python3',
    ['-c', 'import sys; sys.path.insert(0, "tool"); import classic_sw as c; c.classic("export const x = 1;\\n", "")'],
    { cwd: app, encoding: 'utf8' },
  );
  assert.notEqual(result.status, 0);
  assert.match(result.stderr, /import or export/);
});
