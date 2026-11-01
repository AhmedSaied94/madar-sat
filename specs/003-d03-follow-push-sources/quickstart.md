# Quickstart: validating D3 · Follow, push and sources

How each lane proves its story, then the day's done check. Commands match each folder's `CLAUDE.md`; shapes are in [contracts/](contracts/), rules in [data-model.md](data-model.md). Flutter tests run on the test box with `rtest` (never on the laptop). SSH uses the `madar-vps1` / `madar-vps2` aliases.

## Prerequisites

- 002 on `master`, deployed (VPS-1, VPS-2, the home box's worker).
- The owner's one-time setup (spec Assumptions, [owner-actions](../../docs/owner-actions.md)):
  - a Firebase service account with the FCM role → `/srv/secrets/fcm.json` on VPS-2 (mode 600), `FCM_CREDENTIALS_FILE` in its `.env`;
  - the web push VAPID key pair in Firebase Cloud Messaging; the public key in `app/env/*.json`;
  - a Telegram bot and chat → `TELEGRAM_BOT_TOKEN`, `TELEGRAM_CHAT_ID` on VPS-2;
  - a Backblaze B2 bucket and application key, a restic password → both hosts' `.env`; an OCI bucket and customer secret key → VPS-1's `.env`;
  - Remote Config parameters created in the console with the bundled defaults;
  - an Android phone (Android 13+) and an iPhone with iOS ≥ 16.4.

## Lane B1: devices, notifications, cache, admin additions

```bash
cd backend
uv run ruff check . && uv run mypy --strict app && uv run pytest     # includes the FR-053 tests (research R30)
uv run python -m app.cli export-openapi && git diff --stat openapi/   # public.json and admin.json change; non-breaking vs contract-v1
uv run alembic upgrade head && uv run alembic downgrade -1 && uv run alembic upgrade head   # 0005 is reversible
```

On a local stack (`infra/compose/dev.yml`) with the snapshot loaded:

1. `POST /v1/devices` → `201` with a 43-character token. Repeat with the same `install_id` → same `device_id`, new token; the old one now gets `401`.
2. `PUT /v1/devices/me` with `satellite_ids: [<hotbird id>]` and a push token; `PUT /v1/devices/me/follows` with a team and its competition → the stored set comes back. Send an unknown team id → `422 unknown_follow_target`, and the old set is unchanged.
3. Create a match for that team with kickoff in 20 min and a Hotbird and a Nilesat channel (admin API). Run `notifications.schedule_reminders` twice → one `kickoff_reminder:<id>` row, due at kickoff − 15 min.
4. With `FCM_DRY_RUN=true` and a real registration token, run `notifications.dispatch_due` at the due time → the row is `sent`, `sent = 1`; the logged message names the Hotbird channel and has tag `match_<id>`. Remove `satellite_ids` and repeat on a new match → it names the Nilesat channel.
5. Move the kickoff 30 min later before the due time → the pending row's `due_at` moves. Set the match to `postponed` → the row is `cancelled`.
6. `GET /v1/matches?…` twice → the second is a cache hit (log `cache: hit`); edit the match in the admin → the next read misses and has a new `ETag`.
7. Hammer `/v1/matches` from one IP past 600/min → `429 rate_limited` with `Retry-After`.
8. Admin: `GET /admin/api/sources` shows health fields; `POST /sources/ysscores/pause` then `/resume`; `POST /sources/ysscores/run` twice quickly → `202`, then `409 run_in_progress`; `PUT /competitions/order` with one stale version → `409` and no change; `GET /dashboard` lists today's matches without channels.

The owner reviews the dispatcher's audience query (research R7, brief) and revision `0005` before merge.

## Lane B2: LiveSoccerTV, health, backups, monitoring

```bash
cd backend
uv run pytest tests/adapters        # livesoccertv parse on saved pages, link rules, placeholders, breaker, zero-items, schedule_fetch, message v1+v2
cd ../infra && docker compose -f compose/vps1.yml config -q && docker compose -f compose/vps2.yml config -q && shellcheck scripts/*.sh backup/*.sh
```

After the deploy:

1. `ssh madar-vps2 docker compose ps` → `uptime-kuma`, `worker-notify` healthy; one `beat`.
2. Trigger `schedule_fetch("livesoccertv")` (A13 «تشغيل الآن» or `celery call`) → an `import_runs` row with `items_found > 0`; upcoming matches of mapped teams gain `livesoccertv` links; `log.placeholders_created` lists new names, which appear in A8's placeholder filter and nowhere in `/v1`.
3. Run it again → `items_upserted = 0`, no new placeholder. Remove one of its links in A4, run again → the link stays hidden.
4. Set `LIVESOCCERTV_FETCH_QUEUE` to a queue with a broken fetcher (or block the host on the home box) and run 3 times → the breaker opens, the source is paused, and the Telegram alert arrives within 15 min (SC-005). Resume in A13 → it runs.
5. Feed a saved empty page through the ingest test harness on staging data → one zero-items alert, and no second one the same day.
6. Next morning: `ssh madar-vps2 'docker compose run --rm backup-db restic snapshots'` lists last night's snapshot; `ssh madar-vps1 'docker compose run --rm backup-media rclone lsd oci:'` shows the media copy; Kuma shows both heartbeats green (SC-004). Stop `worker-notify` for 10 min → Kuma alerts on Telegram.

## Lane A: admin

```bash
cd admin
pnpm orval                 # from B1's merged admin.json
pnpm typecheck && pnpm lint && pnpm test && pnpm build && ./scripts/check-literals.sh && ./scripts/check-token-copy.sh
```

Then `NODE_EXTRA_CA_CERTS=~/.config/madar/caddy-root.crt pnpm dev:wg` against VPS-1 over WireGuard:

1. A-F1 and A-F2: A4 still saves and shows conflicts; A3 runs on `DataTable` with its keys (J/K/X/E).
2. A5: search «الأهلي», filter missing logo, upload a logo (preview on dark and light), save → the app shows it within 60 s.
3. A6: drag a competition up with the mouse and with the keyboard (space, arrows, space) → S2's group order follows. Two browsers → the second save gets the conflict dialog.
4. A7: reorder satellites; set Nilesat's best/worst frequency and reception video (`http://` refused).
5. A8: filter Nilesat + sports; edit a channel in the drawer; «إضافة على قمر آخر» to Badr; open the placeholder filter, complete one (satellite, frequency, show on match pages) → it appears on its match in the app.
6. A10: upload a photo and a clip, play it; delete a commentator in use → refused with the usage count.
7. A13: cards show status, last success, sparkline, error rate, breaker; pause/resume and «تشغيل الآن» work; open a run's detail.
8. A2: today's matches without channels, placeholders to complete, source tiles, recent changes.
9. Screenshots at 1440 and 1024 against `Main.png`, `Teams.png`, `Competitions.png`, `Satellites.png`, `Channels.png`, `Commentators.png`, `Sources.png`, `SourceRun.png`.

## Lane M: app

```bash
cd app
flutter analyze && ./tool/check_literals.sh && ./tool/check_token_copy.sh
RTEST_HOST=flutter-tests rtest      # flutter test on the test box: onboarding resume, follow sync, device re-register, Remote Config, S0, goldens
```

On a real Android phone (dev flavor against VPS-1, then the closed-test build):

1. Fresh install → splash → S1.1. Pick فاتح; S1.2 search «الاهلي» and «الأهلي» (same results), pick two teams; quit; reopen → S1.2 with both still picked.
2. S1.3 pick Nilesat and Hotbird; S1.4 «تفعيل التنبيهات» → system dialog → allow. S9 shows both teams and «مبارياتي القادمة».
3. Ask B1 to create a test match for a followed team 20 min ahead with a Hotbird channel → the reminder arrives ~15 min before, names the Hotbird channel, and tapping it opens S3 (SC-001, Android).
4. S15: change time zone, 12/24 h, font size 1.3×, theme; every screen follows. «حذف بيانات جهازي» → confirm → the app restarts at S1.1, and B1 sees the device gone.
5. Airplane mode → offline banner with the age; first launch offline on a cleared install → no-connection screen. Raise `min_supported_build` in Remote Config → forced update on next launch; lower it back.
6. Force a test crash (debug menu in the gallery route) → it shows in Crashlytics.

On an iPhone (iOS ≥ 16.4), in Safari, open the PWA preview:

7. S1.4 shows the install guide, not a prompt. Add to Home Screen, open from the icon, reach S1.4 → «تفعيل التنبيهات» → allow. Repeat step 3 → the reminder arrives on the iPhone (SC-001, iPhone) and opens `/match/<id>`.

Screens are compared with `Splash.png`, `Onb-*.png`, `Favorites.png`, `Settings.png`, `More.png`, `Sys-*.png`, `Matches-Banners.png` in both themes.

## Done check (spec SC-009)

Word for word from delivery-plan Appendix A, row 003:

> A kickoff reminder arrives on Android and on an installed iPhone PWA; LiveSoccerTV adds channels to upcoming matches; all MVP admin entities editable; one nightly backup completed; onboarding → follow → favorites works

| Clause | Proven by |
| --- | --- |
| Reminder on Android and an installed iPhone PWA | Lane M steps 3 and 7 |
| LiveSoccerTV adds channels | Lane B2 step 2 |
| All MVP admin entities editable | Lane A steps 2–6 (plus D2's A4 for matches) |
| One nightly backup completed | Lane B2 step 6 |
| Onboarding → follow → favorites | Lane M steps 1–2 |
