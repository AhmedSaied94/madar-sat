# Implementation review: 003-d03-follow-push-sources, lane B2, round 2

- Date: 2026-11-01 · Reviewer: Claude Code (Opus 5.5 lead; Sonnet code-reviewer subagent; every CRITICAL/HIGH re-read by the lead)
- Branch: 003-d03-follow-push-sources (all four lanes' round-1 fixes merged; no lane branch checked out, as in round 1) · Base: master (merge base 5323669) · Head: 5cd804f, plus 0 uncommitted files
- Change: 31 commits, 485 files in all (33 lane B2), +54040 −957. Round-1 fix commits: 28b0944, 667dbd3
- Verdict: **CHANGES REQUESTED** · CRITICAL 0 · HIGH 2 · MEDIUM 3 new (plus 13 open from round 1) · LOW 6 new (plus 10 open from round 1)

## Checks
| Check | Command | Result |
| --- | --- | --- |
| ruff, mypy | `cd backend && uv run ruff check .`; `MYPYPATH=$PWD uv run mypy --strict --explicit-package-bases app` | exit 0, exit 0 |
| pytest (adapters) | the whole backend run (see b1-round-2.md) | all `tests/adapters` pass except the 4 `test_homebox_acl.py` (environment, as in round 1); `livesoccertv.py` 87 %, `livesoccertv_links.py` 97 %, total 95.10 % |
| Backup image end to end (subagent) | built `infra/backup/Dockerfile`, ran `backup-db.sh`, `backup-media.sh`, `backup-media.sh --weekly` as `10001:10001`, `--cap-drop ALL`, against Postgres 16, a local restic repo and an rclone `local` remote | exit 0 ×3: repo initialised on first run, dump written, mirror written, retention "keep 1 snapshots" |
| Backup services render as the timers start them | `docker compose --dry-run … --profile backup run --rm -T backup-db` (and the media ones) with no `IMAGE_TAG` | resolve to `madar-backup:stable` and start |
| Retention drill | `infra/scripts/check-backup-retention.sh` against restic 0.14.0 | passes |
| shellcheck, systemd-analyze, caddy validate, doc commands | `shellcheck` (v0.11.0), `systemd-analyze verify` on the 6 units, `caddy validate`, `check-doc-commands.sh` | clean / clean / OK / OK |
| Media CORS probe | throwaway Caddy 2.11.7 with `infra/caddy/Caddyfile` | reflects only the project's `web.app`/`firebaseapp.com` (and preview channels); nothing for `evil.example`, look-alike hosts or `http://` |
| `infra/scripts/check-backup-permissions.sh` | — | NOT RUN: blocked by the local lean-ctx allowlist; the image run above covers the same permission model |
| On a host (B2, OCI, Kuma, Telegram) | — | NOT RUN: needs the owner's secrets and a deployed host (T081–T086) |
| Ways around the checks | diff scan of 28b0944, 667dbd3 | none: only added CI steps; the rollback drill's two stubs became one `require_host_setup` stub; secrets scan clean |

## Previous round
| Finding | Now |
| --- | --- |
| B2-R1-1 timers cannot start containers | fixed: `vps2.yml:125`, `vps1.yml:161` (`madar-backup:${BACKUP_IMAGE_TAG:-stable}`), `${IMAGE_TAG:-none}`, `deploy.sh:325,381` pull; rendered without `IMAGE_TAG` in CI |
| B2-R1-2 staging/media permissions | fixed: `user: "10001:10001"`, `cap_drop: [ALL]`, `bootstrap-vps.sh:202`, `deploy.sh:208`; real-image run passes |
| B2-R1-3 retention never prunes | fixed: fixed dump path, `--host` on backup and forget; drill passes |
| B2-R1-4 `deploy.sh` root-only work | fixed: deploy only verifies (`check_dirs`, `check_timers`, `require_host_setup`); bootstrap installs. Test gap is MEDIUM B2-R2-5 |
| B2-R1-5 restic repo never initialised | fixed: `cat config \|\| init` in both scripts; confirmed on an empty repo |
| B2-R1-6 media CORS `*` | fixed: `Caddyfile:41-51` reflects the PWA origins only, `Vary: Origin`; CI asserts it |
| B2-R1-7 FCM key steps contradict | fixed for the install (one `install -o 10001 -g 10001 -m 600` everywhere, CI-enforced); the verify/restart commands are MEDIUM B2-R2-4 |
| B2-R1-8 `pick_match` accents/apostrophes/prefixes | fixed: `livesoccertv.py:68-114,428-445`; same Cairo day + unordered pair on both branches; ~20 probed pairs show no cross-club collision. Slug branch untested on its own (LOW) |
| Round-1 MEDIUM "Kuma URLs in the runbook" | regraded to HIGH as B2-R2-1 |
| Round-1 MEDIUM "backups.md commands" | partly fixed; what remains is HIGH B2-R2-2 |
| Other round-1 MEDIUMs | still open: ingest crash never reaches the breaker (`tasks.py:392,412-426`); manual run on a paused source; per-match miss counted as source failure; `alerts.py:43` catches only `httpx.HTTPError`; empty channel list wipes links; no card-sharing label screen (`livesoccertv.py:419`); ambiguous Arabic names pick the first row; 12-target cap; Kuma gets the whole `.env` and a floating tag; rclone sync guard checks only `-d`; no `RESTIC_PASSWORD` escrow; new `# type: ignore` at `tasks.py:385`; weak by-country test |
| Round-1 LOWs | `.env` table fixed; leftover dump reduced to one file; the rest still open (`ssh -J ubuntu@…` in `uptime-kuma.md`, `imports-and-sources.md`, `push-notifications.md:32-33`; `User=root` units; stale comments; …) |

## Findings
### CRITICAL
None.

### HIGH
#### B2-R2-1: The Kuma push URLs the runbook produces cannot be reached, and a failed backup reports `up`
- Layer ops · Source FR-025, SC-004, T084 and T086, constitution VII, `contracts/pipelines-and-ops.md:90` · Location `docs/runbooks/uptime-kuma.md:10,21-22,47-48`; `infra/backup/backup-db.sh:45`, `infra/backup/backup-media.sh:49` · CONFIRMED
- Problem: (a) the runbook sets Kuma's primary base URL to `https://kuma.10-8-0-1.sslip.io` (VPS-1's wg0, Caddy internal CA) and says to copy each monitor's push URL into `.env`; VPS-2 is not a WireGuard peer, and the backup image's curl does not trust the internal CA, while the contract expects `http://uptime-kuma:3001/…` on VPS-2 and `http://<VPS2_VCN_IP>:3001/…` on VPS-1. (b) Kuma shows push URLs as `…/api/push/<token>?status=up&msg=OK&ping=`; the scripts append `?status=${status}&msg=…`, so a `down` push becomes `…?status=up&msg=OK&ping=?status=down&msg=…`, whose `status` is `up`.
- Failure scenario: following T086 literally, every heartbeat monitor is red from day one (a); once the host is corrected by hand, a backup that fails every night still pushes `up` and the 25 h silence alarm never fires (b). SC-004's failure notice never reaches Telegram.
- Fix direction: strip any query from the configured URL in both scripts (`${url%%\?*}`) before appending `status`/`msg`; document the exact per-host form (`http://uptime-kuma:3001/api/push/<token>` on VPS-2, `http://<VPS2_VCN_IP>:3001/api/push/<token>` on VPS-1) and that only the path is copied from Kuma; add a CI check that runs a script against a local HTTP stub and asserts the received `status=down`.

#### B2-R2-2: Three `backups.md` commands fail or mislead, including the SC-004 morning check
- Layer ops · Source T085 ("every command must match"), T083, quickstart step 6, root `CLAUDE.md` runbook rule · Location `docs/runbooks/backups.md:50`, `docs/owner-actions.md:335`, `specs/003-d03-follow-push-sources/quickstart.md:53` (`--last 3`); `docs/runbooks/backups.md:133-135` (rclone into a `:ro` mount, `infra/compose/vps1.yml:176`); `docs/runbooks/backups.md:143-149` (snapshot restore then `sudo -iu deploy cp`) · CONFIRMED
- Problem: (C1) the image installs Debian bookworm's restic 0.14, where `--last` is a deprecated boolean, so `3` is taken as a snapshot id: reproduced in the built image as `Ignoring "3": no matching ID found` and an empty list with exit 0, while `--latest 3` lists the snapshot. (C2) the one-file media restore writes into `/srv/media`, mounted read-only in `backup-media`: `read-only file system`, exit 1. (C3) the snapshot restore leaves files owned by 10001 with mode 0600, which `deploy` can neither read nor copy into the 10001-owned `/srv/media/logos`.
- Failure scenario: the owner's "did last night's backup run?" check (T083, SC-004) prints nothing although the backup ran; a lost logo cannot be restored with either documented path.
- Fix direction: use `--latest 3` in all three places; restore media through a one-off `docker run --user 10001:10001 -v /srv/media:/srv/media` (read-write) or into scratch then `sudo install -o 10001 -g 10001`; have CI run these runbook commands in the real image (the retention drill already builds it).

### MEDIUM
- **B2-R2-3 Nothing guarantees the backup image is on a host before the first 03:00 run.** `deploy.sh:325,381` pulls `madar-backup:stable` only during a backend deploy (warning if absent); `infra.yml`'s build runs independently and `--infra-only` does not pull. A first merge whose deploy runs before `stable` exists leaves no image; the timer's unauthenticated pull of a private GHCR package fails: no dump, no heartbeat. Order the jobs, pull in `--infra-only`, or add an owner-action line.
- **B2-R2-4 The FCM verify/restart commands do not run on VPS-2 as written.** `push-notifications.md:44,60-61,66`, `secrets.md:220`, `owner-actions.md:326`: bare `docker compose exec worker-notify …` has no `-f`/`--env-file`/`--profile`, and `dc` is defined only for VPS-1 (`deploy-and-rollback.md:49`). Use the full `sudo -iu deploy docker compose --env-file /srv/madar/.env -f /srv/madar/infra/compose/vps2.yml --profile workers …` form and update the literal `check-doc-commands.sh` pins.
- **B2-R2-5 `check_timers` and `install_timers` have no behavioural test, and unit drift blocks rollbacks.** `deploy.sh:47` says CI drives `MADAR_UNITS_DIR`; nothing does. `check_timers` (`deploy.sh:221-237`) `cmp`s repo units against `/etc/systemd/system` and dies on any difference, so any later unit change on master blocks every deploy, including an emergency rollback, until a root bootstrap. Test both with a stub `systemctl`; consider warning on drift.

### LOW
- L1 `pick_match`'s slug-pair branch is never the deciding branch in a test, and the `-v-` separator is untested.
- L2 Stale text: `plan.md:147` (deploy installs timers), `deploy.sh:26-27` header, the `backup-db.service` "/bin/bash" comment, T076/T078 wording.
- L3 restic lock contention between nightly `forget --prune` and the Sunday media `backup` (no `--retry-lock` in 0.14).
- L4 system-design §3/§8 do not record the media site's CORS rule or its preview-channel allowance.
- L5 `Persistent=true` plus `Conflicts=` between the nightly and weekly media units can kill one at boot.
- L6 `backups.md` restore step 4 uses `dc` without defining it.

## Requirements
| Requirement | Built in | Proven by | Status |
| --- | --- | --- | --- |
| LiveSoccerTV channels per match (US3) | `adapters/livesoccertv.py`, `livesoccertv_links.py` | `test_livesoccertv_*` with saved pages | Built; accents/prefixes now matched |
| Source health, breaker, alerts (FR-024/025) | `adapters/health.py`, `alerts.py` | `test_health.py`, `test_alerts.py` | Built; ingest crash still bypasses the breaker (MEDIUM, open) |
| Heartbeats to Kuma (FR-025, SC-004) | `tasks.py` heartbeat, backup scripts | `test_heartbeat.py` (Celery only) | **Partial: backup heartbeats mask `down`, runbook URLs unreachable (B2-R2-1)** |
| Nightly backups, retention, restore (SC-004) | `infra/backup/*`, `vps1/2.yml`, timers | image run, retention drill | Built; **restore/check commands wrong (B2-R2-2)** |
| Media CORS (constitution V) | `Caddyfile:41-51` | CI assertion, probe | Built |

## Task audit
Ticked round-1 tasks 8, verified 8. Mismatch: T085 (backups runbook, "every command must match") is ticked while B2-R2-2's commands fail; T086 (Kuma monitors) ticked while B2-R2-1's URLs cannot work.

## Owner must review
- `infra/caddy/Caddyfile:41-51`: the media CORS origin pattern.
- `infra/backup/backup-db.sh`, `backup-media.sh`: what is pushed to B2 and OCI and how retention prunes.
- `docs/runbooks/backups.md`, `uptime-kuma.md`: the commands you will run by hand (see B2-R2-1, B2-R2-2).

## Outside this change
- `app-release.yml:67` passes only `--build-number`, so lane M's forced-update fix (M-R1-4) cannot be relied on until B2 passes `APP_BUILD_NUMBER` (tracked in `owner-actions.md:391`).

## Not reviewed
- Anything on a real host or against B2, OCI, Kuma or Telegram; `check-backup-permissions.sh` (allowlist).
