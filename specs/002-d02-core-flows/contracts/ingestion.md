# Contract: ingestion (adapters, tasks, messages, hosts)

This is the interface between Lane B1's worker app (`app.workers`) and Lane B2's adapters (`app/adapters/`), and between the three hosts that run them. It isn't part of the OpenAPI.

Sources: SD §6.1, §6.6, §6.9, §7.2; constitution VII; spec FR-020 to FR-029; [research](../research.md) R13–R22.

## `SourceAdapter` (SD §6.6)

```python
class SourceAdapter(Protocol):
    name: str                          # the sources.name it writes as: "ysscores", "legacy"
    allowed_hosts: frozenset[str]      # {"www.ysscores.com"}; {"firestore.googleapis.com"}
    def fetch(self, window: DateWindow) -> list[RawPage]: ...          # through HttpFetcher only
    def parse(self, page: RawPage) -> list[ParsedFixture]: ...         # pure: no network, no DB, no clock
    def normalize(self, item: ParsedFixture) -> NormalizedFixture: ... # UTC, ar_normalize, placeholders → None
```

- **`DateWindow`:** Cairo calendar days, today to +3.
- **`RawPage`:** `{url, fetched_at, status, body: bytes, content_type}`.
- **`ParsedFixture`:** the page's own values, as strings: `external_id`, `url`, `competition`, `competition_logo`, `stage`, `home`, `away`, `home_logo`, `away_logo`, `home_external_id`, `away_external_id`, `wall_time` (`"21:00"`, `"--:--"`), `match_date`, plus, for the bridge, `links: [{channel_ref, hidden, commentator, commentator2}]` and `ys_match_id`.
- **`NormalizedFixture`:** `kickoff_at` (UTC or None), `time_tbd`, the names after placeholder cleanup, and the logo URLs, kept only when their host is on `MEDIA_REHOST_ALLOWED_HOSTS`.

## Queues, tasks and schedule

| Task | Queue | Runs on | What it does |
| --- | --- | --- | --- |
| `adapters.fetch(source, window, run_id)` | `scrape_home` (ysscores, by default) or `scrape` (the bridge; ysscores when `YSSCORES_FETCH_QUEUE=scrape`) | the home box / VPS-2 | Takes `lock:fetch:<source>`, fetches and parses, then sends a `ScrapeResult` to `adapters.ingest`. Expires 2 h after it is queued |
| `adapters.ingest(result)` | `imports` | VPS-2 | Takes `lock:ingest:<source>`, saves the raw pages, writes `import_runs`, normalizes, resolves, upserts, bumps, queues logos |
| `adapters.rehost_logo(entity, id, url, source)` | `media` | VPS-1 (`worker-media`) | Rehosts one logo into an empty logo field ([research R20](../research.md#r20-importer-found-logos-a-media-worker-on-vps-1)) |
| `adapters.prune_raw_pages()` | `maintenance` | VPS-2 | Deletes raw run folders older than 5 days |

| Beat entry | Schedule (UTC) | Task |
| --- | --- | --- |
| `ysscores-fixtures` | `crontab(minute=0, hour="*/3")` | `fetch("ysscores", today…+3)` |
| `satair-bridge` | `crontab(minute=30, hour="1-22/3")` (+90 min) | `fetch("legacy", today…+3)` |
| `prune-raw-pages` | `crontab(minute=15, hour=3)` | `prune_raw_pages()` |

- **On demand:** `celery -A app.workers call adapters.fetch --args '["ysscores"]'`. The runbook has the exact command.
- **Defaults:** every task uses the `app.workers` base class (`bind=True`, autoretry with backoff and jitter, `max_retries=5`; [research R13](../research.md#r13-the-celery-app-and-queues)).
- **Overlap:** a run that finds its lock held exits after recording `skipped` in the logs.

## `ScrapeResult` message (schema 1)

Validated by Pydantic on both ends. `ingest` accepts `schema` 1. From the first change on, it also accepts the previous version, and anything else is rejected loudly ([research R21](../research.md#r21-the-x86-64-home-box)).

```jsonc
{ "schema": 1,
  "source": "ysscores", "run_id": "2026-10-31T03:00:00Z-ysscores-7f3a",
  "started_at": "2026-10-31T03:00:02Z", "finished_at": "2026-10-31T03:00:21Z",
  "fetched_on": "home-box",                        // the worker's host name, for the run record
  "pages": [ { "url": "https://www.ysscores.com/ar/match_date_to#2026-10-31", "status": 200,
               "fetched_at": "…", "gz_b64": "H4sI…" } ],          // ≤ 2 MB per message
  "items": [ ParsedFixture, … ],
  "http_errors": 0,
  "error": null }                                   // a short reason when the fetch failed, e.g. "layout_changed"
```

## Raw pages and run records

The layout is in [data-model.md](../data-model.md#raw-pages-and-run-records): `/srv/raw/<source>/<day>/<run_id>/` on VPS-2, kept 5 days, and pointed to by `import_runs.raw_path`.

## Hosts and their settings

| Host | Services | Settings (`.env`, mode 600; never committed) |
| --- | --- | --- |
| VPS-1 | `api-public`, `api-admin` (now with `/srv/media` mounted read-write and `--proxy-headers --forwarded-allow-ips=10.8.0.1`), `worker-media`, PostgreSQL, Redis (published on the VCN IP and on `10.8.0.1:6379`) | D1's settings, plus `ADMIN_JWT_SECRET`, the `REDIS_HOMEBOX_PASSWORD` that seeds the `homebox` ACL user, and `CORS_ORIGINS` including the PWA preview origin (D1 carry-over) |
| VPS-2 | `worker-imports`, `worker-scrape`, `worker-maintenance`, `beat` (`worker-live`, `worker-notify` and `flower` stay defined but aren't started on D2) | The base values `Settings` requires for `ingest`: `DATABASE_URL`, `DATABASE_URL_SYNC` and `REDIS_URL` → VPS-1's VCN IP, `MEDIA_BASE_URL`, `MEDIA_ROOT`, `MEDIA_REHOST_ALLOWED_HOSTS`, `CORS_ORIGINS` (unused by workers); plus `SATAIR_FIREBASE_PROJECT_ID`, `SATAIR_FIREBASE_API_KEY`; `SCRAPE_USER_AGENT`; `YSSCORES_FETCH_QUEUE`; `RAW_ROOT=/srv/raw` |
| Home box (x86-64) | `worker-scrape -Q scrape_home` from `madar-backend-amd64:stable`, and a 10-minute update timer | `REDIS_URL=redis://homebox:<password>@10.8.0.1:6379/0`, `SCRAPE_USER_AGENT`, and `GHCR_READ_TOKEN` (read-only packages token). No database URL, so the fetch path never loads `app.settings` or `app.db`: `app.workers` reads only its broker URL (`CELERY_BROKER_URL`, else `REDIS_URL`) |

### The home box's Redis ACL

```text
user homebox on >${REDIS_HOMEBOX_PASSWORD} ~celery:* ~ratelimit:* ~lock:fetch:* &*
  -@all +@connection +@read +@write +@keyspace +@string +@list +@hash +@set +@sortedset
  +@transaction +@scripting +@pubsub -@admin -@dangerous
```

- The ACL is one line in the real file, shown wrapped here. B2 renders the file from a template at deploy time, so the password comes from `.env` and never sits in the repo.
- The categories are the starting point. B2 confirms them against the commands Celery and the token-bucket script actually send, and narrows any it doesn't need.
- A test connects as `homebox` and must be able to queue and consume a task, but must fail to read an `auth:*` key and to run `CONFIG`, `FLUSHALL` or `KEYS`.
- The key patterns cover what the box uses: Celery's prefixed keys, the rate-limit buckets, and its fetch locks.
- The firewall allows `10.8.0.1:6379` only from the home box's peer address (`infra/firewall/vps1.rules`). Docker publishes the port, so the rule is in `DOCKER-USER`, not INPUT, and D1's INPUT rule that accepts 6379 from every `wg0` peer is removed.

## Who builds what

| Piece | Lane | Path |
| --- | --- | --- |
| The `app.workers` app, base task class, locks, queue declarations | B1 | `backend/app/workers/` |
| Revision `0003`; `app/media/` (encoders and the D1 rehost helpers, moved) | B1 | `backend/alembic/`, `backend/app/media/` |
| Adapters, the fetcher, rate limits, resolution, upsert, tasks, schedule, the message | B2 | `backend/app/adapters/` |
| `vps1.yml` (`worker-media`, the Redis `wg0` port, the api-admin flags and mount), `vps2.yml`, `home-box.yml`, the firewall, the Redis ACL file, `deploy.sh --host vps2`, `home-box-update.sh`, the `backend.yml` jobs | B2 | `infra/`, `.github/workflows/` |
