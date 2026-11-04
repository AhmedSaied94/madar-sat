# Quickstart: D5 validation

How to prove the day's work. Commands use the SSH aliases `madar-vps1` and `madar-vps2`, and the runbooks hold the details.

## Prerequisites

- Revision `0007` applied. Lanes branched from a `master` holding the O7 doc edits and constitution 1.3.0.
- A live match on the day's fixtures for the capture and the done check.
- `TELEGRAM_BOT_TOKEN` and `TELEGRAM_CHAT_ID` set on VPS-2.

## B1: capture

```bash
ssh madar-vps2 'docker compose -f /srv/madar/infra/compose/vps2.yml run --rm worker-live \
  python -m app.cli capture-live --filgoal <id> --yallakora <id> --minutes 130'
```

Expect saved pages under `/srv/raw/capture/<date>/` covering pre-match to full time, and `capture-report.md` with the fields, status strings, update delay, `LIVE_CONFIRM_WAIT_S` and the page caps. If a source is unusable, stop and tell the owner (spec Edge Cases).

## B1: poller

```bash
cd backend
uv run pytest tests/live -q        # parsers on the captured pages; every SD §6.7 row
```

| Check | Expect |
|---|---|
| Replay: both agree | The score updates at once |
| Replay: one updated | No change until the other agrees, or `LIVE_CONFIRM_WAIT_S` then one alert |
| Replay: one source down | The new score after 2 polls |
| Replay: changed format | That source stops, one alert, 0 wrong scores (SC-003) |
| Replay: both down | `estimated: true`, no score or minute, one alert |
| Replay: recovery | The confirmed score returns, one recovery alert |
| Manual status | The feed changes nothing until it's cleared |
| Quiet day | 0 requests to either source (SC-004) |
| Watchdog | Stop `worker-live` mid-match: within 7 min the row is on the clock and an alert fires |
| Long match | A `feed` match at kickoff + 170 min stays polled and in `/v1/live`. At + 210 min with no final state it moves to the clock with one alert |
| Backoff and alarm | A 429 skips that host until its backoff ends. An empty list page with a match in the window opens one `format:` alert |

On the live host, during a match:

```bash
curl -s https://api.<VPS1_IP>.sslip.io/v1/live | jq '.data[] | {match_id,status,estimated,minute,score}'
```

Compare status and score with the broadcast from kickoff to full time (SC-001). Record each goal's time on the broadcast, its first source appearance and its confirmation, and check it reaches the app within 45 s of confirmation (SC-005).

## B1: load re-run (after the owner's resize)

Follow [load-testing](../../docs/runbooks/load-testing.md), and add the result under "Re-runs" in `docs/load-tests/2026-11-03-mvp.md`. Expect 004's targets met (SC-010) and `effective: []` afterwards. If it fails, B2 builds the Caddy cache and the test runs again.

## B2: YallaKora and the queue

```bash
cd backend
uv run pytest tests/adapters/test_yallakora.py tests/adapters/test_resolve.py -q
ssh madar-vps2 'docker compose -f /srv/madar/infra/compose/vps2.yml exec worker-imports celery -A app.workers call adapters.schedule_fetch --args "[\"yallakora\"]"'
```

Expect an `import_runs` row with counts, Egyptian broadcasters on matches, and in the database: queue rows for unmatched names, with 0 new teams, competitions or channels from this source (SC-006). Repeat the run: `seen_count` rises and no duplicate appears. Check `worker-live` is healthy and Kuma's `live` heartbeat is green.

## Lane A

```bash
cd admin
pnpm orval && pnpm typecheck && pnpm lint && pnpm test && pnpm build
pnpm e2e
```

Over WireGuard at `https://10.8.0.1`:

1. **A13 queue:** map a name and see the next import use the alias (SC-007). Create one through the form. Ignore one, then run the import and see it stay out. For a shared name, the picker is shown.
2. **A13 Live poller card:** it shows the sources' state. Pause it: live matches go to the estimate with no alert.
3. **Run detail:** open a failed run. Log, counts and errors show, and the raw page appears as plain text. Paste-testing with a `<script>` fixture shows text and runs nothing.
4. **A9:** create a rights holder with competitions, carriages and one primary. See it in `/v1/competitions/<id>`. Two primaries are refused. Drag the order.
5. Compare with the boards at 1440 and check 1024.

## Lane M

```bash
cd app
RTEST_HOST=flutter-tests rtest
flutter analyze && ./tool/check_literals.sh && ./tool/check_token_copy.sh
```

On a real Android phone, in both themes (SC-008):

1. From S3, tap a channel: S6 opens as a sheet with the frequency showing and no tap needed, other carriages, 7 days of matches, and no history section. Copy works, and follow survives a restart.
2. From S3's hero or S9, open S7: both tabs, follow, and the empty state on a team with no fixtures.
3. From S2, open S8: both tabs grouped by local date, and rights rows with no chevron.
4. Airplane mode: a cached screen shows its age, and an uncached one shows the no-connection state.
5. A match on `feed` shows a real score and minute. An estimated match shows neither. `live_center` is off.

## Done check

*"A real live match updates status and score from FilGoal, cross-checked with YallaKora (O7); YallaKora imports; unresolved names visible in the admin; S6, S7, S8 on a device"*

Replay alone doesn't pass it. It needs a real match on the deployed hosts, after the capture's match. If no later kickoff fits today, it moves to the next match day.
