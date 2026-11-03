// Flutter's web bootstrap, customised for the hashed release layout (research R11,
// contracts/web-release.md).
//
// `tool/stage_web_release.sh` stamps the release hash and the mirror below. On a first
// visit the release loads straight from the mirror while `sw.js` registers in the
// background, so the 5 s first-load budget isn't spent waiting for a worker; later visits
// are served by the worker's cache. If the mirror cannot serve the entrypoint, one load
// from the app's own origin (Firebase) keeps a blocked mirror from breaking the launch.
//
// Flutter 3.47.7's `_flutter.loader.load()` only appends the entrypoint `<script>` and
// resolves: it never rejects when that script fails (M-R1-2). So the mirror is probed first
// (a HEAD of `main.dart.js`, `MIRROR_PROBE_MS`), and a failed entrypoint script is caught
// by a capture-phase `error` listener. Either one loads once from the own origin, and only
// the first entrypoint that arrives starts the app.
{{flutter_js}}
{{flutter_build_config}}

(() => {
  const MIRROR_PROBE_MS = 3000;

  const hash = '__RELEASE_HASH__';
  const stampedHash = hash !== '' && !hash.startsWith('__');
  const mirror = '__MIRROR_BASE__';
  const mirrorBase = stampedHash && !mirror.startsWith('__') ? mirror.replace(/\/+$/, '') : '';
  const releasePath = `/r/${hash}/`;

  const perf = new URLSearchParams(window.location.search).has('perf');
  const mark = (label) => {
    if (perf) console.log(`[madar-perf] ${label} +${Math.round(performance.now())} ms`);
  };
  mark('bootstrap');
  window.addEventListener('flutter-first-frame', () => mark('flutter-first-frame'));

  // Dart reads this for drift's wasm (lib/core/db/release_assets.dart).
  window.MADAR_RELEASE = { base: mirrorBase, hash: stampedHash ? hash : '' };

  const configFor = (base) => ({
    entrypointBaseUrl: `${base}${releasePath}`,
    assetBase: `${base}${releasePath}`,
    canvasKitBaseUrl: `${base}${releasePath}canvaskit/`,
  });
  const entrypointFor = (base) =>
    new URL(`${base}${releasePath}main.dart.js`, window.location.href).href;

  const registerWorker = () => {
    if (!('serviceWorker' in navigator)) return;
    // Only a staged `sw.js` is a classic script (tool/classic_sw.py); `flutter run` serves
    // the module source, which a classic registration cannot parse.
    if (!stampedHash) return;
    navigator.serviceWorker.register('/sw.js').catch((error) => {
      // A worker that will not register is not fatal: the app still loads from the mirror.
      console.warn('[madar] sw.js did not register', error);
    });
  };

  // Each `load()` injects its own entrypoint; a late one must not start a second app.
  let started = false;
  const load = (base) => {
    const config = configFor(base);
    return _flutter.loader.load({
      config,
      onEntrypointLoaded: (engineInitializer) => {
        if (started) return;
        started = true;
        mark('flutter-load');
        engineInitializer.initializeEngine(config).then((appRunner) => appRunner.runApp());
      },
    });
  };

  let fellBack = false;
  const loadFromOwnOrigin = (why) => {
    if (fellBack || started) return;
    fellBack = true;
    mark('mirror-failed');
    console.warn(`[madar] the mirror failed (${why}); loading from this origin`);
    window.MADAR_RELEASE = { base: '', hash };
    load('');
  };

  /** Whether the mirror answers for this release's entrypoint within MIRROR_PROBE_MS. */
  const mirrorAnswers = async () => {
    const controller = new AbortController();
    const timer = setTimeout(() => controller.abort(), MIRROR_PROBE_MS);
    try {
      const response = await fetch(entrypointFor(mirrorBase), {
        method: 'HEAD',
        mode: 'cors',
        signal: controller.signal,
      });
      return response.ok;
    } catch (error) {
      return false;
    } finally {
      clearTimeout(timer);
    }
  };

  (async () => {
    registerWorker();
    // An unstaged file (`flutter run`, a test build) has no release folder: Flutter's
    // default addresses are the right ones.
    if (!stampedHash) return _flutter.loader.load();
    if (!mirrorBase) return load('');
    if (!(await mirrorAnswers())) return loadFromOwnOrigin('no answer to the probe');

    // A resource error doesn't bubble, but a capture listener on window sees it.
    const mirrorEntrypoint = entrypointFor(mirrorBase);
    window.addEventListener(
      'error',
      (event) => {
        const target = event.target;
        if (target && target.tagName === 'SCRIPT' && target.src === mirrorEntrypoint) {
          loadFromOwnOrigin('the entrypoint script failed');
        }
      },
      true,
    );
    try {
      await load(mirrorBase);
    } catch (error) {
      loadFromOwnOrigin(String(error));
    }
  })();
})();
