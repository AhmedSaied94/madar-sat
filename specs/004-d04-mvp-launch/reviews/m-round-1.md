# Implementation review: 004-d04-mvp-launch, lane M, round 1

- Date: 2026-11-03 · Reviewer: Claude Code (Opus 5.5; layer subagents on Sonnet, every finding re-checked)
- Branch: 004-d04-mvp-launch (all four lanes merged; reviewed here at the owner's request, not on `d04-m`) · Base: master (merge base acbfece) · Head: 2a270b1, plus 0 uncommitted files
- Change: Lane M's commits 97c3bcb…0bf278d; 33 files under `app/`, plus `firebase-hosting.md`, `local-dev.md`, the bug-bash files and the M rows of `owner-actions.md`
- Verdict: CHANGES REQUESTED · CRITICAL 0 · HIGH 2 · MEDIUM 10 · LOW 8

## Checks
| Check | Command | Result |
| --- | --- | --- |
| analyze | `flutter analyze` | exit 0, no issues |
| tests | `RTEST_HOST=flutter-tests rtest --coverage` (the test box) | exit 0, 663 passed, 1 skipped (a `write_env_test.dart` case that needs `env/example.json`, which rtest doesn't sync; CI has it) |
| worker tests | `node --test test_web/` | exit 0, 12/12 |
| token copy | `./tool/check_token_copy.sh` | exit 0 |
| literals | `./tool/check_literals.sh` | exit 0 |
| `sw.js` as registered | `sw.js` parsed as a classic script (`node --check` on a `.cjs` copy, subagent) | SyntaxError: `Cannot use import statement outside a module` (M-R1-1) |
| zones / web build / stage | `./tool/test_all_zones.sh`, `flutter build web`, `stage_web_release.sh` | NOT RUN here (Lane M reports a staged build); no browser run (T069) |

## Findings
### HIGH
#### M-R1-1: `sw.js` can never register
- Web shell · FR-038, US2 AC9–11, SC-008a, research R12, T066 · `app/web/sw.js:11-16`, `app/web/flutter_bootstrap.js:37` · CONFIRMED
- Problem: `sw.js` starts with a static `import … from './sw_core.mjs?h=…'`. The bootstrap registers it with `navigator.serviceWorker.register('/sw.js')`, which is a classic worker, and a classic worker can't use `import`. The `.catch` logs only with `?perf`.
- Failure scenario:
  - Registration rejects silently, so no worker ever controls the page.
  - Repeat opens aren't served from the worker's cache, the cached app doesn't open offline, and a new release never replaces a worker.
  - Bug-bash X1/X2/X5 and quickstart M step 4 fail on the first browser run.
  - The node tests import `sw_core.mjs` directly, so they can't see this.
- Fix direction: register with `{ type: 'module' }` (check Safari/iOS ≥ 16.4 support), or stage a classic `sw.js` with the core inlined. Add a test that loads `sw.js` the way it is registered, and log registration failures always.

#### M-R1-2: The bootstrap's mirror → own-origin fallback never runs
- Web shell · US2 AC10, FR-038, research R11, T067 item 2, spec edge case "the mirror is down or slow" · `app/web/flutter_bootstrap.js:43-64` · CONFIRMED
- Problem: in the pinned Flutter 3.47.7 loader, `load()` always supplies an `onEntrypointLoaded` callback (`flutter_js/src/entrypoint_loader.js:62-65`). `_loadJSEntrypoint`'s callback branch (`:118-128`) only appends the `<script>` and returns: no error listener, no rejection. So `await _flutter.loader.load(...)` resolves before the entrypoint is fetched, and a blocked or 404ing mirror never reaches the `catch`.
- Failure scenario: on a first visit with an empty cache and the mirror down (VPS-1 or Caddy outage, or the DevTools block in AC10), the PWA shows the splash forever instead of loading from Firebase. M-R1-1 means there's no worker to help on later opens either.
- Fix direction: detect the entrypoint failure yourself (an `error` listener on the injected script or a probe of `main.dart.js`, plus a watchdog for a hung mirror), then load with `base: ''` while making sure only one app starts. The loader's `_scriptLoaded` guard blocks a second `load()`. Cover this with a node test that stubs `_flutter.loader`.

### MEDIUM
- **M-R1-3: The offline navigation fallback looks up a key nothing writes** (`sw_core.mjs:143-157`). It falls back to `/index.html`, but navigations are stored under their own path (`/`, `/match/12`). The test pre-seeds `/index.html` by hand. An offline open of an unvisited path fails.
- **M-R1-4: `cache.put` sits inside the fetch `try`** (`sw_core.mjs:125-130, 147-149`). A quota error discards a good response and refetches from Firebase (Spark quota), or fails the file. Return the response regardless and log the put error.
- **M-R1-5: Any `response.ok` is cached, so Firebase's `**` → `/index.html` rewrite can be cached as `main.dart.js`** (with B2-R1-8). A pruned or missing hash on the mirror means own-origin answers `200 text/html`, which is pinned cache-first. Reject `text/html` for non-HTML release paths.
- **M-R1-6: The 3 s mirror timeout is a `Promise.race`, not the `AbortController` T066 asks for** (`sw_core.mjs:176-189`). The losing download keeps competing for bandwidth, and every file waits its own 3 s on a hung mirror. Abort it, and remember a failed mirror briefly.
- **M-R1-7: Cache hits wait on `release()`** (an un-timed `fetch('/release.json')`, `sw.js:77-79`), and shell requests are network-first with no timeout. A hanging network delays the repeat open that SC-007 times.
- **M-R1-8: The `drift_worker.js` shim imports only from the mirror** (`stage_web_release.sh:123-128`). With the mirror blocked and no worker, drift's worker fails to load. Add an `importScripts` fallback to the own origin.
- **M-R1-9: "A stray root file exits non-zero" isn't implemented** (contract, T064). The script moves every non-shell file into `r/<hash>/`, and the test of that name checks a leftover file in the output dir instead (`release_layout_test.dart:228-236`). Enforce an allow-list.
- **M-R1-10: `MIRROR_BASE_URL` validation (`^https://[^/]+$`) accepts quotes, `;`, spaces, `@`, `?`, `#`**, and the value is stamped unescaped into JSON and JS (`stage_web_release.sh:48, 131-154`). A typo in the secret ships a broken shell. Tighten the regex, write `release.json` with `json.dumps`, and fail if a placeholder is left.
- **M-R1-11: `bug-bash.md` misses parts of US2 AC2**: S0's load-failed state and S15's notifications group, competitions order/hide, clear cache and delete my data. DC4 is only as wide as this script.
- **M-R1-12: App code now runs from the mirror with no integrity check** (security review). `release.json` (served by Firebase) could carry per-file SHA-256s for the worker to verify before `cache.put`. Owner decision: harden, or record it as an accepted risk in plan.md Complexity Tracking.

### LOW
- T061 changed no production code: `swr_repository.dart` already surfaced failures as stream errors. The 4 new tests are characterization tests and couldn't have failed first. Record it as "already satisfied".
- `previousHash` (`sw.js:48`) is null or the current hash, so `activate` always deletes the prior release cache, contradicting `firebase-hosting.md`'s check.
- No `skipWaiting`: a new worker waits for every old client to close.
- `dev_ca.dart` gates on `!kReleaseMode` (profile builds included), and `devCaPath()`'s defaults and the Dio wiring are untested. `app/CLAUDE.md:25-28` still says debug builds use user CAs for the dev root.
- `teams_step_error_test.dart:99`'s name doesn't match what it asserts.
- `?perf=1` has no "first data" mark, so T072 needs DevTools.
- `sw.js:75` intercepts `/r/` on any host, not only the mirror's.
- `Range` requests aren't handled (nothing streams from `/r/` today).

## Requirements
| Requirement | Built in | Proven by | Status |
| --- | --- | --- | --- |
| US2 AC1 / FR-030 | `dev_ca*.dart`, `dio_provider.dart`, `teams_step.dart`, `team_search_provider.dart` | `dev_ca_test`, 4 SWR tests, `teams_step_error_test` | met in code; phone check is the owner's |
| US2 AC2 / FR-031 (script) | `bug-bash.md` | read | partial (M-R1-11) |
| US2 AC3 / FR-032 (run) | `bug-bash-results.md` template | none | open (T071) |
| US2 AC4 / FR-033 | B2's `pwa.yml` | — | blocked by B2-R1-1 |
| US2 AC5 / FR-034 | `?perf=1` marks | none | open (T072) |
| US2 AC6 / FR-035 | `app-release.yml` | — | open (T070) |
| US2 AC7 / FR-036 | `more_page.dart`, ARB | `more_install_row_test` | met |
| US2 AC8 / FR-037 | stage script, bootstrap, `release_assets*` | `release_layout_test`, `release_assets_test` | met except M-R1-9 |
| US2 AC9 / FR-038 | `sw_core.mjs`, `sw.js`, bootstrap | 12 node tests (core only) | not met (M-R1-1) |
| US2 AC10 | bootstrap retry, worker, shim | none | not met (M-R1-2, M-R1-8) |
| US2 AC11 | `firebase-messaging-sw.js` untouched | read | FCM scope intact; worker replacement moot while M-R1-1 stands |

## Task audit
Ticked 10, verified 7, not done 2, partly done 1.
| Task | Finding |
| --- | --- |
| T066 | not done: the worker can't register (M-R1-1); timeout without `AbortController` (M-R1-6) |
| T067 | not done: the retry path is dead code (M-R1-2) |
| T064 / T065 | partly done: the stray-root-file case is missing (M-R1-9) |

## Owner must review
- `app/web/sw.js`, `sw_core.mjs`, `flutter_bootstrap.js`: what code the public PWA runs and where it comes from.
- `app/tool/stage_web_release.sh`: what ships on each host.
- S16's install row next to its design PNG (no screenshot is attached yet).

## Outside this change
- None.

## Not reviewed
- No browser, device or preview-channel run (T069–T072). The zones script and a real web build were not re-run here.
