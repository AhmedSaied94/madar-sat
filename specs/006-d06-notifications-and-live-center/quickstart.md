# Quickstart: D6 validation

How to prove the day's work. Commands use the SSH aliases `madar-vps1` and `madar-vps2`, and the runbooks hold the details.

## Prerequisites

- Revision `0008` applied, and lanes branched from a `master` holding this spec.
- `FCM_CREDENTIALS_FILE` on VPS-2, and `FCM_DRY_RUN` off for the live checks.
- A real match on the day's fixtures for the done check. Check first.
- `TELEGRAM_BOT_TOKEN` and `TELEGRAM_CHAT_ID` on VPS-2.

## Lane B1

```bash
cd backend
uv run pytest tests/notifications tests/live/test_replay.py tests/admin tests/contract -q
uv run alembic upgrade head && uv run alembic downgrade -1 && uv run alembic upgrade head
uv run python -m app.cli export-openapi && git diff --exit-code openapi/
```

| Check | Expect |
|---|---|
| Replay of the capture | 58 goal messages and 0 corrections. Mouloudia gives only 1–0 at +240 s (SC-001) |
| Two overlapping polls, a retry, a restart | The same rows: no device gets one event twice (SC-003) |
| First evaluation with a match in play | A baseline and no message (FR-002) |
| A manual status holding | No message, and the baseline moves |
| A score falling after a goal was sent | One `goal_correction`, and generation + 1 |
| An editor lowering a score below what was pushed, live or finished | One `goal_correction`, and no second one from the next poll |
| A score falling with nothing sent | No row |
| Pushed 2–0, with sources at 2–1 and 1–1 | An away message saying 2–1, never 1–1 |
| A match finished at the limit | No `final_score`, until an editor finishes it by hand |
| Every type's message | Exact text, isolates and digits, compared with [the catalog](contracts/push-pipeline.md#copy) |
| Audience, per type | Followers as SD §6.8, master off gives 0, a type off gives 0, no prefs gives the defaults (SC-004) |
| A row due after its limit | Cancelled, with its reason (FR-019) |
| A 50,000-device row plus a goal row | The goal goes first, and within 60 s of being due (SC-002) |
| `PUSH_TYPES_OFF=goal` | Cancelled with `type_off`. A frequency row still writes history |
| A channel added and removed inside the hold | `no_net_change` |
| A frequency typo fixed inside the hold | One message with the fixed value. Set back: nothing, and A17 has both saves |
| A16 routes and the password change | No audit row, response or log line contains `password_hash` or a password (SC-011) |
| A flagged account | `403 password_change_required` on every route except `auth/*` |
| `oasdiff` on `/v1` | Nothing breaking |

## Lane B2

### Before Lane B2 builds on API-Football

With the account, read the docs in a browser and make one request from the host. The key stays out of the command line and history, because `curl` and `grep` read it from standard input. The response is saved, because Lane B2's `parse` tests are written from it (T061):

```bash
ssh madar-vps2
sudo sed -n 's/^API_FOOTBALL_KEY=/x-apisports-key: /p' /srv/madar/.env | \
  curl -s -H @- -o /tmp/af-fixtures.json "https://v3.football.api-sports.io/fixtures?date=$(date -u +%F)&timezone=UTC"
jq '{errors, results, first: .response[0].league}' /tmp/af-fixtures.json

# must print 0: the key isn't in the saved response
sudo sed -n 's/^API_FOOTBALL_KEY=//p' /srv/madar/.env | grep -c -F -f - /tmp/af-fixtures.json
```

If it prints 0, copy the file to the repo for Lane B2, then remove it from the host:

```bash
# from your laptop, in the repo
scp madar-vps2:/tmp/af-fixtures.json backend/tests/fixtures/api_football/fixtures-$(date -u +%F).json
ssh madar-vps2 rm /tmp/af-fixtures.json
```

| Check | If it fails |
|---|---|
| The free plan returns current-season fixtures for today | The adapter ships off, and the decision is recorded |
| `date` works without `league` | Use `date` + `league`, which is 24 requests a day and fits |
| The daily reset's time, and its header | Change the counter's date to match |
| What a refused request looks like | Update `parse`'s failure test |
| The terms allow showing fixtures in a free app | The owner decides |

### Tests

```bash
cd backend
uv run pytest tests/adapters/test_sporteventz.py tests/adapters/test_api_football.py tests/adapters/test_upsert.py -q
```

| Check | Expect |
|---|---|
| sporteventz, run twice from saved pages | Each event is one match with its sport and broadcaster entries, with no duplicates |
| A match with `broadcasts` locked | Its entries unchanged |
| A football and a basketball row with the same names and date | Never merge |
| sporteventz names | Text on the match, and `unresolved_names` doesn't grow |
| A valid empty response | No alarm for 7 days. A missing `Records` key alarms at once |
| API-Football over a simulated day | Requests never pass the budget, and the run is `stopped` (SC-009) |
| Redis failing | 0 requests, `failed`, `budget_unreadable` |
| No key | 0 requests, `stopped`, `not_configured`, no alarm |
| `errors` in a 200 | `failed`, not zero items |
| A search of logs, raw pages and run details | No key value |

### On the host

```bash
# VPS-2, as deploy
cd /srv/madar/infra
export IMAGE_TAG=$(cat /srv/madar/current_tag)
dc() { docker compose --env-file /srv/madar/.env -f compose/vps2.yml "$@"; }

dc exec worker-imports celery -A app.workers call adapters.schedule_fetch --args '["sporteventz"]'
dc exec -T worker-imports python -m app.cli repair-matches sport
```

The first gives a succeeded run on A13. The second lists rows with a sporteventz ID labelled `football`, and changes nothing.

To correct them, the owner builds a map from the snapshot's `sport`, as JSON of `{"<match id>": "<sport>"}`, and copies it to `/tmp/sport-map.json` on VPS-2. It isn't committed. A row with no sport in the snapshot stays out of the map, and stays `football`.

```bash
# does the work and rolls it back
dc exec -T worker-imports python -m app.cli repair-matches sport - < /tmp/sport-map.json

# then, the same with the change made
dc exec -T worker-imports python -m app.cli repair-matches sport --apply - < /tmp/sport-map.json
```

Football lists and `/v1/live` return 0 other-sport rows (SC-010).

## Lane A

```bash
cd admin
pnpm test && pnpm typecheck && pnpm build
```

Against the mock, then the real API on `wg0`:

| Check | Expect |
|---|---|
| A15, as `editor` | Reads the log, with no composer. The composer's route is refused by the server |
| A16 and A17, as `editor` | Hidden, a direct address shows not-permitted, and the server refuses |
| A new account | Temporary password shown once, and the first login goes to the change step |
| Deactivating an account | Its next request is refused (SC-011) |
| Yourself, or the last admin | Refused, with the clear message |
| An old audit row | Shows raw, with no crash |
| Two admins editing one account | `ConflictDialog` |
| A8 | «سجل التردد» shows old, new and who |

## Lane M

Run with `RTEST_HOST=flutter-tests rtest`, from `app/`. If the box is unreachable, tell the owner, and don't fall back to a local run.

```bash
cd app
RTEST_HOST=flutter-tests rtest test/features/match_detail test/features/settings test/features/notifications test/core/platform test/goldens
```

| Check | Expect |
|---|---|
| `live_center` off | S3's goldens unchanged (SC-013) |
| Timeline fixtures | Newest first, home on the right, markers, labels |
| 2–0 with one known goal | No running score |
| Estimated | Only the note |
| `event_count` rising | One re-read, and the row appears (SC-006) |
| A push while the app is open | A banner, with no navigation |
| `/channel/5`, `/match/5?section=channels` | S6, and S3 at its channels |
| `/match/5/x`, `/evil`, `//host` | The app opens and goes nowhere |
| S15, each platform state | Switches, the steps, or the install link |
| S15 offline | The change reaches the server on reconnect |

## Deploy order

Automatic types start for every follower when B1's push PR deploys, PWA users included, with no tester stage and no wait for a new app (FR-021). Every merge to `master` deploys (`backend.yml`).

1. **B1's contract PR merges first.** It's safe on its own: its dispatcher still claims only reminders.
2. **B1's push PR merges, and every automatic type is on.** The owner reviews the audience queries first (T037). A match in play at this moment sends nothing for goals already scored, because the poller's first evaluation only sets the baseline (FR-002). Check the day's fixtures, and merge at a time you can watch the first pushes.
3. **The PWA and the Android test build go out as soon as Lane M finishes.** The PWA reaches users on their next load. Until a device updates, a push received with the app open navigates it, and it has no S15 switches ([the spec's Assumptions](spec.md#assumptions)).

**The off switch.** Keep it to hand for the first match night. Add the types to `PUSH_TYPES_OFF` in VPS-2's `.env`, then recreate `worker-notify` (`dc up -d worker-notify`, with `dc` and `IMAGE_TAG` set as in [On the host](#on-the-host)). To turn them back on, remove them and recreate it again.

## The test channel

Editing a real channel shows fans a wrong frequency at once, and pushes it to every follower when the hold ends. So every check that changes a frequency uses a channel made for it:

1. Create a channel in A8 for the check, with a frequency, and name it so that it's clearly a test.
2. Follow it from your own device or devices, by opening `/channel/<id>` in the app.
3. Check who it would reach: `GET notifications/reach?kind=channel&id=<id>`, or A15's composer with that channel as the audience. **It must equal your own devices.** If it's more, stop.
4. When the check is done, delete the channel in A8.

## The done check (Appendix A row 006)

| Item | How | Who |
|---|---|---|
| A goal push arrives with the correct score | Follow a team on a phone and an installed iPhone PWA during a real match. Compare with the broadcast (SC-001, SC-012) | Owner |
| The live center shows events | With `live_center` on for testers, S3 during that match (SC-006) | Owner |
| A frequency change pushes to followers | Use [the test channel](#the-test-channel). Change its frequency in A8, and wait out the hold (SC-005). Set it back afterwards, which is a second change and pushes again, to your devices only | Owner |
| The composer sends a test push | Save the device ID from S15. Send from A15, and only that device gets it (SC-007) | Owner |
| The audit diff is visible | Open the frequency save in A17, with its push's counts | Owner |

Also check that all types read correctly on both platforms (SC-012). SC-014 is proved by a test with a fake sender refusing every send, which gives one alert and one on recovery. SC-008 is a run with `FCM_DRY_RUN` on, against seeded devices, recorded in `load-testing.md`.
