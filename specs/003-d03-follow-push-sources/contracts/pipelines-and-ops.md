# Contract: pipelines, notifications and ops (B1 ↔ B2)

Internal interfaces between lanes inside `backend/` and `infra/`. D2's [ingestion contract](../../002-d02-core-flows/contracts/ingestion.md) still holds; this file lists what D3 adds or changes.

## Who builds what

| Piece | Lane | Path |
| --- | --- | --- |
| Revision `0005` (devices, outbox, sources, channels, `import_runs.log`) | B1 | `backend/alembic/versions/0005_devices_outbox_sources.py` |
| Device and follow services, `/v1/devices*` | B1 | `backend/app/devices/`, `backend/app/api/public/devices.py` |
| Scheduler, dispatcher, messages, `PushSender`, outbox prune | B1 | `backend/app/notifications/` |
| Their beat entries | B1 | `backend/app/notifications/schedule.py` (`BEAT_SCHEDULE`) |
| `app.workers` loading several schedule and task modules | B1 | `backend/app/workers/__init__.py` |
| Response cache and rate limits | B1 | `backend/app/api/cache.py`, `backend/app/api/ratelimit.py` |
| Admin additions | B1 | `backend/app/api/admin/{sources,dashboard,ordering}.py`, `backend/app/services/admin/…` |
| Placeholders hidden from public reads | B1 | `backend/app/services/*` channel queries |
| LiveSoccerTV adapter | B2 | `backend/app/adapters/livesoccertv.py`, `livesoccertv_links.py` |
| `schedule_fetch`, health, alerts, heartbeats | B2 | `backend/app/adapters/{tasks,health,alerts}.py`, `schedule.py` |
| `ScrapeResult` v2 | B2 | `backend/app/adapters/messages.py` |
| Hosts: Kuma, backups, FCM secret mount, new env | B2 | `infra/compose/*.yml`, `infra/backup/`, `infra/scripts/`, `infra/Caddyfile` |

B2 uses B1's models and writes the source-health and placeholder columns only through `app/adapters/health.py` and `app/adapters/livesoccertv_links.py`. B1's services never import `app.adapters`.

## Celery tasks and queues

| Task name | Queue (host) | Args | Owner | Scheduled |
| --- | --- | --- | --- | --- |
| `adapters.schedule_fetch` | `imports` (VPS-2) | `source: str, manual: bool = False, window: str = "default"` (`"t60"` for LiveSoccerTV's pre-kickoff pass) | B2 | Replaces every D2 beat entry that called `adapters.fetch` directly; also sent by A13's «تشغيل الآن» |
| `adapters.fetch` | per source: `scrape_home` (home box) or `scrape` (VPS-2) | `source, start=None, targets=None` | B2 | Sent only by `schedule_fetch` |
| `adapters.ingest` | `imports` | `result: dict` (ScrapeResult v1 or v2) | B2 | Sent by `fetch` |
| `ops.heartbeat` | `maintenance`, `imports`, `notifications` | `queue: str` | B2 | Every 5 min per queue |
| `notifications.schedule_reminders` | `notifications` (VPS-2) | — | B1 | Every 5 min |
| `notifications.dispatch_due` | `notifications` | — | B1 | Every minute, and queued by the scheduler |
| `notifications.prune_outbox` | `maintenance` | — | B1 | Daily 04:30 UTC |

`api-admin` sends `adapters.schedule_fetch` by name with `celery_app.send_task("adapters.schedule_fetch", args=[name], kwargs={"manual": True}, queue="imports")`, importing no adapter code. "Running" in `SourceHealth` is `EXISTS lock:fetch:<name> OR lock:ingest:<name>`.

### `schedule_fetch(source, manual)`

1. If not `manual` and the source is paused ([data-model](../data-model.md#source-health)), log `skipped: paused` and stop.
2. For `livesoccertv`, build the targets ([research R14](../research.md#r14-livesoccertv-plan-fetch-ingest)); none → log `skipped: no_targets` and stop (no run row, no zero-items alarm).
3. Send `adapters.fetch` to the source's fetch queue (`YSSCORES_FETCH_QUEUE`, `LIVESOCCERTV_FETCH_QUEUE`, default `scrape_home`).

### Beat entries after D3 (UTC)

| Entry | Schedule | Task |
| --- | --- | --- |
| `ysscores-fixtures` | `0 */3 * * *` | `schedule_fetch("ysscores")` |
| `satair-bridge` | `30 1-22/3 * * *` | `schedule_fetch("legacy")` |
| `livesoccertv-48h` | `45 */2 * * *` | `schedule_fetch("livesoccertv")` |
| `livesoccertv-t60` | `*/10 * * * *` | `schedule_fetch("livesoccertv", window="t60")` (plans only kickoffs in 55–70 min not fetched in 30 min) |
| `prune-raw-pages` | `15 3 * * *` | unchanged |
| `heartbeat-*` | `*/5 * * * *` | `ops.heartbeat(queue)` |
| `notify-schedule` | `*/5 * * * *` | `notifications.schedule_reminders` |
| `notify-dispatch` | `* * * * *` | `notifications.dispatch_due` |
| `notify-prune` | `30 4 * * *` | `notifications.prune_outbox` |

## `ScrapeResult` v2

D2's message gains `version: 2` and `kind`. v1 messages (fixtures) are still read during the rollout.

```jsonc
{ "version": 2, "kind": "broadcasts",              // "fixtures" (ysscores, legacy) | "broadcasts" (livesoccertv)
  "source": "livesoccertv", "run_id": "…", "started_at": "…", "finished_at": "…", "fetched_on": "homebox",
  "pages": [ … as v1 … ],
  "targets": 23,                                    // broadcasts only: how many matches were planned
  "items": [ { "match_id": 48213, "match_url": "https://www.livesoccertv.com/match/…",
               "channels": [ {"name": "beIN SPORTS 1", "country": "Middle East"}, {"name": "ON Sport", "country": "Egypt"} ] } ],
  "unmatched": [ { "match_id": 48300, "why": "match_not_found" } ] }
```

## Source health writes (B2, `app/adapters/health.py`)

Called once per run, in the ingest transaction that writes `import_runs`:

| Run outcome | `consecutive_failures` | Other |
| --- | --- | --- |
| `succeeded` / `partial` with `items_found > 0` | 0 | `last_success_at = finished_at` |
| `failed` | +1 | at threshold: `breaker_opened_at = now()`, Telegram «⛔ المصدر ‹name› متوقف بعد ‹N› محاولات فاشلة» |
| zero items with pages or targets | +1 | `last_zero_alert_on` ≠ today (Cairo) → Telegram «⚠️ المصدر ‹name› لم يجد أي عناصر», then set it |

Every `record_run` also bumps the `sources` dataset in the same transaction (B1's `bump_datasets`), so A13's `ETag` changes after each run. Resume (B1 admin API) resets the four fields, bumps `sources` and queues one manual `schedule_fetch` ([data-model](../data-model.md#source-health)).

## Alerts

`app/adapters/alerts.py: send_alert(text: str) -> None`: POST `https://api.telegram.org/bot<token>/sendMessage` with `chat_id`, through the D2 fetcher's allowlist (`api.telegram.org` only), 5 s timeout; errors logged, never raised. Settings: `TELEGRAM_BOT_TOKEN`, `TELEGRAM_CHAT_ID` (VPS-2 `.env`). Without them, alerts are logged only.

## Heartbeats

`ops.heartbeat(queue)` GETs `KUMA_PUSH_URL_<QUEUE>` (`http://uptime-kuma:3001/api/push/<token>?status=up&msg=ok`) from inside VPS-2's Compose network. Backup scripts push `KUMA_PUSH_URL_BACKUP_DB`, `KUMA_PUSH_URL_BACKUP_MEDIA` and `KUMA_PUSH_URL_BACKUP_MEDIA_WEEKLY` with `status=up` or `status=down&msg=<error>`. VPS-1's media backup reaches Kuma over the VCN (`http://<VPS2_VCN_IP>:3001`).

## Host environment added on D3

| Variable | Host | Used by |
| --- | --- | --- |
| `FCM_CREDENTIALS_FILE` (+ file `/srv/secrets/fcm.json`, mode 600) | VPS-2 | `worker-notify` |
| `FCM_DRY_RUN` | VPS-2 | `worker-notify` (default false) |
| `PWA_ORIGIN` | VPS-2 | push links |
| `TELEGRAM_BOT_TOKEN`, `TELEGRAM_CHAT_ID` | VPS-2 | alerts |
| `LIVESOCCERTV_COUNTRIES`, `LIVESOCCERTV_FETCH_QUEUE`, `SOURCE_BREAKER_THRESHOLD` | VPS-2 | adapters |
| `KUMA_PUSH_URL_*` | VPS-2, VPS-1 | heartbeats |
| `RESTIC_REPOSITORY`, `RESTIC_PASSWORD`, `B2_ACCOUNT_ID`, `B2_ACCOUNT_KEY` | VPS-2, VPS-1 | backups |
| `RCLONE_CONFIG_OCI_*` (S3-compatible keys, region, endpoint, bucket) | VPS-1 | media mirror |
| `RATE_LIMIT_*`, `RESPONSE_CACHE_ENABLED` | VPS-1 | `api-public` (defaults in settings) |

All are listed in `infra/compose/example.env` with empty values and in `docs/runbooks/secrets.md`; none is committed with a value.
