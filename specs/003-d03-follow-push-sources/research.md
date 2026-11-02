# Research: D3 · Follow, push and sources

Phase 0 decisions for [plan.md](plan.md). Each has a decision, a rationale and the alternatives rejected. The spec's Technical Context had no open `NEEDS CLARIFICATION`; these resolve the design choices behind it. D1 and D2 decisions ([001 research](../001-d01-foundation/research.md), [002 research](../002-d02-core-flows/research.md)) still hold unless one below replaces them.

## Lane B1: devices, follows, notifications, cache, limits, admin additions

### R1. Device registration and the token

- **Decision:** `POST /v1/devices` takes `{install_id (uuid), platform}` and returns `{device_id, device_token}`. The token is `secrets.token_bytes(32)`, encoded base64url (43 characters); the server stores `sha256(token)` hex in `devices.token_hash`. Registering an install id that exists rotates its token in place (same `device_id`, follows kept), so a reinstall that kept its install id, or an app that lost its token, recovers without a second device row. The endpoint has its own limit: 30 per 10 min per IP.
- **Rationale:** SD §6.3.2 and constitution V: 256 server-generated bits, stored hashed. Lookup by the hash is an indexed equality on a value an attacker can't choose, so no timing channel exists; `hmac.compare_digest` is used where a hash is compared in memory.
- **Alternatives rejected:** a new device row per call (leaves orphan devices that keep receiving pushes); a JWT device token (needs a signing key and can't be revoked by deleting a row); refusing a known install id (an app that lost its secure storage would be stuck).
- **Risk accepted:** whoever knows an install id can rotate that device's token. The install id is a random UUIDv4 that never leaves the device except in this call, and a device holds only follows, so the impact is losing the follows mirror, which the app re-sends (P1).

### R2. Device authentication

- **Decision:** one dependency, `DeviceAuth`, parses `Authorization: Device <token>`, hashes it and loads the device. Missing, malformed or unknown → `401 unauthenticated` (no distinction, so nothing leaks). `last_seen_at` is updated at most once an hour per device. All `/v1/devices*` responses are `Cache-Control: no-store` and never go through the response cache (R10).
- **Alternatives rejected:** middleware (it would run on every public route, and only four need it).

### R3. My satellites on the server

- **Decision:** revision `0005` adds `devices.satellite_ids bigint[] NOT NULL DEFAULT '{}'`, set by `PUT /v1/devices/me` (≤ 32 ids, each an existing satellite, de-duplicated, order kept). The device stays the source of truth; the server copy only words notifications (spec Clarifications).
- **Alternatives rejected:** storing it inside `prefs` jsonb (no type or reference check, and the dispatcher would parse JSON per device); a join table (the set is tiny, replaced whole, and only read with the device row).

### R4. Notification preferences

- **Decision:** `prefs` jsonb holds `{"types": {"<type>": {"on": bool, "lead_min": 5|15|30|60}}}` for the seven SD §6.8 types, validated by a Pydantic model with SD §6.8's defaults filled on read. The dispatcher honours `on`. `lead_min` is stored and ignored until D8 (spec Assumptions); every reminder uses 15.
- **Alternatives rejected:** columns per type (seven types × two values, changing as types arrive); refusing `lead_min` until D8 (the app would need another contract change on D8).

### R5. Replacing the follow set

- **Decision:** `PUT /v1/devices/me/follows` takes `{teams, competitions, matches, channels, commentators}` (arrays of ids, ≤ 500 in total). In one transaction: lock the device row (`SELECT … FOR UPDATE`, which serializes two concurrent PUTs from the same device), check every id exists (one `SELECT id … WHERE id = ANY(:ids)` per kind; unknown ids → `422 unknown_follow_target` with `meta.unknown`), `DELETE` the device's follows, `INSERT` the new set. It returns the stored set. No ETag: the call is a full replacement, and the device's own set wins (P1).
- **Alternatives rejected:** add/remove endpoints (two devices of one user can't exist, and diffs drift; SD §6.3.2 says "replaces"); `ON CONFLICT` merging (doesn't remove unfollowed items).

### R6. The reminder scheduler

- **Decision:** a beat entry every 5 min runs `notifications.schedule_reminders` on the `notifications` queue (`worker-notify` on VPS-2). It selects matches with `kickoff_at` in `(now, now + 24 h]`, `time_tbd = false`, status `scheduled`, not soft-hidden, that have at least one follower (`EXISTS` over `device_follows` on home team, away team, competition or match). For each it upserts one outbox row:
  - `type = kickoff_reminder`, `dedupe_key = kickoff_reminder:<match_id>`;
  - `due_at = greatest(kickoff_at − 15 min, now)`;
  - `payload = {match_id, kickoff_at}`; `audience = {kind: "match_followers", match_id}`;
  - `INSERT … ON CONFLICT (dedupe_key) DO UPDATE SET due_at, payload WHERE notification_outbox.status = 'pending'`, so a moved kickoff moves a pending row and never touches a sent one.

  A second statement cancels pending reminders whose match became `time_tbd`, `postponed` or `cancelled`, or whose kickoff moved past 24 h. A match whose kickoff has passed is never scheduled. Admin saves and imports don't call the scheduler: the 5-minute cadence bounds the delay, and keeping it out of the write path leaves D2's writer unchanged.
- **Rationale:** SD §6.8 and constitution VII: producers only insert outbox rows, `dedupe_key` is unique, retries are harmless. One row per match (not per device) is what P1's `DISTINCT` audience needs.
- **Alternatives rejected:** a row per device (500× more rows, and dedupe moves into the app); a trigger on `matches` (logic in SQL, hard to test, fires on importer churn); Celery ETA tasks per match (lost on broker flush, can't be moved).

### R7. The dispatcher

- **Decision:** beat runs `notifications.dispatch_due` every minute on `notifications`; the scheduler also queues it when it creates a row due now.
  1. **Claim:** in a short transaction, `SELECT id … WHERE status = 'pending' AND due_at <= now() ORDER BY due_at FOR UPDATE SKIP LOCKED LIMIT 10`, then set `status = 'sending'`, `claimed_at = now()`, commit. Rows stuck in `sending` for more than 10 min (a dead worker) return to `pending`.
  2. **Audience, in pages:** one `SELECT DISTINCT d.id, d.push_token, d.satellite_ids, d.prefs FROM devices d JOIN device_follows f ON f.device_id = d.id WHERE d.push_token IS NOT NULL AND (f.team_id IN (:home, :away) OR f.competition_id = :competition OR f.match_id = :match) AND <type on> AND d.id > :cursor ORDER BY d.id LIMIT 500`. The owner reviews this query (brief).
  3. **Send:** build each device's message (R8) and send the page with `firebase_admin.messaging.send_each` (one HTTP call, ≤ 500 messages, each with its own body).
  4. **Record:** in one transaction per page: `sent += ok`, `failed += errors`, `cursor_device_id = last id`, and `UPDATE devices SET push_token = NULL` for tokens FCM answered `UNREGISTERED` (or `INVALID_ARGUMENT` on the token). After the last page: `status = 'sent'`, `sent_at = now()`. A row whose match was cancelled while queued is marked `cancelled` with no send.
  5. **Failures:** a whole-call failure (FCM 5xx, `UNAVAILABLE`, quota) raises `Retryable`; the task retries with backoff and resumes from `cursor_device_id`, so devices already sent to aren't sent again. After `max_retries`, the row is `failed`.
- **Rationale:** SD §6.8 and constitution VII name `SKIP LOCKED`, one `DISTINCT` audience, batches of 500 and `UNREGISTERED` cleanup. The cursor gives "never sends one row twice to a device" (FR-007) across retries. The one window left (a page sent but its commit lost) can repeat that page once; the `match_<id>` tag makes the repeat replace the first notification on the device instead of stacking.
- **Alternatives rejected:** `send_each_for_multicast` per group of identical bodies (several calls per page, and the bodies differ by satellite); a deliveries table (a row per device per notification, for a guarantee the cursor already gives); dispatching from the API process (no retries, and VPS-1 has no FCM credentials).
- **Spec note:** FR-007 words each device's message for its satellites; `send_each` takes the page's different messages in one call.

### R8. The kickoff reminder message

- **Decision:** built at send time in `app/notifications/messages.py`, from the match, its visible links and the device's `satellite_ids`:
  - **Channel:** the match's visible links (link not hidden, channel not deleted, not a placeholder, not on the hidden-names list, `show_in_match`), ranked by D1's `app.domain.ranking` with the device's satellites as "mine". If one is on the device's satellites, the best of those (free first); otherwise the best by the default set (Nilesat + Badr by slug, free first); with no visible link, no channel.
  - **Title:** «‹home› × ‹away› بعد ‹N› دقيقة», with `N` = minutes to kickoff at send time, rounded, at least 1 (so a late-created match says «بعد 7 دقائق» honestly). Arabic number agreement (دقيقة / دقيقتين / دقائق) from a small helper.
  - **Body:** «على ‹channel› · ‹satellite› — اضغط لعرض القنوات والترددات», or «اضغط لعرض القنوات والترددات» with no channel. Team, channel and satellite names are wrapped in FSI … PDI (U+2068 / U+2069) so Latin names stay islands (PB §11, §13.4, constitution III).
  - **FCM fields:** `notification {title, body}`; `android {collapse_key: match_<id>, notification {tag: match_<id>, channel_id: "reminders", icon: "ic_stat_madar"}}`; `webpush {notification {tag: match_<id>, icon, badge}, fcm_options {link: <pwa origin>/match/<id>}}`; `data {type, match_id, route: "/match/<id>"}`. The PWA origin comes from the backend setting `PWA_ORIGIN`.
- **Alternatives rejected:** copy in the app (the OS shows background pushes without running app code); a channel picked at scheduling time (stale when channels arrive in the last hour or the device changes satellites).

### R9. FCM credentials and the sender

- **Decision:** `firebase-admin` (named in SD §6.8), initialized once per worker from a service-account JSON at `FCM_CREDENTIALS_FILE` (`/srv/secrets/fcm.json`, mode 600, mounted read-only into `worker-notify` only). A `PushSender` protocol has the FCM implementation and a fake for tests; `FCM_DRY_RUN=true` uses FCM's `dry_run` for staging checks. No credential in the repo, CI or the image.
- **Alternatives rejected:** the legacy server key (shut down by Google); calling the HTTP v1 API by hand (OAuth token refresh and batching are what the SDK does).

### R10. The response cache

- **Decision:** D1's `ETag` dependency already computes a tag from the route, the canonical query and the dataset versions it depends on. The cache stores the serialized envelope under `rc:<etag>` in Redis, with the route's SD §6.3.2 TTL (60 s matches, 15 s live detail, 5 min channels and teams, 1 h competitions), skipping bodies over 512 KB. On a hit the body is returned as is; on a miss the route builds it and stores it. A Redis error falls through to the database (logged, never a 5xx). A write bumps a version, so the next read computes a new tag and misses: no key is ever deleted by scan (constitution VI).
- **Rationale:** the ETag is already the exact cache identity (route + normalized query + versions), so no second key scheme can drift from it.
- **Alternatives rejected:** a generic HTTP cache in Caddy (can't see dataset versions); caching ORM results (the serialization is a large part of the cost).

### R11. Rate limits on `/v1`

- **Decision:** a middleware on `app.public:app` only, using a Redis sliding window (two fixed one-minute buckets, weighted). It is keyed by the device token's hash **only when that hash belongs to a live device**, otherwise by client IP (D2's trusted `X-Forwarded-For` helper). Checking the hash uses a Redis cache of valid hashes (`dv:<hash>`, 10 min; unknown hashes cached as invalid for 60 s), filled by one indexed `devices.token_hash` lookup on a miss and cleared by the device service on rotate and delete. Keying by an unchecked header would let a client send a new random token on every request and get a fresh bucket each time, escaping the IP limit. The app sends its token on every `/v1` request ([R27](#r27-onboarding-state-device-registration-and-follow-sync)), so phones behind one carrier IP are counted apart. Limits, in settings: 120 requests per minute per device; 600 per minute per IP (CGNAT: many users behind one carrier IP, constitution V); `POST /v1/devices` 30 per 10 min per IP. `/healthz` is exempt. Over the limit: `429 rate_limited` with `Retry-After` and `meta.retry_after_s`. Redis down → allow (logged), so a cache outage never takes the API down.
- **Alternatives rejected:** Caddy rate limiting (a non-standard Caddy build, and no device key); a sorted-set exact window (more memory per key for no practical gain).

### R12. Admin additions

- **Decision** (spec Clarifications, FR-011; shapes in [contracts/admin-api.md](contracts/admin-api.md)):
  - `GET /admin/api/sources` gains health fields; `POST /sources/{name}/run`, `/pause`, `/resume`; `GET /sources/{name}/runs` (cursor) and `GET /import-runs/{id}`;
  - `GET /admin/api/dashboard`;
  - `PUT /admin/api/competitions/order` and `PUT /admin/api/satellites/order`, with each row's version in the body, like D2's bulk (one stale row rejects all);
  - `GET /admin/api/channels?placeholder=true`.
  
  «تشغيل الآن» sends `adapters.schedule_fetch` with `manual=true` through the Celery app (`send_task`, by name, so `api-admin` imports no adapter code). It is refused with `409 run_in_progress` while the source's fetch lock is held. A manual run ignores the pause and the breaker, and doesn't resume the source. **Resume** closes the breaker and also queues one manual run, so the editor sees at once whether the fix worked (spec US3 scenario 4) instead of waiting for the next beat slot.
- **ETags for source health:** `GET /sources` already carries `ETag("admin_sources", ("sources",))` from D2. Health changes after every run, so `health.record_run` (B2), pause and resume bump the `sources` dataset; no `/v1` route reads it, so the bump costs the public cache nothing. The dashboard's `ETag` uses `matches`, `channels` and `sources` with a 60 s bucket, because `recent_changes` comes from `audit_log`, which has no dataset version.
- **Alternatives rejected:** A13 polling the Flower API (not the contract, and Flower isn't on VPS-1); per-row PATCH for ordering (N requests, partial orders on a conflict).

### R13. Placeholders in the public API

- **Decision:** a channel with `placeholder_source IS NOT NULL` (R18) is excluded from every public read: match detail, satellite channels, channel detail and the S2 channel line. An editor's save that sets `show_in_match = true` on a placeholder clears `placeholder_source` in the same write, which makes it a normal channel.
- **Alternatives rejected:** relying on `show_in_match = false` alone (S5.2 and S6 list channels whatever `show_in_match` says).

## Lane B2: LiveSoccerTV, safety, backups, monitoring

### R14. LiveSoccerTV: plan, fetch, ingest

- **Decision:** the home box has no database, so the run is split in three, all through D2's message path:
  1. **Plan** (`adapters.schedule_fetch("livesoccertv")`, on `imports`, VPS-2): select Madar matches with kickoff in the next 48 h whose teams map through `livesoccertv_teams` (team id, else exact `ar_name_norm`), and build targets `{match_id, kickoff_at, home_slug, away_slug, country}`.
  2. **Fetch** (`adapters.fetch("livesoccertv", targets=…)`, on the LiveSoccerTV queue, `scrape_home` by default like ysscores): per target, the team page `https://www.livesoccertv.com/teams/<country>/<slug>/` finds the match link by date and opponent, then the match page gives the broadcasters by country, as `LVS.html` does (lines 1263–1300, 1513–1622). Pages are saved raw. `parse` is pure.
  3. **Ingest** (`adapters.ingest`, VPS-2): links by Madar `match_id` (R15).

  The `ScrapeResult` message gets version 2 with a `kind` (`fixtures` | `broadcasts`) and the broadcast items (`match_id`, `channels: [{name, country}]`); version 1 is still read (D2's rule: the current version and the one before).
- **Fetch rules:** host allowlist `www.livesoccertv.com` only, no redirects off it, 1 request per 4 s per host, the D2 size cap and timeouts, the configured `SCRAPE_USER_AGENT`. **The Cloudflare worker proxy `LVS.html` used is not ours and is not used.**
- **Schedule:** beat runs the plan every 2 h; a second entry every 10 min plans only matches with kickoff in 55–70 min that weren't fetched in the last 30 min (T−60, SD §6.6).
- **Alternatives rejected:** the schedule page `/schedules/<date>/` alone (it lists hundreds of matches, needs fuzzy team matching, and `LVS.html` falls back to team pages for accuracy); giving the home box database access (D2 limited it to Redis on purpose).

### R15. Matching LiveSoccerTV channels

- **Decision:** port `saveChannelsToMatch` (`LVS.html` lines 861–930), with Madar's normalization:
  - normalize each name with `ar_normalize` and lowercase, de-duplicate by name, except when a Madar channel with that name has a country, in which case each country entry is matched to the channel with that country (`countriesMatch`, `normalizeCountry`);
  - a match against any existing channel (`name_norm` or display name, not deleted) is linked **whatever country lists it**;
  - a name from a configured country (`LIVESOCCERTV_COUNTRIES`, default the MENA list) that matches nothing gets a placeholder (R18) and is linked;
  - other names are skipped and counted in the run.
  
  Links are written through D2's link rules: source `livesoccertv`, never touching `manual` links or other sources' links, removing only `livesoccertv` links the page no longer lists, and leaving editor-hidden links hidden (D2 FR-008).
- **Alternatives rejected:** fuzzy matching (constitution II: no guessing beyond documented rules).

### R16. The country list

- **Decision:** `LIVESOCCERTV_COUNTRIES` in VPS-2's `.env` (comma-separated, normalized by `normalizeCountry`), defaulting in `AdapterSettings` to: Egypt, Saudi Arabia, United Arab Emirates, Qatar, Kuwait, Bahrain, Oman, Jordan, Lebanon, Syria, Iraq, Palestine, Yemen, Libya, Tunisia, Algeria, Morocco, Mauritania, Sudan, Somalia, Djibouti, Comoros, and "Middle East", "MENA", "North Africa", "Arab World". Changing it needs a worker restart, not a release (spec Clarifications).
- **Alternatives rejected:** a database table with an admin screen (A13 has no place for it today; it can move later).

### R17. Source health: breaker and zero-items alarm

- **Decision:** after each ingest (and each fetch failure, which already sends a failed `ScrapeResult`), `app/adapters/health.py` updates the source row in the same transaction as `import_runs`:
  - a run with `status = failed`, or a zero-items run (below), increments `consecutive_failures`; a `succeeded` or `partial` run with items resets it to 0 and sets `last_success_at`;
  - when `consecutive_failures` reaches `SOURCE_BREAKER_THRESHOLD` (default 3), `breaker_opened_at = now()` and an alert goes to Telegram;
  - **zero items:** a run whose fetch produced pages (or had targets) but `items_found = 0`; it alerts once per source per Cairo day (`last_zero_alert_on`).

  The pause check (`_source_is_paused`) treats `is_enabled = false` (an editor's pause) and `breaker_opened_at IS NOT NULL` as paused. Because the home box can't read the database, every beat entry now goes through `adapters.schedule_fetch(source)` on VPS-2, which checks the pause and then sends the fetch to the right queue. Resume (A13, R12) sets `is_enabled = true`, clears the breaker and the count, and queues one manual run. Every `record_run` bumps the `sources` dataset, so A13's `ETag` changes (R12).
- **Alerts:** `app/adapters/alerts.py` posts to the Telegram Bot API (`api.telegram.org`, allowlisted) with `TELEGRAM_BOT_TOKEN` and `TELEGRAM_CHAT_ID` from VPS-2's `.env`. An alert failure is logged and never fails the run.
- **Alternatives rejected:** time-based auto-reset (the spec keeps a broken source paused until someone looks, constitution VII); counting HTTP errors instead of runs (one flaky page would trip it).

### R18. Placeholder channels

- **Decision:** revision `0005` adds `channels.placeholder_source text REFERENCES sources(name)`. A placeholder is `kind = 'platform'`, `name` = the LiveSoccerTV name, `satellite_id` NULL, `show_in_match = false`, `placeholder_source = 'livesoccertv'`, `country` = the listing country. Before creating one, the adapter looks up `name_norm` among all channels **including soft-deleted ones**; a deleted placeholder with that name means "an editor rejected it", so nothing is created and the name is skipped. Creation writes an audit entry with `source = livesoccertv` (D2's `audit_log.source`) and bumps `channels`.
- **Alternatives rejected:** a separate `channel_candidates` table (A8 would need a second editor and a promote step; the brief keeps A8 as the one channel editor); `kind = 'platform'` without a marker (indistinguishable from real platforms, so the public API couldn't hide them).

### R19. Backups

- **Decision:**
  - **Database:** a `backup-db` one-shot container on VPS-2 (image `restic/restic` plus `postgresql-client-16`, arm64), run by a systemd timer at 03:00 Africa/Cairo: `pg_dump -Fc` over the VCN to a staging file on `/srv/backup`, `restic backup` to the B2 repository, `restic forget --keep-daily 7 --keep-weekly 4 --keep-monthly 6 --prune`, then a push to the Kuma heartbeat URL (success or `status=down` with the error).
  - **Media:** media lives on VPS-1's disk, so `backup-media` runs on VPS-1 by its own timer: `rclone sync /srv/media` to the OCI bucket nightly (03:30), and `restic backup /srv/media` weekly (Sunday 04:00, keep 4 weekly), each with its own heartbeat.
  - Secrets (`RESTIC_PASSWORD`, `B2_ACCOUNT_ID`, `B2_ACCOUNT_KEY`, the OCI S3 keys, heartbeat URLs) live in each host's `.env`.
- **Rationale:** SD §7.3 and constitution IX. A systemd timer calling `docker compose run --rm` is the most boring scheduler and survives Celery outages, which is the point of a backup.
- **Alternatives rejected:** Celery beat tasks (a broken worker would also stop the backups); pulling media to VPS-2 over SSH (opens SSH from VPS-2 to VPS-1, as D2 rejected for logos).

### R20. Uptime Kuma

- **Decision:** `louislam/uptime-kuma:1` (arm64) in `vps2.yml`, data on `/srv/kuma`, published on VPS-2's VCN address only and proxied by VPS-1's `wg0` Caddy site at `https://10.8.0.1/kuma/` (as Flower is planned). Monitors are configured in Kuma's UI by the owner from the runbook (Kuma has no config file): HTTP checks for `https://api.<ip1>.sslip.io/healthz`, `https://media.<ip1>.sslip.io/<known asset>`, `https://<project>.web.app/`, `https://app.<ip1>.sslip.io/`; push monitors for Celery (`ops.heartbeat` beat entries every 5 min on `maintenance`, `imports` and `notifications`, so a dead worker queue goes quiet) and the three backup jobs. Notifications go to the same Telegram chat.
- **Alternatives rejected:** Kuma on VPS-1 (VPS-1 is what it watches); a config-as-code fork (non-standard).

### R21. Who owns what in the backend

- **Decision:** B1 owns `app/devices/`, `app/notifications/` (scheduler, dispatcher, messages, sender), `app/api/public/devices.py`, the cache and limits, the admin additions, revision `0005`, and the `app.workers` change that loads several beat-schedule modules (`app.adapters.schedule` and `app.notifications.schedule`). B2 owns `app/adapters/` (LiveSoccerTV, `schedule_fetch`, `health.py`, `alerts.py`, `ops.heartbeat`), `infra/` and CI. The source-health columns are B1's migration; B2 writes them only through `app/adapters/health.py`, and B1's admin API reads them.

## Lane A: admin screens

### R22. Ordering with drag and keyboard

- **Decision:** `@dnd-kit/core` and `@dnd-kit/sortable` for A6 and A7, with their keyboard sensor (space to lift, arrows to move, space to drop) and Arabic screen-reader announcements; RTL handled by the vertical list strategy. A drop sends the whole new order with each row's version (R12); a `409` shows the D2 conflict dialog and reloads.
- **Alternatives rejected:** HTML5 drag and drop (no keyboard path, constitution IV's visible focus); up/down buttons only (the boards show drag handles).

### R23. A8's editor drawer, A10's audio and A5's logo preview

- **Decision:** the drawer is a feature-local component built from `FormField` and `Button`, with focus trapped and returned, and the D2 unsaved guard. A10's player is a shared `AudioPlayer` (native `<audio>`, one playing at a time, play/pause with a visible focus ring). A5 previews a chosen logo on dark and light tiles with the `Logo` frame. Uploads use D2's media endpoint, then PATCH the entity with the asset id.
- **Alternatives rejected:** a third-party audio player (native `<audio>` covers it).

### R24. A13 and A2 refresh

- **Decision:** React Query `refetchInterval` of 30 s on A13 and 60 s on A2 while the tab is visible; «تشغيل الآن», pause and resume invalidate the sources query. A2 is built from `KpiCard` (INDEX) and `DataTable`.

## Lane M: onboarding, push, settings, system screens

### R25. Firebase in the Flutter app

- **Decision:** add `firebase_core`, `firebase_messaging`, `firebase_remote_config`, `firebase_crashlytics`, `flutter_secure_storage` and `share_plus` (all in SD §5.1). Firebase options come from `env/<flavor>.json` (`--dart-define-from-file`, public identifiers only) and are passed to `Firebase.initializeApp(options: …)`; no `google-services.json` is needed for these plugins, and the Crashlytics Gradle plugin is not used until obfuscated builds need mapping uploads. Each native-only capability sits behind D1's adapters: `CrashReporter` (Crashlytics on Android, no-op on web) and `InstallGuide` (web only).
- **Alternatives rejected:** `flutterfire configure` generating `firebase_options.dart` (generated per flavor and committed; env files already carry these values and stay the one source).

### R26. Web push and the iPhone PWA

- **Decision:** `web/firebase-messaging-sw.js` at the origin root, minimal: `importScripts` of the pinned Firebase compat SDK (`firebase-app-compat`, `firebase-messaging-compat`, an exact version), `firebase.initializeApp` with the public web config, `onBackgroundMessage` showing the notification with its `tag`, and `notificationclick` opening `fcm_options.link`. The public VAPID key goes in `env/*.json`. `getToken` is called only after a user tap (iOS requires the prompt to come from a gesture). Install detection: `navigator.standalone` or `matchMedia('(display-mode: standalone)')`; on iOS Safari not standalone, S1.4 shows S1.5 and no prompt.
- **Rationale:** SD §5.2. FCM's web SDK supports Safari's standard Web Push (iOS ≥ 16.4, installed PWAs only). Caching and mirror failover in the service worker wait for D9–D10.
- **Alternatives rejected:** merging into Flutter's `flutter_service_worker.js` now (that merge is D9–D10's mirror work).
- **Risk:** iPhone push is the plan's top risk (delivery-plan §10); quickstart tests it on a real device today.

### R27. Onboarding state, device registration and follow sync

- **Decision:** a drift table `app_settings` (key/value, typed accessors) holds onboarding progress (`onboarding_step`, `onboarding_done`), theme, time zone, 12/24 h, font scale, my satellites and the follow set. The device token lives only in `flutter_secure_storage`. A `DeviceRepository` registers once (install id generated and kept in secure storage), sends `PUT /devices/me` when the push token, settings or satellites change, and a `FollowsRepository` sends the full set after each change. Pending syncs are flagged in drift and retried on launch, on resume and on reconnect. A `401` re-registers with the same install id (R1). Once a token exists, the Dio interceptor sends `Authorization: Device` on **every** `/v1` request, never to the media host or any other host, so the API's rate limits count each phone separately ([R11](#r11-rate-limits-on-v1)).
- **Alternatives rejected:** SharedPreferences (constitution VIII); a sync queue of individual changes (the full set is small and replaces the server copy).

### R28. Remote Config

- **Decision:** `RemoteConfigRepository` sets the bundled defaults for every SD §5.1 key, fetches on start (`fetchAndActivate`, 10 s timeout, minimum fetch interval 1 h in prod) and exposes typed values. `api_base_url` and `media_base_url` are accepted only when they parse as `https` URLs without userinfo; otherwise the bundled default stays. A change to the hosts applies on the next launch. Every network image goes through one `mediaImage` helper that only loads from the active media host (D2's open security follow-up). Live updates on mobile only (SD §5.1); web reads on start.
- **Alternatives rejected:** applying host changes mid-session (cached ETags and drift keys are per host).

### R29. S0 and the offline banner

- **Decision:** a `ConnectivityState` provider from Dio failures (no new plugin): a request that fails with no response marks offline, the next success marks online. `OfflineBanner` (`Banner` README) shows «أنت غير متصل — آخر تحديث ‹منذ 12 دقيقة›» from the newest cached copy's age. Forced update compares the build number with `min_supported_build` before the router builds; the Play Store link on Android, reload on the PWA. The exit snackbar uses `PopScope` on root tabs.
- **Alternatives rejected:** `connectivity_plus` (reports a network, not reachability, and adds a plugin).

### R30. What is written first

Per FR-053 and constitution Quality Gates, these tests are written and seen failing before their code:

- **B1:** device registration, rotation and `401`s; follow replacement (atomic, cap, unknown ids); scheduler upsert/move/cancel/no-second-row; dispatcher claim with two sessions, `DISTINCT` audience (team + competition + match → 1), cursor resume, `UNREGISTERED` cleanup; reminder copy (channel choice on and off the device's satellites, no-channel body, bidi isolation, Arabic number agreement); cache hit/miss/invalidation by version; rate limits (device vs IP, `Retry-After`, Redis down); admin additions contract tests; placeholders hidden from every public read.
- **B2:** LiveSoccerTV `parse` on saved team and match pages; channel matching (country rule, existing-channel rule, placeholder, deleted placeholder not recreated, unlisted country skipped); link rules (never `manual`, remove own only, hidden stays hidden); breaker open/reset, zero-items once per day; `schedule_fetch` honours pause and breaker; message v1 and v2 accepted.
- **A:** `SortableList` keyboard reorder; `AudioPlayer` states; A5–A8, A10, A13 and A2 flows against the MSW handlers, including the reorder `409`.
- **M:** onboarding resume; follow sync with retry; device re-register on `401`; Remote Config defaults and host validation; reminder deep link routing; S0 states; goldens for new components.
