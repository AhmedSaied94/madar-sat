# Source alerts

What the importer alerts mean, and what to do about them (Lane B2's T085, research R17, SC-005).
Alerts go to one Telegram chat through a bot, and the same chat receives Uptime Kuma's notifications
([uptime-kuma.md](uptime-kuma.md)).

## The two settings

| Variable | Host | What it is |
| --- | --- | --- |
| `TELEGRAM_BOT_TOKEN` | VPS-2 | The bot's token from @BotFather (`123456789:AA…`). Never committed. |
| `TELEGRAM_CHAT_ID` | VPS-2 | The chat or group the bot posts to (a negative number for a group). |

Without both, alerts are written to the worker's log and not sent, so a developer's stack stays
quiet. After setting them, restart `worker-imports` (that is the worker that ingests and therefore
alerts):

```sh
ssh -J ubuntu@10.8.0.1 ubuntu@"$VPS2_VCN_IP" \
  'sudo -iu deploy env IMAGE_TAG=$(cat /srv/madar/current_tag) docker compose --env-file /srv/madar/.env \
   -f /srv/madar/infra/compose/vps2.yml --profile workers up -d worker-imports'
```

Test it from inside the worker, which proves the token, the chat id and the network in one step:

```sh
ssh -J ubuntu@10.8.0.1 ubuntu@"$VPS2_VCN_IP" \
  'sudo -iu deploy docker compose -p madar exec -T worker-imports python -c \
   "from app.adapters.alerts import send_alert; send_alert(\"اختبار تنبيهات مدار\")"'
```

You should receive the message within a few seconds. A `[403]` in the log means the bot was never
added to the chat; `[400] chat not found` means the chat id is wrong (a group id starts with `-`).

## ⛔ المصدر ‹name› متوقف بعد ‹N› محاولات فاشلة

The source's **circuit breaker** opened: N consecutive runs failed (default 3,
`SOURCE_BREAKER_THRESHOLD`). The source is now paused in `sources.breaker_opened_at`, so
`schedule_fetch` skips it entirely until someone resumes it; it does not reset on its own.

1. Read the last runs: A13, or
   `select started_at, status, error, http_errors from import_runs where source = '<name>' order by started_at desc limit 5`.
2. Read the saved pages of a failed run: `import_runs.raw_path` on VPS-2, with `run.json` beside
   them ([imports-and-sources.md](imports-and-sources.md#read-what-a-run-did)).
3. Fix the cause: a changed page is `layout_changed` (the adapter needs a new parse and a new saved
   page in `backend/tests/fixtures/<source>/`); a `403`/`429` is the site blocking the host (move
   the fetch to the other host, below); a `fetch_failed` 404 is usually a moved URL.
4. Resume it in A13 («استئناف»). That clears the breaker and the count and queues one manual run,
   so you see at once whether the fix worked.

Do not clear `breaker_opened_at` by hand in SQL: A13 also resets `consecutive_failures`,
`paused_until` and bumps the `sources` dataset, which is what makes A13's and A2's cards agree.

## ⚠️ المصدر ‹name› لم يجد أي عناصر

A run fetched pages (or planned matches) and found **nothing**: the page shape changed, the site
answered a soft error, or the source is genuinely empty. It counts as one failure and it alerts at
most once per source per Cairo day (`last_zero_alert_on`), so a quiet night does not fill the chat.

1. Check whether the source really has nothing: open its page in a browser, or read the run's saved
   pages.
2. If it does have data, this is a parse problem: treat it as `layout_changed` above.

A zero-items run that had **no pages and no targets** is not an alert: LiveSoccerTV with nothing to
plan is a quiet result, not a fault.

## Moving a fetch to the other host

If the site blocks the host, move the fetch rather than disabling the source:

1. On VPS-2, set `YSSCORES_FETCH_QUEUE=scrape` (or `LIVESOCCERTV_FETCH_QUEUE=scrape`) in
   `/srv/madar/.env`.
2. Restart the VPS-2 services ([imports-and-sources.md](imports-and-sources.md#switch-where-a-source-fetches)).
3. Resume the source in A13 and watch the next run.

The queue name is the only thing that changes: `schedule_fetch` reads it on every pass.

## Alerts that are not about a source

| Message | From | Meaning |
| --- | --- | --- |
| `🔴 <monitor> is DOWN` / `🟢 … is UP` | Uptime Kuma | An HTTP check or a queue heartbeat went quiet. [uptime-kuma.md](uptime-kuma.md) says which monitor means what. |
| Nothing at all, while runs are failing | — | The bot is not configured, or `worker-imports` is down: check `docker compose logs worker-imports \| grep alert`. |
