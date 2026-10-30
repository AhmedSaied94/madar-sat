# Research: D2 · Core flows

Phase 0 of [plan.md](plan.md). Each decision lists what was chosen, why, and what was rejected. D1's decisions ([001 research](../001-d01-foundation/research.md), R1–R21) still hold unless one below replaces them.

## Admin auth (Lane B1)

### R1. Passwords, the CLI and accounts

- **Decision:**
  - `argon2-cffi`'s `PasswordHasher` with its RFC 9106 low-memory defaults (t = 3, m = 64 MiB, p = 4). `check_needs_rehash` runs on login, so changing the parameters later upgrades hashes silently.
  - CLI commands in `app/cli.py`:
    - `create-admin --email --name --role`;
    - `set-admin-password --email`;
    - `deactivate-admin --email`, which also revokes every refresh token of that admin.

    Each reads the password twice with `getpass`, or once from `--password-stdin`. A password is never accepted as an argument, so it can't land in shell history or `ps`. Fewer than 12 characters, a mismatch or a duplicate email exits non-zero.
  - They run on VPS-1 as one-off containers of the backend image, like `load-snapshot` (D1 R10).
- **Rationale:** FR-002 and constitution V. The `staff-accounts.md` runbook needs a way to reset a password and remove an editor before A16 (D6).
- **Alternatives:** A `--password` flag (rejected: shell history). A seed admin in a migration (rejected: a default credential).

### R2. Access JWT, refresh rotation and CSRF

- **Decision:**
  - **Access token:** a PyJWT HS256 token carrying `sub` (admin id), `role`, `iat` and `exp` (15 min). The key comes from `ADMIN_JWT_SECRET` (≥ 32 bytes), checked at startup; api-admin refuses to start without it. The token goes in the response body only.
  - **Refresh token:** `secrets.token_urlsafe(32)`, stored as its SHA-256 in `admin_refresh_tokens` with a `family_id`. Refreshing locks the row (`FOR UPDATE`), marks it `revoked_at` and `replaced_by_id`, and issues a new token in the same family.
    - Presenting a token that is revoked or already replaced revokes the whole family, then answers `401 refresh_invalid`.
    - Refresh re-reads the admin, so a deactivated admin can't refresh.
  - **CSRF:** a separate random `madar_csrf` cookie, rotated on every refresh. Refresh and logout compare `X-CSRF-Token` with it using `hmac.compare_digest`, and a mismatch is `403 csrf_failed`.
  - Cookie names, paths and attributes are exactly those in D1's [admin-auth-v1.md](../001-d01-foundation/contracts/admin-auth-v1.md).
- **Rationale:** FR-004 and constitution V. The shapes were frozen on D1, so only the behavior is designed here.
- **Alternatives:** Asymmetric JWTs (rejected: one service signs and verifies). Server sessions only (rejected: the frozen contract has a bearer token).

### R3. Login limiting and the client IP

- **Decision:**
  - **Key:** `auth:fail:<sha256(lower(email))[:32]>:<ip>`, a Redis sorted set of failure times trimmed to the last 15 minutes.
  - **Lockout:** the fifth failure inside the window sets `auth:lock:<same key>` with `EX 900`. While that key exists, login answers `429 account_locked`, with `retry_after_s` set to its TTL and a matching `Retry-After`. `attempts_remaining` is `5 − count`.
  - **Success** deletes both keys.
  - **Unknown emails** count the same way. They also run `verify` against a fixed dummy hash, so response time doesn't reveal whether an account exists. A deactivated admin gets `invalid_credentials`.
  - **Client IP:** api-admin runs uvicorn with `--proxy-headers --forwarded-allow-ips=10.8.0.1`, so only Caddy on `wg0` can set `X-Forwarded-For`. Lane B2 changes the compose command.
- **Rationale:** FR-003, SD §6.5, and the D1 contract's `attempts_remaining` and `retry_after_s`. Redis was chosen on D1 (001 data-model, `admin_users`).
- **Alternatives:** A fixed 15-minute counter (rejected: an attacker can time the window edge). Counting per account only (rejected: the spec counts per account + IP, and one IP shouldn't lock an editor out everywhere).

### R4. Roles on every route

- **Decision:** One dependency factory, `require_role("editor" | "admin")`. It decodes the JWT, loads the admin by `sub`, rejects inactive admins, and compares role rank (`admin` covers `editor`).
  - Every admin router is created with `dependencies=[Depends(require_role(...))]`.
  - Errors: `401 unauthenticated`, `401 token_expired`, `403 forbidden`.
  - A test walks `app.admin:app.routes` and fails if any route other than `auth/*` and `healthz` lacks the dependency.
- **Rationale:** FR-005 and constitution V. Loading the admin on every request is one indexed read. With 2–5 editors that is cheap, and it makes deactivation and role changes immediate instead of waiting up to 15 minutes for the JWT to expire.
- **Alternatives:** Trusting the role claim (rejected: changes would lag up to 15 minutes).

## Admin writes (Lane B1)

### R5. Entity versions and `If-Match`

- **Decision:** Each entity's `ETag` is strong: `"` + the first 32 hex characters of `sha256(canonical JSON of the entity's own stored state)` + `"`.
  - **Match:** its own columns (status fields and `locked_fields` included), plus its `match_channels` rows (`channel_id`, `source`, `imported_by`, `is_hidden`, both commentators) and its `match_custom_broadcasts` rows, sorted.
  - **Other entities:** their own columns, plus their link rows (a team's competitions).
  - Joined data, such as a team's name shown on a match, is not hashed. Renaming a team therefore doesn't make every open match stale.
  - Writes run `SELECT … FOR UPDATE` on the entity row, recompute the version under the lock and compare it with `If-Match`:
    - missing header → `428 precondition_required`;
    - mismatch → `409 edit_conflict`, with `meta = {current_etag, changed_by: {kind: "admin" | "source", name}, changed_at}` from the entity's latest `audit_log` row (null for snapshot-only rows).
  - Creates (`POST` of a new entity) and the hidden-name add and remove take no `If-Match`, because they have no earlier representation to overwrite ([Complexity Tracking](plan.md#complexity-tracking)).
- **Rationale:** FR-009 and the clarification that an importer's change must make an open editor's copy stale. A content hash catches every writer, importers included, with no version column to keep in sync. The row lock serializes two saves of the same match.
- **Alternatives:** A `row_version` column bumped by triggers on three tables (rejected: a migration and triggers to get the same result). `updated_at` as the version (rejected: link and slot changes don't touch it). The latest audit row's id (rejected: snapshot rows have none).

### R6. One unit of work per admin write

- **Decision:** `app/services/admin/writer.py` runs every mutation through the same steps, in one transaction:
  1. lock the row;
  2. check the version;
  3. apply the validated change;
  4. compute the field diff, keeping only fields whose value changed;
  5. add the changed lockable fields to `locked_fields` (001 data-model lists the lockable columns);
  6. write an `audit_log` row (`admin_user_id`, `entity`, `entity_id`, `action`, `diff`; link changes go under `diff.channels`, slot changes under `diff.broadcasts`);
  7. bump the datasets in the table below, as the last statement;
  8. return the new version.

  | Change | Datasets bumped |
  | --- | --- |
  | Match fields, links or slots | `matches`, plus `live` when `kickoff_at` or `time_tbd` changes |
  | Match status set or cleared | `matches`, `live` |
  | Team | `teams`, `matches` |
  | Competition | `competitions`, `matches` |
  | Satellite | `satellites`, `channels`, `matches` |
  | Channel | `channels`, `satellites` (counts), `matches` |
  | Commentator | `commentators`, `matches` |
  | Hidden channel name | `matches` |
  | Media upload alone | none (no row references the asset yet) |

- **Rationale:** FR-010 and constitution VI. One code path means one set of tests covers audit, locks and versions for every entity.
- **Alternatives:** Database triggers for audit (rejected: they don't know the admin, and they would audit importer noise as well).

### R7. The match editor's payload

- **Decision:** `PATCH /admin/api/matches/{id}` takes optional sections and saves them together under one `If-Match`: `fields`, `broadcasts`, `channels` (the full desired link list) and `status` (`{set: …}` or `{clear: true}`). The shapes are in [contracts/admin-api.md](contracts/admin-api.md). The link list is compared with the stored links:
  - a link in both lists whose `is_hidden` or commentators changed → updated, and set to `source = 'manual'`;
  - a new link → inserted with `source = 'manual'` and `imported_by = NULL`;
  - a link missing from the list:
    - `imported_by IS NULL` (an editor added it) → deleted;
    - otherwise → kept as `source = 'manual'`, `is_hidden = true`, so the importers leave it alone. The clarification chose this.

  A manual status follows FR-011:
  - setting it writes the status columns with `status_source = 'manual'` and locks the fields whose value changed (R6);
  - clearing it sets `status_source = 'clock'`, `status = 'scheduled'`, sets the score, penalties, minute and period to NULL (`ck_matches_clock_no_score` requires this), and removes those names from `locked_fields`.
- **Rationale:** A4 saves one form. Several requests would each change the version, so the second would conflict with the first.
- **Alternatives:** One endpoint per section (rejected for the version reason above). JSON Patch (rejected: harder to validate with Pydantic and to render as a Zod form).

### R8. Bulk actions

- **Decision:** `POST /admin/api/matches/bulk` with `{action, items: [{id, etag}], …}`:
  - `change_competition` (`editor`) takes `competition_id` and an optional `competition_stage`;
  - `remove_channels` (`admin`) takes an optional `channel_ids`; when it is omitted, every visible link is removed, using R7's removal rule.

  Everything is done in one transaction, with the rows locked in id order to avoid deadlocks. If any item is stale, nothing is written and the answer is `409 edit_conflict` with `meta.stale_ids`. Each changed match gets its own `audit_log` row with `action = 'bulk'`.
- **Rationale:** FR-008, FR-009 and PB A3. All-or-nothing keeps the editor's selection consistent.
- **Alternatives:** Best-effort per item (rejected: half-applied bulk changes are hard to see in A3).

### R9. Admin lists and pickers

- **Decision:**
  - **Matches:** `GET /admin/api/matches?from&to` returns the whole list for a window of at most 8 days. The admin sends Cairo day bounds as UTC.
    - Filters: `competition_id`, `source`, `missing_channels`, `status`.
    - `source` matches the row's creator or any of its external ids.
    - `missing_channels` means no visible link and no manual broadcaster.
    - Each row's status is the derived one (D1 R3), with `estimated`, so editors see what fans see.
    - Order: competition priority (nulls last), then kickoff.
  - **Pickers:** `GET /admin/api/teams?q` and the commentator search return the top 20 by `pg_trgm` similarity on `ar_normalize(q)`, with a prefix match first. They don't page; `meta.next_cursor` is null.
  - **Paged browsing:** without `q`, teams, channels and commentators page with an opaque keyset cursor (`(name_norm, id)`, or `(sort_order, id)` for channels), `limit` ≤ 100. Channels also filter by `satellite_id`, `category` and `kind`.
  - **Small whole lists:** satellites, competitions, broadcast presets and hidden names.
  - **Team disambiguation:** every team item carries `country`, its logo, its primary competition and its other competitions.
- **Rationale:** FR-007 and constitution VI (cursor pagination for long lists). The data sizes come from 001 plan, Scale/Scope.
- **Alternatives:** Offset pagination (rejected: unstable while importers insert rows).

### R10. Uploads

- **Decision:** `POST /admin/api/media` takes `multipart/form-data` with `kind` (`image` | `audio`) and `file`.
  - **Size first:** a `Content-Length` above the cap plus 64 KB is refused before parsing, and the body is read with a hard cap.
  - **Type by magic bytes:**
    - images: PNG `89 50 4E 47`, JPEG `FF D8 FF`, WebP `RIFF….WEBP`;
    - audio: MP3 `ID3` or a frame sync `FF Ex`/`FF Fx`, M4A/AAC `….ftyp`, OGG `OggS`, WAV `RIFF….WAVE`.
  - **Encoding:**
    - Pillow decodes with `Image.MAX_IMAGE_PIXELS` set to 40 MP (decompression bombs), then re-encodes to WebP ≤ 512 px without metadata;
    - `ffprobe` must read the audio, and `ffmpeg -t 30` encodes it to AAC in MP4.

    This code moves from `app/etl/media.py` into `app/media/encode.py`, shared by the rehoster and the upload. Both are B1's code.
  - **Storage:** content-addressed under `MEDIA_ROOT`. An existing `sha256` returns the existing `media_assets` row.
  - **Where it runs:** inside api-admin, in a thread pool. Lane B2 mounts `/srv/media` read-write into api-admin.
  - **Errors:** `415 unsupported_media_type`, `413 file_too_large`, `422 media_invalid`.
  - **New dependency:** `python-multipart` (FastAPI's form parser).
- **Rationale:** FR-012 and constitution V. With 2–5 editors and files of at most 1 MB, encoding in the request takes about 1 s, and A10 (D3) needs the asset back right away to preview it.
- **Alternatives:** Encoding audio on a worker, as SD §6.9 describes (rejected for now: VPS-2's workers can't write VPS-1's media disk, and an asynchronous result would need polling. SD's intent, keeping heavy work off the public API, is still met, because api-admin is a separate process on `wg0`). `python-magic` (rejected: it needs libmagic; nine signatures don't).

### R11. Manual status on the read path, and the 60 s path

- **Decision:** No read-path change is needed.
  - `derive_status` already returns `manual` rows as stored, with `estimated: false` (D1 R3).
  - Bumping `live` and `matches` changes every affected `/v1` ETag at once, and there is no response cache until D3.
  - A B1 integration test performs the editor's save, then calls `/v1/matches` and `/v1/live` with the old ETags and expects `200` with the change.
  - Lane M's 60 s refresh closes the loop (FR-047).
- **Rationale:** FR-011, FR-014 and SC-001.

### R12. Revision `0003`: two columns

- **Decision:** A small expand-only revision, which the owner reviews line by line (delivery-plan §5.4):
  - `audit_log.source text REFERENCES sources (name)`, with `ck_audit_log_actor`: `admin_user_id IS NULL OR source IS NULL`. Importers write `audit_log` rows with `source` set when they change a match, so the conflict dialog and A17 (D6) can name the source.
  - `match_channels.imported_by text REFERENCES sources (name)`: the source that first brought the link. NULL means an editor added it. It is backfilled with `source` wherever `source <> 'manual'`. R7's removal rule needs it, because editing a link sets `source = 'manual'` and so forgets which importer brought it.
- **Rationale:** These are the smallest schema changes that make the clarified rules work. Both serve the brief's "audit writes" and "`locked_fields`" items. `/v1` doesn't change.
- **Alternatives:** Keeping the original source only in `audit_log` (rejected: a lookup on every link removal, and snapshot links have no audit rows). Writing importer changes to logs only (rejected: the conflict dialog couldn't name the source).

## Ingestion (Lane B2, with B1's worker app)

### R13. The Celery app and queues

- **Decision:**
  - **App:** B1 creates `backend/app/workers/__init__.py`, the `app.workers` app that `vps2.yml` already names.
    - Broker: Redis, with `broker_transport_options = {"global_keyprefix": "celery:"}`.
    - Settings: `task_ignore_result=True`, `task_acks_late=True`, `task_reject_on_worker_lost=True`, `worker_prefetch_multiplier=1`, JSON only.
    - A base task class that sets `bind=True`, `autoretry_for=(Retryable, httpx.TransportError)`, `retry_backoff=True`, `retry_backoff_max=600`, `retry_jitter=True` and `max_retries=5`.
    - `workers/locks.py`: a Redis `SET NX EX` context manager (constitution VII).
    - It imports `app.adapters.tasks` and takes its `beat_schedule` from `app.adapters.schedule`.
  - **Queues:** `scrape` (VPS-2), `scrape_home` (the home box only), `imports` (VPS-2), `maintenance` (VPS-2), and `media` (VPS-1's `worker-media` only, R20). `live` and `notifications` stay idle until D3–D5.
  - **New dependencies:** `celery[redis]`; `lxml` (B2's parser).
- **Rationale:** Constitution VII and SD §6.1. The key prefix lets a Redis ACL restrict the home box to Celery's keys (R21). B1 owns everything in `backend/` outside `adapters/`, so it delivers this skeleton in the morning, and B2's tasks plug into it.
- **Alternatives:** B2 writing `app/workers/` (rejected: delivery-plan §4 ownership).

### R14. The `SourceAdapter` base

- **Decision:** `app/adapters/base.py` defines the SD §6.6 protocol and an `HttpFetcher`:
  - **Client:** an `httpx.Client` with `follow_redirects=False`. A redirect is followed by hand, at most 3 times, and only to a host in the adapter's `allowed_hosts`; any other target fails the request.
  - **Limits:** timeouts of 5 s to connect and 20 s to read. The body is streamed with a 5 MB cap.
  - **Rate limit:** a token bucket per host in Redis (`ratelimit:<host>`), one atomic Lua script. ysscores gets 1 request per 4 s with a burst of 2; Firestore 5 per second.
  - **Errors:** 429, 403 and 5xx raise `Retryable`, so Celery backs off with jitter. Other 4xx statuses and parse errors fail the run without a retry.
  - **User agent:** read from `SCRAPE_USER_AGENT`.
- **Rationale:** FR-020 and constitution V (SSRF) and VII.
- **Alternatives:** httpx's built-in redirect following (rejected: it can't check the target host before following).

### R15. Raw pages and run records

- **Decision:**
  - **Fetching:** the fetch task (on whichever host) gzips each page and sends it, base64-encoded and capped at 2 MB per message, with the parsed items in one versioned `ScrapeResult` message ([contracts/ingestion.md](contracts/ingestion.md)).
  - **Saving:** `ingest` on VPS-2 writes the pages to `/srv/raw/<source>/<YYYY-MM-DD>/<run_id>/<n>.html.gz`, plus a `run.json` with the counts, the skipped items, and the unresolved names with their context. That folder is `import_runs.raw_path`.
  - **Pruning:** a daily `prune_raw_pages` task on `maintenance` deletes run folders older than 5 days.
  - **Run rows:** a failed fetch still sends a `ScrapeResult`, with `http_errors` and no pages, so the run row records the failure.
- **Rationale:** FR-020 and FR-025. The home box has no database access and no shared disk, so the pages must travel with the message, and VPS-2 is where SD §7.1 keeps raw HTML.
- **Alternatives:** Keeping pages on the home box (rejected: they can't be read from VPS-2, and they would be lost if the box dies).

### R16. The ysscores adapter

- **Decision:**
  - **Fetch:** one `POST https://www.ysscores.com/ar/match_date_to` per Cairo day, today to +3, with the form body `get_date=<Month D,YYYY>` (English month, no space after the comma, as `IMPORT.html` builds it). `allowed_hosts = {"www.ysscores.com"}`. A response without `matches-wrapper` is treated as a layout change: the run is `failed` and the page is saved.
  - **Parse:** pure, with `lxml.html`. Each `.matches-wrapper` (`champ_title`, `champ_img`) contains `a.ajax-match-item` elements. Teams, logos and the time come from the element's attributes and `.match-date`, as `parseYSDay` reads them. The ysscores match id comes from the `/ar/match/<id>/<slug>` href.
  - **Normalize:** times are Cairo wall clock (IMPORT.html: «مواعيد الموقع بتوقيت القاهرة أصلاً»), converted with `app.domain.time`. `"--:--"` sets `time_tbd`. Placeholders become NULL and doubled stage text is cleaned.
  - **Status:** fixtures only. The adapter writes no status or score; feed status is D5's work (constitution II).
  - **Tests:** pages saved by B2 on D2 go in `backend/tests/fixtures/ysscores/`: a normal day, a day with `"--:--"` and a postponement, and an empty day. One test pins a known kickoff, so a change in the site's time zone is caught.
  - **Routing:** fetches go to `scrape_home` when `YSSCORES_FETCH_QUEUE=scrape_home` (the default; SD §6.6 says ysscores blocks datacenter IPs), else to `scrape`.
- **Rationale:** FR-021, and the brief: "ported from `IMPORT.html`". Reading attributes is as stable as the old page made it.
- **Alternatives:** The per-match pages (rejected: channels are LiveSoccerTV's job on D3, and 4 requests per run are kinder to the site than about 200).

### R17. Entity resolution v0

- **Decision:** `app/adapters/resolve.py`.
  - **Competition:** a `competition_external_ids` hit, then an exact `(sport, name_norm)` match. Otherwise `competition_id` stays NULL and the name is kept.
  - **Team:**
    1. a `team_external_ids` hit, when the page gives a team id;
    2. exactly one team with the same `name_norm` and sport;
    3. among several, the one whose primary or linked competition names score highest under a Python port of `competitionSimilarity`, `tokenize`, `stripArabicAffixes` and `STOP_WORDS` from `../old_app/src/utils/arabicMatch.js`, with a score of at least 0.5 and no tie.

    Anything else keeps the text name and gets no id. It is listed in `run.json` and logged as `team_unresolved`. Teams are never created automatically.
  - **Tests:** the port is tested against cases taken from the JS function's behavior.
- **Rationale:** FR-023 and constitution II: no guessing beyond the documented rules. The alias tables and the queue are D5's work (Complexity Tracking).

### R18. The upsert pipeline

- **Decision:** `app/adapters/upsert.py`, used by both ysscores and the bridge. Each fixture runs in a savepoint, so one bad item marks the run `partial` instead of failing it.
  1. **Find the row**, in order:
     - by `(source, external_id)`;
     - else by a duplicate probe: the same resolved home and away team ids with kickoffs within 45 minutes, or, when either id is NULL, the same normalized home and away names on the same `match_date`;
     - else insert a new row with `source = <adapter>`.
  2. **Lock the row** with `SELECT … FOR UPDATE` and re-read `locked_fields` under the lock. An admin save that commits just before is never overwritten.
  3. **Write** only unlocked fields whose value differs, and record the external id.
  4. **Audit:** if anything changed, write an `audit_log` row with `source` set (R12).
  5. **Logos:** for a resolved team or competition whose logo is NULL, and a logo URL on an allowlisted host, queue `rehost_logo` on `media` after the commit (R20). The pipeline itself never stores a URL.
  6. **Bump** `matches` (and `live` when a kickoff changed) once, at the end of the run.

  `match_channels` follows the importer rules:
  - insert with `source = imported_by = <adapter>`;
  - remove only rows whose `source` is this adapter;
  - never touch `source = 'manual'` rows.
- **Rationale:** FR-022 and constitution VII. The row lock plus the re-read is what makes an editor's lock hold against an import running at the same moment.
- **Alternatives:** One `INSERT … ON CONFLICT` per fixture (rejected: it can't honor per-field locks or write the diff).

### R19. The Firestore bridge

- **Decision:** `app/adapters/satair_bridge.py`, with source key `legacy`, runs on `scrape` (VPS-2).
  - **Fetch:** `GET https://firestore.googleapis.com/v1/projects/<SATAIR_FIREBASE_PROJECT_ID>/databases/(default)/documents/matchDays/<YYYY-MM-DD>?key=<SATAIR_FIREBASE_API_KEY>`, one request per day for today to +3. It is a GET only, so the bridge is read-only by construction. `allowed_hosts = {"firestore.googleapis.com"}`.
  - **Config:** the two values live only in VPS-2's `.env` (D15, FR-052).
  - **Parse:** pure. It converts Firestore's typed values (`stringValue`, `arrayValue`, `mapValue`, …) to plain JSON, as `export-firestore.mjs` does, then reads `matches[]` using the README rules:
    - placeholders become NULL;
    - `channelIds` resolve by `channels.legacy_id`, and an unknown id is skipped and logged;
    - `hiddenChannels` sets `is_hidden`;
    - `channelCommentators` gives commentator 1 and 2, by `name_norm`, creating a commentator row when the name is new, as the snapshot load does;
    - no card-sharing labels are read.
  - **Upsert:** through R18, keyed on `matches.legacy_id` (the Sat Air id; D1's upsert key for these rows). It also records `ysMatchId` as the ysscores external id, so bridge and ysscores rows converge.
    - If the match already has a ysscores external id, the bridge leaves its fields alone and updates only its `legacy` links.
    - Manual broadcaster slots aren't imported (the clarified scope).
  - **Schedule:** beat runs it every 3 hours at +90 min from ysscores, and on demand.
- **Rationale:** FR-027 and the Q2 clarification. The old data is still maintained by Sat Air's own editors, so its links are the best channel coverage before LiveSoccerTV arrives on D3.
- **Alternatives:** The Firebase Admin SDK (rejected: it needs a service account for a project we don't own; the public web config already permits these reads). Reusing D1's private ETL functions (rejected: they read the export format, not Firestore's typed REST format, and they belong to B1).

### R20. Importer-found logos: a media worker on VPS-1

- **Decision:** `vps1.yml` gets `worker-media`: the backend image running `celery -A app.workers worker -Q media -c 1`, with a 256 MB memory limit and `/srv/media` mounted read-write. It uses the local PostgreSQL and Redis.
  - **Requests:** the import workers on VPS-2 queue `rehost_logo(entity, id, url, source)` (R18 step 5). A lock on `lock:media:<sha256(url)>` drops duplicates while one is in flight.
  - **The task** (`app/adapters/media_tasks.py`, B2) calls B1's code: `fetch_media` with `MEDIA_REHOST_ALLOWED_HOSTS` and `download_and_encode` from D1, which move into `app/media/` alongside R10's encoders. It then:
    1. reuses the `media_assets` row when the content hash is already stored, with the source URL in `original_url`;
    2. runs `UPDATE … SET logo_asset_id = :asset WHERE id = :id AND logo_asset_id IS NULL`, so an editor's logo, or one set in the meantime, is never replaced;
    3. writes an `audit_log` row with `source` set, and bumps `teams` or `competitions`, plus `matches`.

    A host outside the allowlist, a redirect to another host, an oversize file or a decode failure is logged and dropped. Network errors and 5xx retry with backoff, as in R13.
  - **Health and deploy:** it has the same `celery inspect ping` healthcheck as VPS-2's workers. VPS-1's `deploy.sh` waits for it as well as for `/healthz` before declaring success, and rolls back both together.
  - **Scope:** match-level logo overrides (`home_logo_asset_id`, `away_logo_asset_id`) aren't filled. NULL already means "use the team's logo".
- **Rationale:** FR-024 and the planning clarification. The files must land on VPS-1's disk, where Caddy serves them (SD §6.9). A worker next to the disk needs no file transfer, no new credential and no new network path, and it runs the rehost code D1 already proved on VPS-1. A few logos a day, one at a time, fits in VPS-1's roughly 2 GB of spare memory (SD §7.1).
- **Alternatives:**
  - VPS-2 joins WireGuard and uploads through `POST /admin/api/media` with an importer account (rejected by the owner: a bot credential, the Caddy CA on VPS-2, and a new peer).
  - rsync from VPS-2 over the VCN (rejected: it opens SSH from VPS-2 to VPS-1 and needs a restricted key).
  - Deferring the logos (rejected: new teams would show placeholders until an editor uploads each one).

### R21. The x86-64 home box

- **Decision:**
  - **Image:** `backend.yml` also builds `linux/amd64` on master, natively on the x86 runner, and pushes it as a separate package, `ghcr.io/<owner>/madar-backend-amd64:<sha>`. After the VPS deploys succeed, it moves a `stable` tag to that sha. Retention keeps 3 versions, as for the arm64 package (D1 R13).
  - **Compose:** `infra/compose/home-box.yml` runs only `worker-scrape -Q scrape_home`, with no database credentials. Its broker is Redis at `10.8.0.1:6379` over WireGuard.
  - **Updates:** a systemd timer on the box runs `infra/scripts/home-box-update.sh` every 10 minutes. It pulls `:stable` with a GHCR read-only token kept in the box's `.env`, then runs `up -d`. CI never connects to the box, so no peer-to-peer forwarding is opened on the hub, and an offline box doesn't fail a deploy.
  - **Version skew:** `ScrapeResult` carries `schema: 1`. `ingest` accepts the current and the previous version and rejects anything else loudly.
  - **Redis:** `vps1.yml` also publishes Redis on `10.8.0.1:6379`. `infra/firewall/vps1.rules` allows it only from the home box's peer address, with a `DOCKER-USER` rule (Docker-published ports never reach INPUT), and drops D1's INPUT rule that accepted 6379 from every `wg0` peer.
  - **Settings:** the box has no database URL, so `app.workers` reads only its broker URL, and the fetch path never imports `app.settings` or `app.db`. A Redis ACL user, `homebox`, may touch only the key patterns `celery:*`, `ratelimit:*` and `lock:*`, and may not run admin or dangerous commands.
  - **Expiry:** home-box tasks expire after 2 hours, so a box that was offline doesn't replay stale fetches.
- **Rationale:** FR-028, FR-029, the Q1 clarification and SD §7.2 (the home box reaches Redis only). A separate package avoids the known trouble of multi-arch manifests under retention, where per-platform manifests show up as untagged versions and get deleted.
- **Alternatives:** A multi-arch manifest under one tag (rejected: the retention issue above). CI deploying through the hub (rejected: it needs FORWARD rules between peers, and fails when the box is off). QEMU on the box (rejected: slow, fragile).

### R22. Deploying VPS-2

- **Decision:** `backend.yml` gets a `deploy-vps2` job after `deploy` (VPS-1, which runs the migrations).
  - **Access:** it reaches VPS-2 with `ssh -J deploy@10.8.0.1 deploy@<VPS2_VCN_IP>`, because VPS-2's port 22 is open only from VPS-1 (SD §7.2). Host keys for both are in `DEPLOY_KNOWN_HOSTS`.
  - **Steps:** it rsyncs `infra/` and runs `deploy.sh --host vps2 <sha>`, which:
    - pulls the image;
    - runs `compose -f compose/vps2.yml up -d` for the workers and `beat`;
    - waits up to 90 s for every container to be healthy (`celery inspect ping`, and the `beat` pid check already in `vps2.yml`);
    - on failure, restores the previous tag.
  - **Concurrency:** group `deploy-vps2`.
  - **VPS-2's `.env`:** `DATABASE_URL_SYNC` and `REDIS_URL` pointing at VPS-1's VCN IP, plus the `SATAIR_*` values and `SCRAPE_USER_AGENT`.
- **Rationale:** FR-029 and constitution IX (health-checked deploys with rollback). Nothing deploys to VPS-2 yet (`docs/runbooks/README.md`).

## Admin (Lane A)

### R23. Reaching the admin API over WireGuard on D2

- **Decision:** `pnpm dev:wg` runs Vite with `server.proxy['/admin/api']` → `https://10.8.0.1`. `NODE_EXTRA_CA_CERTS` points at Caddy's internal root, which the editor installed when joining `wg0`.
  - The browser talks only to `localhost`, so the cookies are host-only on one origin, and `SameSite=Strict` and the CSRF header work unchanged. Chrome and Firefox treat `localhost` as a secure context, so `Secure` cookies are kept.
  - Deploying on `wg0` stays on D4.
- **Rationale:** The done check needs "an admin logs in over WireGuard". A same-origin proxy needs no CORS, which the admin API must never enable (SD §5.4).

### R24. Session, forms and time in the admin

- **Decision:**
  - **Session:** the access token lives in memory only (D1's `session.ts`). On load, the app calls refresh once. It refreshes again at `expires_in − 60 s`. A `401 token_expired` triggers one shared refresh followed by a retry, and a failed refresh returns to A1. The CSRF header is read from the `madar_csrf` cookie by the Orval mutator in `src/api/http.ts`.
  - **Forms:** A4 is one React Hook Form form with Orval's Zod schema as the resolver. A save sends only the sections that changed.
  - **Unsaved guard:** React Router's `useBlocker` (the app moves to `createBrowserRouter` if it isn't on it already), plus `beforeunload`.
  - **Conflict:** on `409`, the client fetches the current match and shows `ConflictDialog` with the field diff and the `changed_by` name. "Reload" resets the form to the current version.
  - **Cairo time:** `date-fns-tz` (`fromZonedTime`, `formatInTimeZone`) with `Africa/Cairo`. Digits are forced Western with `ar-EG-u-nu-latn`. The time field shows «بتوقيت القاهرة». A test enters a kickoff on each side of Egypt's DST change.
  - **New dependencies:** `date-fns` and `date-fns-tz`.
- **Rationale:** FR-030 to FR-034, the Q4 clarification, and constitution III (Western digits). `Intl` can format a time zone but not parse one, and `date-fns-tz` is the small, well-tested standard for that.
- **Alternatives:** Hand-rolled offset arithmetic (rejected: DST edge cases). The Temporal polyfill (rejected: large, and still a proposal).

## App (Lane M)

### R25. Stale-while-revalidate with drift

- **Decision:**
  - **Matches:** the D1 `matches` table holds rows by id with `kickoff_at`. A new `match_windows` table (local-day key, `etag`, `fetched_at`) records each day's revalidation. The repository:
    1. emits the rows of that local day from drift;
    2. sends `If-None-Match` with the window's ETag;
    3. on `200`, replaces that day's rows and the ETag in one transaction, and emits again;
    4. on `304`, touches only `fetched_at`.

    It keeps local days today−1 to today+6 and prunes older ones.
  - **Other screens:** a `cached_documents` table (`key`, `etag`, `body` as JSON text, `fetched_at`) holds match detail, `/v1/satellites`, each satellite's channel list, and S4's day filtered by `satellite_ids`, with the same flow. S4's list goes there, not into `match_windows`, because it is a different query: written through the day path, it would replace S2's full day, and filtering S2's rows locally would miss carriages (a row's channel line holds at most 2).
  - **Freshness targets:** `StaleHint` appears once a copy is past its target: 5 minutes for matches and match detail, 24 hours for satellites and channels. A cached state is never shown as live: `StatusBlock` uses the cached status only for non-live states, and live states come only from `/v1/live`, in memory.
- **Rationale:** FR-046, constitution VIII and SD §5.1. Typed rows are needed to group matches by local day across windows; the other screens read whole documents, so JSON is the smallest correct cache for them.
- **Alternatives:** Typed tables for every shape (rejected: a lot of schema for documents that are only ever read whole). Dio's HTTP cache (rejected: it isn't drift, and it can't group by local day).

### R26. Polling, audio, lists and links

- **Decision:**
  - **Polling:** a Riverpod provider runs a 60 s timer for matches, and a 30 s timer for `/v1/live` while a live or imminent match is on screen. Both run only while the route is visible and `AppLifecycleListener` reports `resumed`, and stop otherwise.
  - **Audio:** `just_audio` (SD §5.1's package; it works on web) with one shared player in a provider, so starting a clip stops the other. Errors show `CommentatorRow`'s error state. On web, playback starts only from the tap.
  - **Lists:** S3 builds a `CustomScrollView` with one `SliverList.builder` per open group, and collapsed groups render only their header, so 171 links stay cheap. A back-to-top button appears after two screen heights.
  - **Links and copying:** `url_launcher` opens the reception video, and `Clipboard` copies the frequency.
  - **Logos:** `cached_network_image`, if D1's `LogoTile` doesn't already cache.
  - **Day paging:** a `PageView` inside the app's RTL `Directionality`, so a swipe follows RTL order.
  - **My satellites:** resolved from `/v1/satellites` by the slugs of Nilesat 7.0W and Badr (O10) until D3 stores the user's choice.
  - **New dependencies:** `just_audio`, `url_launcher`, `cached_network_image`, all in SD §5.1's package list.
- **Rationale:** FR-042, FR-043 and FR-047, constitution VIII (lists virtualized, logic in providers), and SC-006.

### R27. The closed-test build and the PWA preview

- **Decision:**
  - **Android:** the owner pushes a tag such as `app-v0.2.0`. `app-release.yml` (from D1) builds the signed `prod` AAB with `versionCode = run_number` and keeps it as a run artifact. The owner enrols in Play App Signing, uploads the AAB to the closed track by hand, and adds the testers.
  - **PWA:** `pwa.yml` keeps deploying `master` to the preview channel. It can load data once the owner adds its origin to `CORS_ORIGINS` (D1 carry-over).
  - **Runbook:** `store-releases.md` (Lane M) documents the tag, the upload and the testers list.
- **Rationale:** FR-049 and SD §9: the Play upload arrives with the Play service account, later.

## Tests

### R28. What is written first

| Area | Test (written and seen failing first) | Lane |
| --- | --- | --- |
| Auth | login, lockout on the sixth attempt, unknown-email parity, refresh rotation, family revocation on reuse, CSRF, deactivated admin | B1 |
| Writes | `428` / `409` with `changed_by`; audit diff of changed fields only; `locked_fields` for changed lockable fields; the dataset-bump table; link removal keeps imported links hidden; bulk all-or-nothing; the manual status rules and their DB checks | B1 |
| Uploads | each magic signature; oversize; a fake `.png`; a decompression bomb; a duplicate returns the same asset; audio trimmed to 30 s | B1 |
| Read path | an admin save, then the old `/v1` ETags get `200` with the change (SC-001's backend half) | B1 |
| Contract | schemathesis over the admin OpenAPI (FR-013); every admin route has a role dependency | B1 |
| Ingestion | ysscores `parse` on the saved pages; Cairo → UTC, including DST; resolution v0 including the similarity port; upsert idempotency; locked fields survive; duplicate probe; the bridge's typed-JSON parse and link rules; prune; lock overlap skipped; `rehost_logo` fills only empty logos and refuses hosts outside the allowlist | B2 |
| Admin | A3 filters and grouping; A4 Cairo entry across DST; conflict dialog; unsaved guard; typed confirmation; Zod on every response (MSW from Orval) | A |
| App | local-day grouping; channel-line ranking; every `StatusBlock` variant; the SWR repository (200, 304, offline); `StaleHint` thresholds; goldens for every new component | M |

- **Rationale:** FR-053, and the constitution's Test-first list. The coverage bar stays D1's MVP bar (FR-054).
