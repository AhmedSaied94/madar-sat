# Implementation review: 004-d04-mvp-launch, lane B2, round 2

- Date: 2026-11-03 · Reviewer: Claude Code (Opus 5.5)
- Branch: 004-d04-mvp-launch (all four lanes merged; reviewed here at the owner's request, as in round 1) · Base: master (merge base acbfece) · Head: 2a270b1, plus 21 uncommitted files and 3 untracked files across the four lanes
- Change: the round-1 fixes only. Lane B2's share is `.github/actions/vps1-sync/action.yml`, `admin.yml`, `infra.yml`, `pwa.yml`, `infra/scripts/deploy.sh`, the runbooks `README.md`, `deploy-and-rollback.md` and `pwa-release.md`, and the D4 B2 rows of `owner-actions.md`.
- Verdict: APPROVE WITH NOTES · CRITICAL 0 · HIGH 0 · MEDIUM 1 new (7 open from round 1) · LOW 0 new (8 open from round 1)

## Checks
| Check | Command | Result |
| --- | --- | --- |
| actionlint | `docker run --rm -v "$PWD:/repo" -w /repo rhysd/actionlint:1.7.12 -color` (as `infra.yml`) | exit 0 |
| shellcheck | `docker run --rm -v "$PWD:/mnt" -w /mnt koalaman/shellcheck:v0.11.0 --external-sources infra/scripts/*.sh infra/backup/*.sh` (as `infra.yml`) | exit 0 |
| shell syntax | `bash -n infra/scripts/deploy.sh` | exit 0 |
| new `infra.yml` step: admin symlink check | the step's `run:` extracted with PyYAML and run with `RUNNER_TEMP` in a scratch copy | exit 0: `check_dirs vps1` fails with no `current`, fails with `current` pointing at a release with no `index.html`, passes on the bootstrap layout; `admin.yml`'s `readlink` names the bootstrap |
| new `infra.yml` step: `deploy-vps1` group | the same, plus a negative copy with `admin.yml`'s group set to `deploy-vps1-admin` | positive exit 0; negative exit 1 with `::error::.github/workflows/admin.yml:deploy uses vps1-sync in group 'deploy-vps1-admin'` |
| release job's mirror read | the new step's `jq` and `.firebaserc` lines under `set -euo pipefail`, in a scratch folder holding only `web_release/release.json` and `infra/firebase/.firebaserc` | exit 0: `mirror=https://app.…sslip.io origin=https://madar-sat.web.app`. An empty `.mirror` fails with `::error::` (exit 1) |
| hosts and Actions | — | NOT RUN: nothing ran on VPS-1 or in GitHub Actions |

## Previous round
| Finding | Now |
| --- | --- |
| B2-R1-1 the release job read a missing `app/env/prod.json` (HIGH) | **fixed**: it reads `.mirror` from the artifact's `web_release/release.json`, which `stage_web_release.sh:134` writes and the `build` job uploads (`pwa.yml:117`). The `https://` check stays, and the `Origin` comes from `infra/firebase/.firebaserc` (`madar-sat`) |
| B2-R1-2 the merge broke the admin until a bootstrap re-run (HIGH) | **fixed**: `deploy.sh` `check_admin_current` (a symlink with an `index.html` behind it; `bootstrap-vps.sh:208-210` installs one) stops every VPS-1 deploy and names the bootstrap. `admin.yml`'s `readlink` fails with an `::error::` naming the same command. The re-run is first in owner-actions D4 B2 "Before merge" and step 17 of the README setup order, and `infra.yml` tests both cases |
| B2-R1-3 VPS-1 jobs outside `deploy-vps1`, re-syncing `infra/` (HIGH) | **fixed** as asked: `admin.yml` `deploy` and `pwa.yml` `release` are in `deploy-vps1` and pass `sync-infra: "false"`, a tag that isn't an ancestor of `origin/master` is refused (`fetch-depth: 0`), `infra.yml` enforces the group, and `deploy-and-rollback.md:36` says so. The shared group has a side effect: see B2-R2-1 |
| B2-R1-4 holes in the admin deploy's rollback | still open (`admin.yml` has no `trap`, `curl` no `--max-time`) |
| B2-R1-5 FR-010 / SC-003 not met yet | still open (needs a clean 48 h window) |
| B2-R1-6 two commits outside lane tasks | still open |
| B2-R1-7 the report's "unmatched" column | still open |
| B2-R1-8 the live deploy drops the previous release; `**` rewrite | still open |
| B2-R1-9 on-call and PWA runbook commands | still open |
| B2-R1-10 `scrape-home` monitor stays down offline | still open |
| B2-R1-11 T042 and T046 open | still open: `admin.yml` has no Playwright step and `app.yml` no `node --test app/test_web/`. This matters more now: the new guard tests (Lane A) and the classic-worker and bootstrap tests (Lane M) run nowhere in CI |
| LOW (8) | still open |

## Findings
### MEDIUM
#### B2-R2-1: One shared `deploy-vps1` group cancels a waiting admin deploy or PWA release
- CI · constitution IX, FR-015, FR-020 · `.github/workflows/admin.yml:72`, `.github/workflows/pwa.yml:161`, `docs/runbooks/deploy-and-rollback.md:36` · CONFIRMED (GitHub's documented concurrency rule, which the runbook itself states)
- Problem: in a concurrency group, GitHub keeps one running job and one pending job. A newer job that queues cancels the pending one, even with `cancel-in-progress: false`. That was harmless while the group held only `backend.yml` `deploy` and `infra.yml` `sync`, which both sync `infra/` and run `deploy.sh`. The admin deploy and the PWA release ship different things, so they can't stand in for each other.
- Failure scenario: a merge touches `infra/` and `admin/`. `infra.yml` `sync` runs and `admin.yml` `deploy` waits. Then the `backend.yml` deploy (or a `web-v*` release) queues, and the waiting admin deploy is cancelled before it starts. The admin site keeps the old bundle and the run shows "cancelled", not "failed". The same can drop a tagged release. Nothing breaks on the host, but the change silently isn't deployed. The runbook's "the newest commit wins" is no longer true across job kinds.
- Fix direction: keep the jobs from overlapping without letting one cancel another. For example, give `admin.yml` and the PWA release a second CI WireGuard peer and their own groups, since they only copy files and `deploy.sh`'s lock covers the rest. Or have each job retry when it is cancelled while pending. Then correct the runbook sentence. A new peer is an owner item.

## Requirements
| Requirement | Built in | Proven by | Status |
| --- | --- | --- | --- |
| US3 AC6 / FR-015 | `pwa.yml` `release` | mirror-read reproduction; actionlint | the round-1 blocker is gone; the live run is T048's. B2-R1-8 is still open |
| FR-020 (B2's half) | `admin.yml` `deploy`, `deploy.sh` check, bootstrap | the `infra.yml` check reproduced | met in config; B2-R1-4 and B2-R2-1 are open |
| US3 AC1–5, AC7, FR-016 | as in round 1 | as in round 1 | unchanged |

## Task audit
Ticked 18 (15 from round 1 plus B2-R1-1 … 3), verified 16, not done 0, partly done 2 (T040 still has B2-R1-4's rollback holes; T045 still has B2-R1-8).

## Owner must review
- `.github/workflows/pwa.yml` `release` and `admin.yml` `deploy`: their shared group (B2-R2-1), the ancestor check, and what they write on VPS-1.
- `infra/scripts/deploy.sh` `check_admin_current`: from this merge on, every VPS-1 deploy stops until the bootstrap has been re-run. Do the owner-actions "Before merge" item first.

## Outside this change
- The other lanes' fixes in the same working tree.

## Not reviewed
- No run on VPS-1, in GitHub Actions or against the real mirror. The release job's `curl` header checks and the admin deploy's swap were read, not run.
