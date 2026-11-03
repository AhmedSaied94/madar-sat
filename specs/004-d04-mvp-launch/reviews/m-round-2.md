# Implementation review: 004-d04-mvp-launch, lane M, round 2

- Date: 2026-11-03 · Reviewer: Claude Code (Opus 5.5)
- Branch: 004-d04-mvp-launch (all four lanes merged; reviewed here at the owner's request, as in round 1) · Base: master (merge base acbfece) · Head: 2a270b1, plus 21 uncommitted files and 3 untracked files across the four lanes
- Change: the round-1 fixes only. Lane M's share is `app/web/flutter_bootstrap.js`, `app/tool/stage_web_release.sh`, the new `app/tool/classic_sw.py`, `app/test_web/sw_classic.test.mjs` and `app/test_web/bootstrap.test.mjs`, and `app/CLAUDE.md`.
- Verdict: APPROVE WITH NOTES · CRITICAL 0 · HIGH 0 · MEDIUM 1 new (10 open from round 1) · LOW 1 new (7 open from round 1)

## Checks
| Check | Command | Result |
| --- | --- | --- |
| worker and bootstrap tests | `cd app && node --test test_web/` | exit 0, 22/22 (12 core, 4 classic worker, 6 bootstrap) |
| staged `sw.js` as a classic script | `python3 tool/classic_sw.py web/sw.js web/sw_core.mjs > sw.cjs && node --check sw.cjs` | exit 0 |
| stage script | `RTEST_HOST=flutter-tests rtest test/core/web/release_layout_test.dart` (the test box) | exit 0, 10 passed |
| loader behaviour | read the pinned 3.47.7 loader (`flutter_js/src/loader.js:173-180`, `entrypoint_loader.js:118-128, 205`) | `load()` builds a **new** `FlutterEntrypointLoader` each call, so a second `load('')` does inject its script (round 1's remark about `_scriptLoaded` was wrong). `scriptTag.src` reads back as the absolute URL that `entrypointFor()` builds |
| `flutter analyze`, full `flutter test` | — | NOT RUN: no Dart file changed since round 1 |
| browser, device, preview channel | — | NOT RUN (T069–T072) |

## Previous round
| Finding | Now |
| --- | --- |
| M-R1-1 `sw.js` could never register (HIGH) | **fixed**: step 5b of the stage script inlines `sw_core.mjs` into a classic `sw.js` (`tool/classic_sw.py`, which wraps the core in an IIFE and refuses any leftover `import`/`export`). The bootstrap registers only a stamped (staged) worker and always logs a failure. `sw_classic.test.mjs` runs the staged form in a `vm.Script`, through install, activate and one release fetch |
| M-R1-2 the mirror fallback never ran (HIGH) | **fixed**: a 3 s `HEAD` probe of the mirror's `main.dart.js` (Caddy's CORS matcher allows `GET HEAD`), plus a capture-phase `error` listener on the mirror's entrypoint `<script>`. Either one loads once from the own origin, and `started` lets only the first entrypoint start the app. `bootstrap.test.mjs` covers mirror OK, probe failure, a script error, and a late second entrypoint |
| M-R1-3 … M-R1-12 | still open (`sw_core.mjs`, the drift shim and `bug-bash.md` are unchanged) |
| LOW: registration failures logged only with `?perf` | **fixed** (`console.warn` always) |
| other LOW (7) | still open |

## Findings
### MEDIUM
#### M-R2-1: Every repeat open now waits for the mirror before the cached entrypoint loads
- Web shell · FR-034 and SC-007 (repeat open < 1.5 s), SC-008a · `app/web/flutter_bootstrap.js:82-105` · PLAUSIBLE (only the T072 timing will settle it)
- Problem: the probe is a `HEAD`, and `sw.js` passes every non-`GET` to the network (`if (request.method !== 'GET') return;`). So on every open, including repeat opens that the worker serves from cache, the bootstrap first opens a connection to the mirror and waits for its answer before it starts `main.dart.js`.
- Failure scenario: on a repeat open over 4G, DNS, TLS and the `HEAD` to the mirror host take a few hundred milliseconds of the 1.5 s budget. With a slow or hung mirror, every open waits the full 3 s, and then loads from the own origin. A worker is already controlling the page and would have served the file from its cache either way.
- Fix direction: skip the probe when `navigator.serviceWorker.controller` is set, because the worker already falls back from the mirror to the own origin for release files. Or let the worker answer the probe from its cache.

### LOW
- **M-R2-1b:** once the probe passes, a mirror that then stalls on the `main.dart.js` body has no watchdog (round 1 asked for "a timeout for a hung mirror"). This is rare, since the probe just succeeded, but the splash would wait for the browser's own timeout.

## Requirements
| Requirement | Built in | Proven by | Status |
| --- | --- | --- | --- |
| US2 AC9 / FR-038 (worker caches the release) | `classic_sw.py`, stage step 5b, `sw.js`, `sw_core.mjs` | `sw_classic.test.mjs`, `sw_core.test.mjs` | met in code; browser run is T069; not in CI until B2's T046 |
| US2 AC10 (blocked mirror → own origin) | `flutter_bootstrap.js` probe and error listener | `bootstrap.test.mjs` | met in code; M-R1-8 (drift shim) still open |
| US2 AC11 | as in round 1 | — | the worker now registers, so replacement can be checked in T069 |
| FR-034 / SC-007 | `?perf=1` marks | none | open (T072); see M-R2-1 |
| the rest of US2 | as in round 1 | — | unchanged |

## Task audit
Ticked 12 (10 from round 1 plus M-R1-1 and M-R1-2), verified 11, not done 0, partly done 1 (T064/T065: the stray-root-file case, M-R1-9).

## Owner must review
- `app/web/flutter_bootstrap.js` and `app/tool/classic_sw.py`: what code the public PWA runs, where it loads from, and when it switches to Firebase.

## Outside this change
- The other lanes' fixes in the same working tree.

## Not reviewed
- No browser, device or preview-channel run (T069–T072), and no real `flutter build web` plus staging (the layout test stages a fake build).
