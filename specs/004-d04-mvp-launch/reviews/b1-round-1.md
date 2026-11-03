# Implementation review: 004-d04-mvp-launch, lane B1, round 1

- Date: 2026-11-03 · Reviewer: Claude Code (Opus 5.5; layer subagents on Sonnet, every finding re-checked)
- Branch: 004-d04-mvp-launch (all four lanes merged; reviewed here at the owner's request, not on `d04-b1`) · Base: master (merge base acbfece) · Head: 2a270b1, plus 0 uncommitted files
- Change: 25 commits in the range; lane B1's share is 15 files under `backend/` plus its runbooks (`load-testing.md`, `response-cache-and-limits.md`, the B1 rows of `owner-actions.md`)
- Verdict: CHANGES REQUESTED · CRITICAL 0 · HIGH 3 · MEDIUM 8 · LOW 4

## Checks
| Check | Command | Result |
| --- | --- | --- |
| ruff | `cd backend && uv run ruff check .` | exit 0, all checks passed |
| ruff format | `uv run ruff format --check .` | exit 1: `app/adapters/report.py` (B2's file; CI does not run it) |
| mypy | `python -m mypy --strict app` (from a clean `git archive` copy) | exit 0, 144 files. In place it exits 2 because of a stray `~/__init__.py` on this machine, not the code |
| pytest | `uv run pytest --cov` against dev PostgreSQL 16 and Redis 7 | exit 1: only the 4 `tests/adapters/test_homebox_acl.py` failures (the dev Redis password, known since D3); coverage 94.77 % (bar 70 %) |
| OpenAPI | `export-openapi` | NOT RUN here; B1 reports no change and no API file changed |
| k6 | `k6 inspect` / run | NOT RUN (needs the hosts; T009) |

## Findings
### HIGH
#### B1-R1-1: The k6 `matches` scenario calls a query the API rejects
- Load script · FR-001, FR-002, US1 AC2, SD §6.3.2 · `backend/loadtest/mvp.js:132` · CONFIRMED
- Problem: it requests `/v1/matches?date=<YYYY-MM-DD>`, but `list_matches` requires `from` and `to` (`backend/app/api/public/matches.py:30-31`, `Query(..., alias="from")`). There is no `date` parameter.
- Failure scenario: every `matches` request answers 422. The `expectedStatuses(200, 304)` callback counts that as a failure, so about 23 % of the run fails and AC2 can never pass. The owner learns this only after opening the allowlist window.
- Fix direction: send `from`/`to` as UTC day bounds for today to +3, check the envelope's `data` array, and fix the same `date=` wording in T006, research R2 and the runbook.

#### B1-R1-2: `/v1/live`'s full responses get the 400 ms budget instead of 150 ms
- Load script · US1 AC1, FR-002, SC-001 · `backend/loadtest/mvp.js:68-73, 110-113` · CONFIRMED
- Problem: `revalidate = liveEtag !== null && __ITER % 2 === 1`. Every request without `If-None-Match` is tagged `cache:miss`, so all full 200s from `/v1/live` (served from the Redis cache) are held only to `p(95)<400`.
- Failure scenario: full 200s at p95 ≈ 380 ms with fast 304s pass every threshold, and the gate reads green while AC1's "p95 under 150 ms" is broken.
- Fix direction: add `http_req_duration{scenario:live}: p(95)<150`, tag `miss` only as T006 says (first fetch per URL per minute), and make the `If-None-Match` share an `-e` variable.

#### B1-R1-3: The runbook's "allowlist is empty again" check can't fail
- Runbook · spec edge case "the allowlist is left filled = HIGH", T007 ("every command must match the code") · `docs/runbooks/load-testing.md:72, 120` · CONFIRMED
- Problem: `docker logs … | grep ratelimit.exempt_enabled`. The warning goes to stderr (no logging config, Python's last-resort handler), and `docker logs` writes container stderr to its own stderr, which the pipe never sees.
- Failure scenario: step 2 never shows the confirmation, and step 4's `grep -c … # 0` prints 0 whether or not the window was closed. A forgotten allowlist goes unnoticed.
- Fix direction: check the effective value (`docker exec madar-api-public-1 printenv RATE_LIMIT_EXEMPT_IPS`, expect empty), or at least `2>&1`.

### MEDIUM
- **B1-R1-4: The public app configures no logging** (`backend/app/public.py`; the only setup is `app/workers/logs.py`, Celery-only). `ratelimit.exempt` info and debug lines and the `madar.cache` counters are dropped at the root's WARNING level, so T005's "one info line a minute" and FR-003's cache hit share (data-model) can't come from the API's logs. The test passes only because caplog lowers the level. Configure JSON logging at INFO in `create_app()`, or take that evidence from k6.
- **B1-R1-5: Docs name the wrong variable.** `load-testing.md:166` and `response-cache-and-limits.md:50` say `TRUSTED_PROXIES`; the Compose key is `TRUSTED_PROXIES_PUBLIC` (`infra/compose/vps1.yml:82`). A `TRUSTED_PROXIES=` line in `.env` does nothing for `api-public` and silently changes `api-admin` through `env_file`.
- **B1-R1-6: The report's numbers are lost or missing.** `docker run --rm` drops `handleSummary`'s JSON file. The per-scenario latencies need a threshold on the `scenario` tag to exist. There is no `dropped_iterations` guard, and `| tee` hides k6's exit code. Mount an output dir or print the JSON, add per-scenario and `dropped_iterations` thresholds, and use `pipefail`.
- **B1-R1-7: Test gaps.**
  - No test has a trusted hop inside `X-Forwarded-For`; deleting `if address in trusted: continue` (`limits.py:85`) keeps the suite green.
  - `RATE_LIMIT_EXEMPT_IPS` parsing, validation and default are untested.
  - The tests pass settings as init kwargs, so dropping `NoDecode` would break startup unseen.
  - The minute rollover of the summary is untested.
- **B1-R1-8: Nothing stops one IP from being both exempt and trusted** (`settings.py:84-97`). With `172.30.0.1` copied into the allowlist (the key a broken setup shows), a missing or all-trusted header returns the trusted peer, which is exempt, and the limiter is off for everyone. Reject the overlap in a validator.
- **B1-R1-9: The runbook has no "quiet hour / stop" step, and the script has no abort threshold** (spec edge case "the load test hurts real users").
- **B1-R1-10: The runbook's k6 command runs as `ubuntu`, which isn't in the docker group**; other runbooks use `sudo -iu deploy docker …`. It also uses `ssh -J ubuntu@…` instead of the `madar-vps1`/`madar-vps2` aliases.
- **B1-R1-11: Commit 2a270b1 changed B1's `backend/app/workers/__init__.py` and `tests/unit/test_workers.py` outside any lane or task** (FR-042). It's an owner hotfix for the 2026-11-02 home-box hang, made on the spec branch. B1 should acknowledge it in its section. The change itself is sound (see LOW).

### LOW
- `limits.py:79` reads only the first `X-Forwarded-For` header line; join `getlist()` for hardening (Caddy sends one line).
- `workers/__init__.py:85-95`: `socket_keepalive` without options and `health_check_interval: 25` (kombu's default) add little; `socket_timeout` is the real fix.
- Runbook step 5's 700 sequential `curl`s may take longer than the 60 s window; run them in parallel.
- The exempt list has no expiry; consider `RATE_LIMIT_EXEMPT_UNTIL`, or exposing the state to Kuma.

## Requirements
| Requirement | Built in | Proven by | Status |
| --- | --- | --- | --- |
| US1 AC1 / FR-002 (live 170 rps, p95 < 150) | `mvp.js` live | not run (T009) | thresholds wrong (B1-R1-2) |
| US1 AC2 (matches 50 rps) | `mvp.js` matches | none | broken (B1-R1-1) |
| US1 AC3 / FR-007 (allowlist window, forged header, 429 fails) | `settings.py`, `ratelimit.py`, `limits.py`, runbook | `test_ratelimit.py`, `test_client_ip.py` | code met; runbook check inert (B1-R1-3) |
| US1 AC4 (fix and re-run) | runbook | none | written |
| US1 AC5–6 / FR-004–006 (security review, host review) | none | none | open (T010–T012); `security-review.md` does not exist |
| FR-001 | `mvp.js` | none | partial |
| FR-003 (report) | runbook step 6 | none | blocked by B1-R1-4 and B1-R1-6 |
| FR-043 | owner-actions | secret scan in this review | met |
| FR-044 | `load-testing.md`, README rows | read | met, with B1-R1-3, B1-R1-5 and B1-R1-10 |

## Task audit
Ticked 6, verified 4, not done 2, partly done 0.
| Task | Finding |
| --- | --- |
| T006 | ticked; the `matches` scenario is broken and the live tags are wrong (B1-R1-1, B1-R1-2) |
| T007 | ticked; the clear-window check doesn't work (B1-R1-3) and the docker commands need `deploy` (B1-R1-10) |
| T005 (unticked) | code part complete; its info logging does nothing in production (B1-R1-4) |

## Owner must review
- `backend/app/auth/limits.py` and `backend/app/api/ratelimit.py`: the trust list and the exempt early return (auth and rate limiting).
- `infra/compose/vps1.yml` `api-public` block (B2's file): the same trust list as `--forwarded-allow-ips`.
- No contract or migration changed.

## Outside this change
- The `test_homebox_acl.py` failures come from this machine's dev Redis password (D3 note), not from code.

## Not reviewed
- k6 not run (needs VPS-2 and the window); host checks T008, T012 not run; `export-openapi` not run locally.
