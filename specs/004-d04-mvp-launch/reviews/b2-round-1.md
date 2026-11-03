# Implementation review: 004-d04-mvp-launch, lane B2, round 1

- Date: 2026-11-03 · Reviewer: Claude Code (Opus 5.5; layer subagents on Sonnet, every finding re-checked)
- Branch: 004-d04-mvp-launch (all four lanes merged; reviewed here at the owner's request, not on `d04-b2`) · Base: master (merge base acbfece) · Head: 2a270b1, plus 0 uncommitted files
- Change: 25 commits in the range; lane B2's share is 19 files (`infra/`, `.github/`, `backend/app/adapters/`, adapter tests) plus its runbooks
- Verdict: CHANGES REQUESTED · CRITICAL 0 · HIGH 3 · MEDIUM 8 · LOW 8

## Checks
| Check | Command | Result |
| --- | --- | --- |
| backend suite (adapters included) | `uv run pytest --cov` | exit 1: only the 4 known `test_homebox_acl.py` dev-Redis failures; coverage 94.77 % |
| ruff | `uv run ruff check .` | exit 0 |
| ruff format | `uv run ruff format --check .` | exit 1: `backend/app/adapters/report.py:133` would be reformatted (not a CI gate) |
| mypy | `mypy --strict app` (clean copy) | exit 0 |
| shell syntax | `bash -n` on every changed script (subagent) | exit 0, all 16 |
| backup heartbeat check | `infra/scripts/check-backup-heartbeat.sh` (subagent) | exit 0 |
| Compose | `docker compose -f infra/compose/vps1.yml config` with a dummy env (subagent) | renders the subnet, gateway and trust list as specified |
| Caddy | `caddy validate`, plus the real `app.` and `10.8.0.1` blocks run in `caddy:2.11.7` against a fake mirror (subagent) | headers, CORS, no listing and no traversal as specified |
| release job's mirror read | reproduced in a clean checkout under `set -euo pipefail` (subagent) | exit 2: `Could not open file app/env/prod.json` (B2-R1-1) |
| shellcheck / actionlint | not installed | NOT RUN |

## Findings
### HIGH
#### B2-R1-1: The `web-v*` release job can never reach the live deploy
- CI · T045, FR-015, US3 AC6, contracts/web-release.md "B2 provides" step 3 · `.github/workflows/pwa.yml:187` · CONFIRMED
- Problem: `mirror=$(jq -r '.MIRROR_BASE_URL' app/env/prod.json …)` runs in the `release` job. `app/env/prod.json` is git-ignored (`app/.gitignore:53`) and written only in the `build` job, and the artifact doesn't carry it.
- Failure scenario: on `web-v0.1.0`, the mirror copy succeeds, then this step dies under `set -e` and the live deploy is skipped. Every release stops here, so the PWA can't go public (DC7).
- Fix direction: read `.mirror` from `web_release/release.json` (the stage script writes it into the artifact), or pass it as a `build` job output. Keep the `https://` check, and derive the `Origin` header from the project instead of hard-coding `madar-sat.web.app`.

#### B2-R1-2: The merge breaks the admin site until someone re-runs the bootstrap, and nothing says so
- Infra and CI · FR-020, US4 AC1, T039–T041, infra/CLAUDE.md (a changed setup step lands in its runbook) · `.github/workflows/admin.yml:95`, `infra/Caddyfile` wg0 `root * /srv/admin/current`, `infra/scripts/deploy.sh` (no check), `docs/owner-actions.md` D4 B2 "Before merge" · CONFIRMED
- Problem:
  - Only `bootstrap-vps.sh` creates `/srv/admin/releases/placeholder` and the `current` symlink.
  - `deploy.sh` doesn't check for them, and the owner's before-merge list never says to re-run `bootstrap-vps.sh vps1`.
- Failure scenario: on merge, `infra.yml` reloads Caddy with the new root, and the admin SPA answers 404. The same push's admin deploy fails at `readlink /srv/admin/current` with a bare exit 1.
- Fix direction:
  - Add `check_dir`/symlink checks to `deploy.sh` that name `sudo bootstrap-vps.sh vps1`.
  - Make the admin deploy's `readlink` fail with an `::error::` that names the fix.
  - Put the bootstrap re-run first in the owner's before-merge list and in the README setup order.

#### B2-R1-3: The new VPS-1 jobs run outside `deploy-vps1` and re-sync `infra/` from their own checkout
- CI · constitution IX, `docs/runbooks/deploy-and-rollback.md:36` ("deploys never overlap … `deploy-vps1`"), D1 research · `.github/workflows/admin.yml:70-72` (group `deploy-vps1-admin`), `pwa.yml` `release` job (no deploy group), `.github/actions/vps1-sync/action.yml:62` (`rsync -a --delete … infra/ vps1:/srv/madar/infra/`) · CONFIRMED
- Problem: the admin deploy and the PWA release join wg0 with the same `WG_CI_CONFIG` peer as the backend and infra deploys, but in other concurrency groups. Through `vps1-sync`, they also overwrite `/srv/madar/infra/` on the host.
- Failure scenario:
  - This lane's own merge starts `infra.yml` sync and `admin.yml` deploy together: two runners bring up one peer, and one SSH session (possibly `deploy.sh`) stalls or drops mid-deploy.
  - A `web-v*` tag on an older commit rsyncs that commit's `infra/` over the host. The next `up -d` then runs a `vps1.yml` without the D4 subnet and trust list, which is R1 again.
- Fix direction: put both jobs in `group: deploy-vps1`, give `vps1-sync` an input that skips the `infra/` rsync for them, require a release tag to be an ancestor of `origin/master`, and update `deploy-and-rollback.md:36`.

### MEDIUM
- **B2-R1-4: The admin deploy's rollback has holes** (`admin.yml:107-124`). A failing CA fetch (`docker exec madar-caddy-1 cat …`) exits under `set -e` with `current` already swapped and no restore. `curl` has no `--max-time`. Arm `trap restore ERR` after the swap and add `--max-time 15 --retry 2` (constitution IX, T040 step 5).
- **B2-R1-5: FR-010 / SC-003 is not met yet.** T035's output shows 36 of 56 slots missing (home box down since 2026-11-02, recovered by hand). T035 is ticked for running and explaining the report, which it did. DC1 needs a clean 48 h window (earliest about 2026-11-05) or the owner's acceptance.
- **B2-R1-6: Two commits sit outside every lane task.**
  - `a77f023` (LiveSoccerTV postponed rows and name matching) was committed on the spec branch into B2's folder. It saves no real page as a fixture (the test edits an old fixture by string replace), shows no failing-first evidence (FR-011), and contradicts T036/T037's "None found".
  - `2a270b1` (home-box hang recovery) adds `ops.scrape_home_backlog`, a seventh Kuma monitor and a restart in `home-box-update.sh`, with no task.
  - B2 should record both and commit trimmed real pages as `edge-*` fixtures.
- **B2-R1-7: The coverage report's "unmatched" column is wrong, and its database half is untested** (`report.py:344-366`). It lists `import_runs.log.skipped` refs (ids, URLs, channel refs), not team names, and keys them by run day, so +1…+3 always print `-`. `_fetch_runs`, `_fetch_triggers` and `_fetch_coverage` have no real-Postgres test.
- **B2-R1-8: The live deploy drops the previous release from Firebase, and the `**` → `/index.html` rewrite answers missing `/r/<old>/…` files with `200 text/html`** (`pwa.yml:206-219`, `firebase.json:5`). That breaks the contract's "previous release stays on both", and Lane M's worker will cache the HTML (M-R1 notes). Exclude `/r/**` from the rewrite, or deploy the previous hash folder too.
- **B2-R1-9: On-call and PWA runbook commands don't work as written** (FR-013, US3 AC4).
  - Hosts written as `api.<VPS1_IP>` lack `.sslip.io` (`on-call.md:69-132`, `pwa-release.md:30-72`).
  - These anchors are broken: `pwa-release.md#check-the-mirror` and `#roll-back-the-live-channel`, `workers.md#worker-media`, `uptime-kuma.md#4-push-monitors-six` (`backups.md:100`).
  - `pwa-release.md:134` uses `../specs` (should be `../../specs`).
  - There is no row for the new `scrape-home` monitor.
  - `on-call.md:87` cites a section that doesn't mention the report.
  - `secrets.md:27` still says "six", and `private-network.md:162` and `infra/README.md:55` still describe a flat `/srv/admin`.
- **B2-R1-10: The `scrape-home` monitor stays down during the documented offline procedure** (`adapters/tasks.py:683-709`). Expired messages stay in `celery:scrape_home` while nobody consumes it. `_broker_redis()` also has no `socket_timeout`, which is the hang class 2a270b1 fixes. Skip or annotate the push when no source uses `scrape_home`, add timeouts, and document pausing the monitor.
- **B2-R1-11: T042 and T046 are unblocked but still open.** Lanes A and M are merged on this branch, yet `admin.yml` has no Playwright step and `app.yml` no `node --test app/test_web/`, so FR-038's worker tests run nowhere in CI.

### LOW
- `pwa.yml` doesn't install `brotli` explicitly (the stage script needs it; `firebase-hosting.md:130` says to install it).
- `release-check.txt` is written before the mirror check and the live deploy, so Kuma can show a hash that isn't live yet.
- The preview's "stage script missing" fallback (`pwa.yml:83-86`) now only hides failures; make it an error.
- The mirror check has no `--max-time` and no negative CORS case.
- T048's "forced mirror failure" has no switch (`workflow_dispatch` takes no input).
- T030 records no manual `systemctl start backup-db.service` run after the fix.
- `infra.yml`'s timer check is a plain grep, and `report.py` accepts `--hours 0` and crashes on `--days 0`.
- Slot edge cases in `report.py`: a slot inside its tolerance reads `missing`, breaker resumes go undetected, and manual attribution is by time only.

## Requirements
| Requirement | Built in | Proven by | Status |
| --- | --- | --- | --- |
| US3 AC1 / FR-010 / SC-003 | `report.py runs` | T035 output | not met (B2-R1-5) |
| US3 AC2 / FR-011 | a77f023 (out of task) | synthetic fixture edits | partial (B2-R1-6) |
| US3 AC3 / FR-012 | `report.py coverage` | T035 output | met, with B2-R1-7 |
| US3 AC4 / FR-013 | `on-call.md`, README rows | read | partial (B2-R1-9) |
| US3 AC5 / FR-014 | `infra/Caddyfile` `app.` site, `infra.yml` checks | Caddy run in a container; host pending (T048) | met in config |
| US3 AC6 / FR-015 | `pwa.yml` | static and reproduced | not met (B2-R1-1, B2-R1-8) |
| US3 AC7 | `uptime-kuma.md` | read | met on the docs side |
| FR-016 | backup scripts, `check-backup-heartbeat.sh`, `infra.yml` | the 01:05 run, the check script | partial (no manual run recorded) |
| FR-020 (B2's half) | `admin.yml` deploy, Caddy root | static | blocked by B2-R1-2, B2-R1-3 |

## Task audit
Ticked 15, verified 12, not done 1, partly done 2.
| Task | Finding |
| --- | --- |
| T045 | not done as written: the release can't pass step 3 (B2-R1-1) |
| T039 / T049 | partly done: the bootstrap layout exists, but neither the deploy nor the owner list requires the re-run (B2-R1-2) |
| T040 | partly done: the rollback has holes (B2-R1-4) and the job is outside `deploy-vps1` (B2-R1-3) |

## Owner must review
- `.github/workflows/pwa.yml` `release` job and `admin.yml` `deploy` job: what they write on VPS-1 and when.
- `infra/Caddyfile` `app.` site and wg0 root: CORS origins and cache headers.
- `infra/compose/vps1.yml` `api-public`: the subnet and trust list behind the client IP.
- `backend/app/adapters/tasks.py` `ops.scrape_home_backlog` (2a270b1): the new monitor's behaviour.

## Outside this change
- The `test_homebox_acl.py` failures are this machine's dev Redis password.

## Not reviewed
- Nothing ran on a host or in GitHub Actions; shellcheck and actionlint are not installed.
