# Implementation review: 003-d03-follow-push-sources, lane B2, round 1

- Date: 2026-11-01 · Reviewer: Claude Sonnet 5.5 (lead) with three Sonnet 5.5 layer reviewers (pipelines, run twice; ops/infra/docs; spec/tests). Every HIGH below was re-opened by the lead; CONFIRMED means the lead saw it in the code or reproduced it. Nothing was executed on a host.
- Branch: 003-d03-follow-push-sources (all four lane PRs merged; no lane branch was checked out, at the owner's request) · Base: origin/master (merge base 5323669) · Head: 8405dd2, plus 0 uncommitted files
- Change: B2's commits `d97ccc0`, `88d4d44`, `7f429d1`, `d575c04`, `cd289a2` (PR #17); 30 files owned by B2 (+2,197 −75) per the scope script, plus the 26 `backend/tests/adapters/**` and `tests/fixtures/livesoccertv/**` files that the script files under B1 but tasks.md assigns to B2. None of B2's commits touch another lane's folders. The owner's own commit `d43cd86` (Caddyfile media CORS) sits in B2's folder and is reviewed here.
- Verdict: **CHANGES REQUESTED** · CRITICAL 0 · HIGH 8 · MEDIUM 17 · LOW 12

## Checks

| Check | Command | Result |
| --- | --- | --- |
| ruff, mypy | `cd backend && uv run ruff check .`; `MYPYPATH=$PWD uv run mypy --strict --explicit-package-bases app` | exit 0 and exit 0 (plain `mypy --strict app` fails on this machine because of a stray `/mnt/endeavour/home/saied-dev/__init__.py`; environment) |
| pytest (adapters) | `TEST_DATABASE_URL=postgresql://madar:changeme@localhost:5434/postgres TEST_REDIS_URL=redis://:changeme@localhost:6380/0 uv run pytest --cov` over the whole backend | all `tests/adapters` pass except 4 in `test_homebox_acl.py` (D2's; needs the ACL Redis CI starts, the dev Redis has `requirepass` only). `app/adapters` coverage 93 %: `livesoccertv.py` 87 %, `livesoccertv_links.py` 97 %, `health.py` 98 %, `tasks.py` 93 %, `alerts.py` 100 % (gate 70 %, one combined number over five packages) |
| Backup services render the way the timers start them | `env -u IMAGE_TAG MADAR_ENV_FILE=compose/example.env docker compose --env-file <example.env without IMAGE_TAG> -f compose/vps2.yml --profile backup config -q` (and `vps1.yml`) | reproduced B2-R1-1: `error while interpolating services.backup-db.image: required variable IMAGE_TAG is missing a value: set IMAGE_TAG` (and the same for `backup-media`) |
| `team_slug` on accented names | `uv run python -c "from app.adapters.livesoccertv import team_slug; …"` | reproduced B2-R1-8: `'Atlético Madrid' → 'atlético-madrid'`, `"Côte d'Ivoire" → 'côte-d-ivoire'`, `"FC Bayern München" → 'fc-bayern-münchen'` |
| `infra.yml` CI jobs (shellcheck, actionlint, `systemd-analyze verify`, `caddy validate`, compose `config` with `example.env`) | not run | NOT RUN: not run locally; CI runs them. restic, rclone and shellcheck are not installed on this machine, so no backup script was executed |
| Backups end to end on a host (restic to B2, rclone to OCI, Kuma heartbeat) | — | NOT RUN: needs the owner's secrets and a deployed host (tasks T081–T084) |

Ways around the checks: none found. No `skip`/`xfail`/`importorskip`, no lowered threshold, no change to ruff/mypy config; `.gitleaks.toml` (B1's file) gained a narrow allowlist (four exact paths and one literal, `AND`). One new production `# type: ignore[arg-type]` (MEDIUM, below); the two `lxml` ignores copy `ysscores.py`.

## Previous round

Round 1: none.

## Findings

### CRITICAL

None.

### HIGH

#### B2-R1-1: The nightly backup timers cannot start the backup containers
- Layer: ops · Source: FR-025, SC-004, T074/T075/T078, constitution IX · `infra/compose/vps2.yml:112`, `infra/compose/vps1.yml:153`, `infra/systemd/backup-db.service:17`, `infra/systemd/backup-media.service:11`, `infra/scripts/deploy.sh:330`, `.github/workflows/infra.yml:370,396-415` · CONFIRMED (reproduced with `docker compose config`)
- Problem: both backup services use `image: …/madar-backup:${IMAGE_TAG:?set IMAGE_TAG}`. The systemd units run `docker compose --env-file /srv/madar/.env … run --rm -T backup-*`, and `IMAGE_TAG` is "set by `deploy.sh`, not in the file" (`infra/README.md:91`). Even with a value set, `IMAGE_TAG` is the backend deploy SHA, while `madar-backup` is tagged by the `infra.yml` run SHA and `stable`, which no compose file references; `deploy.sh:330` pulls only `vps2_services`, so nothing ever pulls the backup image, and `deploy.sh` logs out of GHCR, so a pull when the timer fires is unauthenticated.
- Failure scenario: at 03:00 compose exits with "required variable IMAGE_TAG is missing". No dump is made and no `down` heartbeat is sent, so Kuma notices only after its 25 h window, which misses SC-004's 15 minutes. CI cannot catch it because it renders with `example.env`, which defines `IMAGE_TAG`. The runbook's "Run one by hand" and "Check last night" commands and quickstart step 6 fail the same way.
- Fix direction: give the backup services their own image variable (the moving `madar-backup:stable` tag CI already maintains), pull it in `deploy.sh` while logged in to GHCR (or make the package public), and add a CI step that renders compose without `IMAGE_TAG`. Task `B2-R1-1`.

#### B2-R1-2: The backup containers cannot write the staging directory or read the media
- Layer: ops · Source: SC-004, T073/T075 · `infra/compose/vps2.yml` (`backup-db`) and `infra/compose/vps1.yml` (`backup-media`): no `user:`, `cap_drop: [ALL]`; `infra/scripts/bootstrap-vps.sh` and `deploy.sh:176-180` create `/srv/backup` as `deploy:deploy` mode 700; `backend/app/media/store.py:32-36` writes media with `mkstemp` (mode 0600, owner uid 10001) · CONFIRMED by kernel permission rules (not executed)
- Problem: root inside a container without `CAP_DAC_OVERRIDE` is bound by the owner and mode bits.
- Failure scenario: `backup-db.sh:56` `pg_dump --file /srv/backup/…` gets EACCES; `rclone sync` and `restic backup` of `/srv/media` get "permission denied" on every file, so the media mirror exits non-zero every night. Caddy reads the same files only because it runs without `cap_drop`. The repo already hit this class of bug for `/srv/raw` (B2-R1-5 of an earlier round).
- Fix direction: run each backup container as the uid that owns its paths, or add only the capabilities it needs, and make the host directory ownership match. Task `B2-R1-2`.

#### B2-R1-3: The restic retention never deletes anything, so B2 grows without limit
- Layer: ops · Source: constitution IX (7 daily / 4 weekly / 6 monthly), FR-025, $0/month · `infra/backup/backup-db.sh:62-65`, `infra/backup/backup-media.sh:70-71` · CONFIRMED against the restic documentation (`forget` applies the policy per group of host and paths); not executed
- Problem: `restic backup` runs without `--host`, in a `run --rm` container with a random hostname, and the dump path changes every night (`madar-<UTC stamp>.dump`). `restic forget --keep-daily 7 …` therefore sees one snapshot per group and keeps every one. The media snapshots have the same random host.
- Failure scenario: every nightly full dump is kept for ever. Compressed `pg_dump -Fc` dedups poorly, so the 10 GB Backblaze free tier is passed within weeks; uploads then fail or Backblaze starts billing, which breaks constitution IX.
- Fix direction: pin `--host` on both `backup` and `forget`, give the dump a fixed path or use `--stdin-filename`, or `forget --group-by tags`; add a CI test that runs real restic against a local repository and checks that old snapshots are pruned. Task `B2-R1-3`.

#### B2-R1-4: `deploy.sh` does root-only work as the `deploy` user, so every deploy aborts
- Layer: ops · Source: T078, FR-027, constitution IX (deploy path) · `infra/scripts/deploy.sh:174-185` (`ensure_dirs`: `install -d -o 10001 -g 10001 /srv/secrets`, `/srv/backup`, `/srv/kuma`), `:188-202` (`install_timers`: `install … /etc/systemd/system/`, `systemctl daemon-reload`, `systemctl enable --now`), called at `:258,263,322-323,392,398`; header "as `deploy`"; `infra/scripts/bootstrap-vps.sh:91-96` creates `deploy` in the `docker` group only; no sudoers entry anywhere · CONFIRMED (code read)
- Problem: a non-root user cannot write `/etc/systemd/system`, reload systemd, or chown to another uid. CI runs the script over SSH as `deploy` (`backend.yml:325,367`, `infra.yml:443`).
- Failure scenario: under `set -Eeuo pipefail` the script exits at `install_timers vps1`, which runs before `alembic upgrade head` and the image pull. Every backend deploy, every `infra.yml` sync and every VPS-2 deploy fails, and the rollback goes through the same script. `infra.yml:268-269` stubs both functions in the rollback drill, so CI never ran them.
- Fix direction: do the privileged steps in `bootstrap-vps.sh` (root) and have `deploy.sh` only verify them, or add a narrow sudoers entry; update README step 11's "timers were installed by the deploy". Task `B2-R1-4`.

#### B2-R1-5: The restic repository is never initialised
- Layer: ops · Source: SC-004, T083, FR-055 · `infra/backup/backup-db.sh:62`, `infra/backup/backup-media.sh:70`, `docs/runbooks/backups.md`, `docs/owner-actions.md` · CONFIRMED (no `restic init` or init-if-missing anywhere in `infra/`, `docs/` or `specs/`)
- Problem: `restic backup` on an empty bucket fails with "unable to open config file". The owner action stops at putting the four variables in `.env`.
- Failure scenario: once B2-R1-1 to B2-R1-3 are fixed, the first night still goes red with no documented remedy.
- Fix direction: `restic cat config || restic init` in both scripts, or document `restic init` in `backups.md` and the owner action. Task `B2-R1-5`.

#### B2-R1-6: The media site answers `Access-Control-Allow-Origin: *`, against constitution V, with no recorded decision
- Layer: security/ops · Source: constitution V (NON-NEGOTIABLE): "Public CORS allows only the PWA's `web.app` and `firebaseapp.com` origins"; `docs/system-design.md:580` (the mirror allows the same origins for `GET`); governance ("fix the source, or amend the constitution in the same PR") · `infra/Caddyfile:43` (media site), `docs/runbooks/exposure-check.md`, commit `d43cd86` · CONFIRMED
- Problem: a separate `fix(infra)` commit added the wildcard with no D3 task and no decision in system-design §3. The sibling `app.` site (`Caddyfile:63-70`) correctly echoes only the two origins, for GET and HEAD.
- Failure scenario: any website can read media bytes cross-origin. The real exposure is nil (static, immutable, public files, no credentials, media site only), which is why this is graded HIGH and not CRITICAL; the letter of a NON-NEGOTIABLE rule is still broken, and the next reader of the constitution will not know it was meant.
- Fix direction: an owner decision. Either reflect the origin only when it matches `<project>(--<channel>-<hash>)?.web.app` or `firebaseapp.com` (with `Vary: Origin`, GET and HEAD), or amend constitution V and system-design §3/§8 to allow `*` for public media. Task `B2-R1-6` asks the owner.

#### B2-R1-7: The FCM key install steps contradict each other, and the owner-action version cannot run
- Layer: ops/security · Source: FR-012, research R9, T077, FR-055 · `docs/runbooks/push-notifications.md:34-36` (installs `/srv/secrets` and `fcm.json` as `deploy:deploy`), `docs/runbooks/secrets.md:22` (owner `deploy`) vs `:25,217` (uid 10001), `docs/owner-actions.md:325` (`sudo -iu deploy install … -o 10001 -g 10001`), `infra/compose/vps2.yml` (`worker-notify` runs as uid 10001 with `cap_drop: ALL`; `bootstrap-vps.sh` creates the directory as 10001:10001 mode 700) · CONFIRMED
- Problem: following `push-notifications.md` (which T047 links to) leaves a key that uid 10001 cannot read. `sudo -iu deploy install -o 10001` fails with EPERM because `deploy` is not root; only a root `install -o 10001 …` works.
- Failure scenario: the first real reminder (T047) fails with an FCM credentials or permission error.
- Fix direction: one correct command (root `install`), repeated identically in all places; remove the duplicate `secrets.md` row. Task `B2-R1-7`.

#### B2-R1-8: `pick_match` cannot match a team whose name has an accent, an apostrophe or a prefix, so no channels are added for it
- Layer: pipelines · Source: FR-020/FR-021, spec scenario 2, T054, constitution II · `backend/app/adapters/livesoccertv.py:61-66` (`team_slug`), `:379-389` (`pick_match` compares `team_slug(target.*_slug)` with `team_slug(row.home/away)`), `backend/app/domain/arabic.py:22-30` · CONFIRMED for the function (reproduced); the live row text is inferred from the saved pages
- Problem: one side is the mapping table's ASCII URL slug (`atletico-madrid`, `cote-divoire`, `bayern-munchen`, `fenerbahce-sk`), the other is the display name from the team page. `team_slug` only lower-cases and turns punctuation into spaces (`ar_normalize` does not fold Latin accents, and the two `.replace()` calls are dead code because `ar_normalize` has already turned `'` and `.` into spaces). The saved pages show LiveSoccerTV prints `Fenerbahçe SK`, `FC Bayern München`, `Atlético Madrid` and `Tala'ea El Gaish`, whose slugs are `fenerbahce-sk`, `bayern-munchen`, `atletico-madrid`.
- Failure scenario: a Madar match involving such a team passes planning, the team page is fetched, `pick_match` returns `None`, and the match is recorded `match_not_found`; it never gets channels. Each such run is also a zero-items failure toward the breaker (`health.py:121`), so a day of La Liga, Bundesliga, Turkish or Egyptian fixtures can pause the whole source. It is silent. `test_livesoccertv_match.py` uses only Al Ahly, Al Sekka and Pyramids, so nothing covers it.
- Fix direction: compare like with like: fold accents (NFKD), drop apostrophes and periods and common prefixes/suffixes on both sides, or compare the match link's own URL slug pair (`/match/<a>-vs-<b>/id`) with the mapping slugs; add a fixture or test with an accented and an apostrophe name. Task `B2-R1-8`.

### MEDIUM

- **An ingest crash never reaches the breaker** (FR-023 "N consecutive failed runs", constitution VII): `tasks.py:412-426` marks the run failed and re-raises, but `health.record_run` is called only on the success path (`tasks.py:392`). A persistent ingest exception (placeholder insert, an audit CHECK) gives endless `import_runs.failed` with no breaker and no alert; no test covers it (`test_a_failed_fetch_still_counts_toward_the_breaker` monkeypatches `record_run`). `failed.error` can also carry SQLAlchemy statement text into `import_runs.error`. CONFIRMED.
- **A manual run on a paused source fetches, then discards the data, and is recorded as a success** (research R17 "manual ignores pause"): `schedule_fetch` skips the pause check for a manual run (`tasks.py:630-634`) but ingest re-checks it (`:375-377`) and `record_run` then sees `items_found > 0` (`health.py:143-144`). A13 shows a recent success on a source that did nothing; `consecutive_failures` resets while `breaker_opened_at` stays set. Resume is fine. CONFIRMED by reading.
- **A per-match miss counts as a source failure and can open the breaker** (`tasks.py:470-473`, `health.py:121`): a run where every planned target ends `match_not_found` has `items=[]` and `targets>0`, so it is a "zero-items failure". Three evening passes for fixtures LiveSoccerTV does not list pause the source for everything. Together with B2-R1-8 this is likely. CONFIRMED by reading; needs an owner decision.
- **The alert path can still break a run** (R17 "errors logged, never raised"): `alerts.py:43` catches only `httpx.HTTPError`; `httpx.InvalidURL` is not a subclass, so `TELEGRAM_BOT_TOKEN` with a trailing newline in `.env` makes `send_alert` raise (reproduced), `record_run` propagates it into ingest's `except Exception`, and the run is marked failed exactly when the breaker opens. Alerts are also sent before the commit (`health.py:135/141`). CONFIRMED by reproduction. Catch `Exception` in `send_alert`; send after commit.
- **An empty channel list removes every livesoccertv link of that match** (FR-021, constitution II): `parse_broadcasts` returns `[]` when the marker element exists but no `table.ichannels` row parses (`livesoccertv.py:325-349`), and the reconciler deletes every own row not in `wanted` (`livesoccertv_links.py:221-233`). A bot or consent variant of the page that keeps the marker but not the table wipes the match's links until the next good run. PLAUSIBLE.
- **No card-sharing label screen on the LiveSoccerTV path** (backend/CLAUDE.md content rule): `_valid_channel_name` checks length and URL only, and the name goes into `channels.name`. Placeholders are hidden from `/v1` and an editor's save screens the text, so the reach is gated. PLAUSIBLE.
- **Ambiguous Arabic team names resolve to an arbitrary first row** (R14/R15 "no guessing", constitution II): `livesoccertv.py:449-459` keeps the first row of `by_name` with no `ORDER BY`, and `_mapping_for` falls back to it for names whose `team_id` is NULL (`etl/reference.py:261-262`), which are exactly the ambiguous ones (الأهلي). `pick_match` then needs both teams, so a wrong link is practically impossible, but the club with the largest audience is permanently `match_not_found`. Code CONFIRMED; data effect PLAUSIBLE.
- **The 12-target cap and the 30-minute plan mark starve later matches** (FR-022, SC-003): `plan_targets` takes the soonest 12 (`livesoccertv.py:52,475`); the "already planned" mark lasts 30 min (`:49`) while the cadence is 2 h, so every pass re-plans the same 12; the mark is also written at plan time (`:488`), so a skipped or failed fetch leaves the match unplanned for 30 min, and the T−60 window is 15 min wide. CONFIRMED by logic.
- **`backups.md` commands do not match the code** (T085, CLAUDE.md rule): `run --rm backup-media rclone lsd oci:` passes `rclone` as `$1` to an entrypoint script that rejects it (`backup-media.sh:17-23`); the DB restore writes to `/restore` in a `--rm` container then lists `/srv/backup/restore/…`; the media restore copies into `/srv/media`, mounted `:ro`; step 3 loads a dump from VPS-2's `/srv/backup` on VPS-1 before the scp step; `sudo -iu deploy env $(sudo cat /srv/madar/.env | xargs) docker compose …` puts every secret in argv and breaks on values with spaces. CONFIRMED.
- **Kuma receives every host secret** (`vps2.yml` `uptime-kuma` uses `<<: *service`, so `env_file: /srv/madar/.env` puts DB, Redis, restic, B2, Telegram and JWT secrets into `louislam/uptime-kuma:1`, a floating tag re-pulled on each deploy). T077 limits only the FCM mount. CONFIRMED. Also, `uptime-kuma` is in `vps2_services` (`deploy.sh:57`), so a slow or unhealthy Kuma within 90 s rolls back healthy workers (PLAUSIBLE).
- **Kuma URLs in the runbook:** `uptime-kuma.md` §1.3 sets the Primary Base URL to the wg0-only HTTPS name, §4 says to copy each push URL into `.env`, but the contract expects `http://uptime-kuma:3001/...` on VPS-2 and `http://<VPS2_VCN_IP>:3001/...` on VPS-1 (a literal copy is unreachable from VPS-2); the scripts append `?status=…` to a URL that already ends in `?status=up&msg=OK&ping=`, so a doubled query could report `up` for a failed backup (PLAUSIBLE); the `127.0.0.1:3001` check does not reach a Kuma published on `${VCN_IP}:3001` only.
- **`rclone sync` guard** (`backup-media.sh:57`): only `-d /srv/media` is checked, so an empty or unmounted media directory makes the nightly sync delete the whole OCI mirror. Add `--max-delete` or a non-empty check.
- **No escrow for `RESTIC_PASSWORD`**: it lives only in the host `.env` files; losing both hosts makes the backups unreadable, and no doc says to keep a copy.
- **Missing owner step:** the Kuma 3001 DROP rule in `vps2.rules` and the `/srv/{backup,kuma,secrets}` directories on a pre-D3 host exist only after `bootstrap-vps.sh vps2` is re-run; `deploy-and-rollback.md:230` says firewall changes are bootstrap-only, and README step 11 claims "the directories exist since bootstrap".
- **New `# type: ignore[arg-type]` in production code** (`tasks.py:385`; absent at the base): it comes from widening `ScrapeResult.items` to `ParsedFixture | BroadcastItem`, guarded at runtime by `_items_match_the_kind`. Narrowing with `isinstance` removes it. Graded MEDIUM, not a way around the checks: it is one specific code, no gate changed.
- **The by-country channel rule has no discriminating test** (FR-021, T055): changing `candidates = matched or with_country` to `with_country` (`livesoccertv_links.py:155`) fails no test; `test_a_listed_country_picks_the_country_variant` has a fallback half and a single-variant half.
- **Weak tests:** the parser purity test only parses twice and compares (its last assertion is unrelated); `test_a_run_for_an_unknown_source…` uses the seeded `livesoccertv`; `paused_until` in the future is never asserted (T058); `test_health.py:110-115` sets `SOURCE_BREAKER_THRESHOLD=10` and calls `cache_clear()` before but not after; the helpers' match URL is `/matches/…` while the real one is `/match/…`, so `adapter.parse()` dispatch is untested.

### LOW

- Scheme is not enforced by the fetcher: `fetcher.py:209-215` compares only the hostname and `_absolute` passes any href starting with `http`, so `http://www.livesoccertv.com/…` from page content is fetched in clear. Require `https` in `_check_host`.
- Retries are tight for a host that blocks: `base.py:19-23` backs off from 1 s for 5 tries (about 31 s) and `fetcher.py:180-181` ignores `Retry-After`; each retry restarts from target 1.
- The systemd units run as `User=root` with no hardening and no `OnFailure=`; the weekly unit's `Conflicts=backup-media.service` stops a nightly mirror still running at Sunday 04:00 and leaves its heartbeat unsent.
- A failed backup leaves its partial dump in staging (`rm -f "$dump"` runs only on success); repeated failures fill the disk.
- The backup containers load the whole `.env` (JWT secret, Redis and DB passwords) through `env_file`.
- The B2 size estimate in `backups.md` ignores the weekly media snapshot that shares the same 10 GB.
- Stale text: `vps2.yml` header says `worker-notify` is not started on D2 and the Kuma comment says `https://10.8.0.1/kuma/` (Kuma is served at `kuma.10-8-0-1.sslip.io`); `vps2.rules` header lists only `${PEER_VCN_IP}`; ticked T076/T086, research R20 and `plan.md:146` still say `/kuma/`; the `infra/README.md` host `.env` table omits the D3 variables; `infra/CLAUDE.md` has no backup or Kuma notes.
- The new runbooks use `ssh -J ubuntu@10.8.0.1 ubuntu@$VPS2_VCN_IP` where the project rule is the `madar-vps1` / `madar-vps2` aliases.
- The contract says `version: 2` but the wire field is `schema` (`messages.py:102`).
- `health.bump_datasets` (`health.py:70`) is a sync copy of B1's async writer; T065 said "through B1's `bump_datasets`". It can drift.
- `lstv:plan:last` is one Redis key, so a run's compact log can show another pass's plan; `_redis()` (`livesoccertv.py:511-517`) builds a client per call and never closes it.
- Formatting-only edits to `base.py` and `satair_bridge.py` came from B1's commit (FR-051, harmless).

## Requirements

| Requirement | Built in | Proven by | Status |
| --- | --- | --- | --- |
| AS1 / FR-020 pure `parse`, `LayoutChanged` | `livesoccertv.py:292-349` | `test_livesoccertv_parse.py` (7 tests, saved real pages) | Built (purity test weak) |
| FR-020 MENA country list, configurable | `config.py:21-48,88-91,108-116` | explicit lists in link tests only | Built, partial test |
| AS2 / FR-021 link, placeholder, reuse, own links only, editor-hidden stays hidden | `livesoccertv_links.py:110-248` | `test_livesoccertv_links.py` (10 tests) | Built; by-country pick untested; **team matching fails for accented names (B2-R1-8)** |
| AS3 / FR-022 beat 48 h + T−60, queue | `schedule.py:23-77`, `tasks.py:619-661` | `test_schedule_fetch` | Built; 48 h coverage partial (12 cap) |
| AS4 / FR-023 breaker, threshold, alert once | `health.py:94-162` | `test_health` | Built; ingest-crash gap |
| AS5 / FR-024 zero-items alarm once per Cairo day | `health.py:121,137-141` | `test_health` | Built |
| T056 ScrapeResult v2 | `messages.py:29-236` | `test_messages_v2.py` | Built |
| T059 alerts and heartbeats | `alerts.py`, `tasks.py:664-683` | `test_alerts`, `test_heartbeat` | Built (alert path can raise, MEDIUM) |
| T060 compact log ≤ 64 KB | `tasks.py:532-606` | `test_ingest_log` | Built |
| AS6 / FR-025 03:00 DB, 03:30 media, retention, heartbeats | `infra/backup/*.sh`, `infra/systemd/*` | CI static checks only | **Broken in practice (B2-R1-1, -2, -3, -5)** |
| AS7 / FR-026 Kuma on VPS-2, wg0 only | `vps2.yml`, `Caddyfile:99-117`, `vps2.rules:33-35` | CI `check-firewall` | Built (secret scope, MEDIUM) |
| AS8 / FR-052 no secrets committed | `example.env`, fixtures | grep of the 6 fixtures: no script, cookie, csrf, token, email or IP | Built |
| FR-027 CI deploys timers and image | `deploy.sh`, `infra.yml` | rollback drill stubs them | **Broken (B2-R1-1, B2-R1-4)** |
| SC-003 second run adds none | `_reconcile_links` | `test_the_same_placeholder_is_reused…` | Built |
| SC-004 nightly backup in B2 | — | T083 open | Not proven; blocked by B2-R1-1, -2, -5 |
| SC-005 breaker plus alert | `health.py` | `test_health` | Built (live alert unproven) |

## Task audit

Ticked 34 (T050–T080, T085–T087), verified 29, not done 0, partly done 5.

| Task | Mismatch |
| --- | --- |
| T074, T075, T078 `[x]` | Backup image/tag, container permissions and the deploy's timer install do not work as built (B2-R1-1, -2, -4). |
| T073 `[x]` | Retention flags are right, but the grouping makes them inert (B2-R1-3); no `restic init` (B2-R1-5). |
| T077 `[x]` | The FCM mount is right; the install steps in the docs contradict each other (B2-R1-7). |
| T054 `[x]` | `pick_match` fails on accented, apostrophe and prefixed names (B2-R1-8). |
| T058, T055, T065 `[x]` | `paused_until` not asserted; by-country rule not discriminated; `health.bump_datasets` duplicates B1's writer instead of calling it. |
| T076, T086 `[x]` | Still describe the `/kuma/` path; Kuma moved to its own wg0 site. |
| T081–T084 `[ ]` | Genuinely open: need a deploy, the owner's secrets and the next morning's check. |

## Owner must review

- `infra/scripts/deploy.sh` and `infra/scripts/bootstrap-vps.sh`: they change how the hosts are deployed and who owns what (B2-R1-4).
- `infra/Caddyfile:43` (media CORS, B2-R1-6) and the Kuma site `bind 10.8.0.1`; `infra/firewall/vps2.rules`.
- `infra/backup/backup-db.sh`, `backup-media.sh`, `infra/systemd/*`, and the secret handling in `infra/compose/vps2.yml` (`worker-notify` mount, Kuma `env_file`).
- `backend/app/adapters/alerts.py`, `health.py` and `tasks.py` (breaker and alert rules; the three owner decisions flagged in MEDIUM).
- `.gitleaks.toml` allowlist (narrow, B1's commit).

## Outside this change

- `tests/adapters/test_homebox_acl.py` (D2) needs a Redis started with the home-box ACL; it cannot pass against the dev Redis. Test defaults in `backend/tests/conftest.py` do not match `infra/compose/dev.yml`.
- `/mnt/endeavour/home/saied-dev/__init__.py` (outside the repo) breaks `mypy` package detection from this checkout path.
- `files-b2` attribution: the scope script files `backend/tests/adapters/**` and the LiveSoccerTV fixtures under B1; tasks.md assigns them to B2.

## Not reviewed

- Nothing was run on a host; `restic`, `rclone`, `shellcheck`, `caddy` and `systemd-analyze` were not run. GHCR package visibility and OCI S3 settings for rclone were not verified.
- The live LiveSoccerTV site and Telegram/Kuma behaviour; the exact row text of accented clubs on the live team pages.
- `test_messages_v2.py`, `test_livesoccertv_plan.py` and `test_schedule.py` line by line; B1's `/v1` placeholder hiding and the resume endpoint (reviewed in B1's round).
