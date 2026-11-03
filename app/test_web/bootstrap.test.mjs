// `web/flutter_bootstrap.js`'s mirror fallback (M-R1-2). Flutter 3.47.7's loader resolves
// `load()` as soon as it appends the entrypoint `<script>`, so the bootstrap has to notice a
// failed mirror itself and load once from the own origin, starting one app only.
//
// `node --test app/test_web/`: the bootstrap runs in a vm with `_flutter.loader` stubbed.
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { test } from 'node:test';
import vm from 'node:vm';

const HASH = '0123456789abcdef';
const ORIGIN = 'https://madar-sat.web.app';
const MIRROR = 'https://app.198.51.100.7.sslip.io';
const MIRROR_ENTRY = `${MIRROR}/r/${HASH}/main.dart.js`;
const OWN_BASE = `/r/${HASH}/`;

const source = readFileSync(new URL('../web/flutter_bootstrap.js', import.meta.url), 'utf8')
  // Flutter's build fills these two in with its loader and build config.
  .replace('{{flutter_js}}', '')
  .replace('{{flutter_build_config}}', '');

const settle = async () => {
  for (let i = 0; i < 10; i += 1) await new Promise((resolve) => setImmediate(resolve));
};

/**
 * Runs the stamped bootstrap. [probe] answers the mirror HEAD; the loader stub records each
 * load's entrypoint base and keeps its `onEntrypointLoaded`, as Flutter's does.
 */
function boot({ probe, mirror = MIRROR }) {
  const loads = [];
  const engines = [];
  const warnings = [];
  const captured = [];
  const window = {
    location: { search: '', href: `${ORIGIN}/` },
    addEventListener(type, listener, capture) {
      if (type === 'error' && capture === true) captured.push(listener);
    },
  };
  const loader = {
    async load(options) {
      loads.push({ base: options?.config?.entrypointBaseUrl, onEntrypointLoaded: options?.onEntrypointLoaded });
    },
  };
  const context = vm.createContext({
    window,
    navigator: {},
    performance: { now: () => 0 },
    console: { log() {}, warn: (...args) => warnings.push(args.join(' ')) },
    URL,
    URLSearchParams,
    AbortController,
    // The 3 s probe limit, run at once.
    setTimeout: (fn) => setTimeout(fn, 0),
    clearTimeout,
    fetch: probe,
    _flutter: { loader },
  });
  const stamped = source.replaceAll('__RELEASE_HASH__', HASH).replaceAll('__MIRROR_BASE__', mirror);
  new vm.Script(stamped, { filename: 'flutter_bootstrap.js' }).runInContext(context);

  const entrypointLoaded = (index) =>
    loads[index].onEntrypointLoaded({
      initializeEngine: async () => {
        engines.push(loads[index].base);
        return { runApp() {} };
      },
    });
  const scriptError = (src) => {
    for (const listener of captured) listener({ target: { tagName: 'SCRIPT', src } });
  };
  return { loads, engines, warnings, window, entrypointLoaded, scriptError };
}

test('a mirror that answers loads from the mirror, once', async () => {
  const run = boot({ probe: async () => ({ ok: true }) });
  await settle();
  assert.deepEqual(run.loads.map((load) => load.base), [`${MIRROR}/r/${HASH}/`]);
  run.entrypointLoaded(0);
  await settle();
  assert.deepEqual(run.engines, [`${MIRROR}/r/${HASH}/`]);
  assert.equal(run.window.MADAR_RELEASE.base, MIRROR);
});

test('a blocked mirror (the probe fails) loads once from the own origin', async () => {
  const run = boot({
    probe: async () => {
      throw new TypeError('blocked');
    },
  });
  await settle();
  assert.deepEqual(run.loads.map((load) => load.base), [OWN_BASE]);
  assert.equal(run.window.MADAR_RELEASE.base, '', 'drift reads its wasm from the own origin too');
  assert.match(run.warnings.join('\n'), /mirror failed/);
});

test('a hung mirror is abandoned after the probe limit', async () => {
  const run = boot({
    probe: (url, { signal }) =>
      new Promise((resolve, reject) => {
        signal.addEventListener('abort', () => reject(new Error('aborted')));
      }),
  });
  await settle();
  assert.deepEqual(run.loads.map((load) => load.base), [OWN_BASE]);
});

test('a mirror that 404s the entrypoint loads from the own origin', async () => {
  const run = boot({ probe: async () => ({ ok: false }) });
  await settle();
  assert.deepEqual(run.loads.map((load) => load.base), [OWN_BASE]);
});

test('an entrypoint script that fails after the probe falls back once, and one app starts', async () => {
  const run = boot({ probe: async () => ({ ok: true }) });
  await settle();
  run.scriptError(MIRROR_ENTRY);
  run.scriptError(MIRROR_ENTRY);
  run.scriptError(`${ORIGIN}/somewhere-else.js`);
  await settle();
  assert.deepEqual(run.loads.map((load) => load.base), [`${MIRROR}/r/${HASH}/`, OWN_BASE]);

  // Should the mirror's copy still arrive late, only the first entrypoint starts an app.
  run.entrypointLoaded(1);
  run.entrypointLoaded(0);
  await settle();
  assert.deepEqual(run.engines, [OWN_BASE]);
});

test('without a mirror the release loads from the own origin with no probe', async () => {
  let probed = false;
  const run = boot({
    mirror: '',
    probe: async () => {
      probed = true;
      return { ok: true };
    },
  });
  await settle();
  assert.equal(probed, false);
  assert.deepEqual(run.loads.map((load) => load.base), [OWN_BASE]);
});
