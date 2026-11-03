# Implementation review: 004-d04-mvp-launch, lane B1, round 2

- Date: 2026-11-03 · Reviewer: Claude Code (Opus 5.5)
- Branch: 004-d04-mvp-launch (all four lanes merged; reviewed here at the owner's request, as in round 1) · Base: master (merge base acbfece) · Head: 2a270b1, plus 21 uncommitted files and 3 untracked files across the four lanes
- Change: the round-1 fixes only. Lane B1's share is `backend/loadtest/mvp.js`, `docs/runbooks/load-testing.md`, research R2, and T006's wording plus the `### Review fixes (round 1)` ticks in `tasks.md`.
- Verdict: APPROVE WITH NOTES · CRITICAL 0 · HIGH 0 · MEDIUM 0 new (7 open from round 1) · LOW 0 new (4 open from round 1)

## Checks
| Check | Command | Result |
| --- | --- | --- |
| k6 thresholds | `docker run --rm -i grafana/k6:2.3.0 inspect -e HOST=… - < backend/loadtest/mvp.js` | exit 0. Six thresholds: `cache:hit` p95<150, `cache:miss` p95<400, `scenario:live` p95<150, `scenario:matches` p95<400, `checks` rate>0.99, `http_req_failed` rate<0.01 |
| k6 short run | public API from `uvicorn app.public:app` on the dev PostgreSQL 16 and Redis 7, then `docker run --rm -i --network host grafana/k6:2.3.0 run -e HOST=http://127.0.0.1:8765 -e LIVE_RPS=20 -e MATCHES_RPS=10 -e DURATION=20s -` | exit 0. 601 requests; the API log shows `/v1/matches` 40× 200 and 160× 304, **zero 422**. The 3 `429`s on `/v1/live` (127.0.0.1 not exempt in this run) were counted as failures (0.50 %), which shows the response callback works |
| old query | `curl …/v1/matches?date=2026-11-03` | 422, as round 1 said; `from`/`to` for one UTC day answers 200 with the envelope |
| backend suite | — | NOT RUN: no file under `backend/app/` or `backend/tests/` changed since round 1 |

## Previous round
| Finding | Now |
| --- | --- |
| B1-R1-1 `matches` sent `date=` (HIGH) | **fixed**: `utcDayWindow()` sends `from`/`to` (`Z` bounds, one UTC day), a `check()` requires a `data` array, and T006, R2 and the runbook say `from=&to=`. The short run shows zero 422s |
| B1-R1-2 live 200s held to 400 ms (HIGH) | **fixed**: `http_req_duration{scenario:live}` p95<150 covers every `/v1/live` response. `miss` is now the first fetch per URL per minute per VU, as T006 says, and `REVALIDATE_SHARE` is an `-e` variable that is validated to be 0–1 |
| B1-R1-3 the allowlist checks could not fail (HIGH) | **fixed**: steps 2 and 4 read the container's effective `RATE_LIMIT_EXEMPT_IPS` with `docker exec … sh -c 'test -n/-z …'`, which exits 1 on the wrong state. `vps1.yml:84` passes the variable through, so the check reads what the app reads. The log grep is kept with `2>&1` |
| B1-R1-4 the public app configures no logging | still open (MEDIUM) |
| B1-R1-5 `TRUSTED_PROXIES` named instead of `TRUSTED_PROXIES_PUBLIC` | still open (`load-testing.md:69, 192`) |
| B1-R1-6 the report's numbers are lost | partly fixed: the per-scenario thresholds now exist. `loadtest-summary.json` still stays inside the `--rm` container (`load-testing.md:44`), there's no `dropped_iterations` guard, and `| tee` still hides k6's exit code |
| B1-R1-7 test gaps in `limits.py` and the settings | still open |
| B1-R1-8 an IP can be both exempt and trusted | still open |
| B1-R1-9 no quiet-hour / abort step | still open |
| B1-R1-10 docker as `ubuntu`, `ssh -J` | **fixed** with B1-R1-3: commands run as `deploy` over the `madar-vps1` and `madar-vps2` aliases |
| B1-R1-11 commit 2a270b1 is outside any lane task | still open |
| LOW (4) | still open |

## Findings
None new. The script and the runbook changes do what the three tasks asked for, and I could disprove each of the round-1 failure scenarios with a real run.

## Requirements
| Requirement | Built in | Proven by | Status |
| --- | --- | --- | --- |
| US1 AC1 / FR-002 (live 170 rps, p95 < 150) | `mvp.js` `live`, `scenario:live` threshold | `k6 inspect`; the short local run | ready for T009 |
| US1 AC2 (matches 50 rps) | `mvp.js` `matches` | the short local run: zero 422s | ready for T009 |
| US1 AC3 / FR-007 (allowlist window) | `settings.py`, `ratelimit.py`, runbook steps 2 and 4 | `test_ratelimit.py`, `test_client_ip.py`; the runbook checks now fail on the wrong state | met |
| US1 AC5–6 / FR-004–006 | — | — | open (T010–T012) |
| FR-003 (report) | runbook step 6 | — | still limited by B1-R1-4 and B1-R1-6 |

## Task audit
Ticked 9 (6 from round 1 plus B1-R1-1 … 3), verified 9, not done 0, partly done 0. T005 is unticked and stays as round 1 described it.

## Owner must review
- `docs/runbooks/load-testing.md` steps 2 and 4: the commands that open and close the rate-limit allowlist window.
- No contract, migration, auth or audience change.

## Outside this change
- The other lanes' fixes in the same working tree (rounds `b2-`, `a-` and `m-round-2.md`).

## Not reviewed
- k6 against the hosts (T009), the two-network check (T008) and the security and host reviews (T010–T012) need VPS-1 and VPS-2.
