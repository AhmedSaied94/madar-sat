// Flutter's web bootstrap, customised for the hashed release layout (research R11,
// contracts/web-release.md).
//
// `tool/stage_web_release.sh` stamps the release hash and the mirror below. On a first
// visit the release loads straight from the mirror while `sw.js` registers in the
// background, so the 5 s first-load budget isn't spent waiting for a worker; later visits
// are served by the worker's cache. If the mirror cannot serve the entrypoint, one retry
// from the app's own origin (Firebase) keeps a blocked mirror from breaking the launch.
{{flutter_js}}
{{flutter_build_config}}

(() => {
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

  const registerWorker = () => {
    if (!('serviceWorker' in navigator)) return;
    navigator.serviceWorker.register('/sw.js').catch((error) => {
      // A worker that will not register is not fatal: the app still loads from the mirror.
      if (perf) console.warn('[madar-perf] sw.js did not register', error);
    });
  };

  const start = async (base) => {
    try {
      // An unstaged file (`flutter run`, a test build) has no release folder: Flutter's
      // default addresses are the right ones.
      await _flutter.loader.load(stampedHash ? { config: configFor(base) } : undefined);
      mark('flutter-load');
      return true;
    } catch (error) {
      if (!base) throw error;
      mark('mirror-failed');
      window.MADAR_RELEASE = { base: '', hash: stampedHash ? hash : '' };
      return false;
    }
  };

  (async () => {
    registerWorker();
    if (await start(mirrorBase)) return;
    // The mirror was blocked or down: the own origin is the fallback the worker would
    // have given the next visit anyway.
    await start('');
  })();
})();
