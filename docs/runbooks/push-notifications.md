# Push notifications

How the reminder gets made and sent, how to set up and rotate the FCM service account, how to read the outbox, and what to do when a row fails. Background: system-design §6.8, constitution VII, `specs/003-d03-follow-push-sources/` research R6–R9, and `backend/app/notifications/`.

Since D6 every type goes out: kickoff reminder, match started, goal, final score, channels updated, frequency changed and announcements (composer). The goal bar, the five-minute holds, lateness and the off switch are in the sections below; the pipeline is `backend/app/notifications/`.

## How a reminder is made

Three steps, no HTTP request in the path (FR-007):

1. **Schedule** — `notifications.schedule_reminders` on the `notifications` queue, every 5 minutes (`notify-schedule`). It takes `lock:notifications:schedule` (4 min) so two beats cannot double-schedule, selects matches with `kickoff_at` in `(now, now + 24 h]`, `time_tbd = false`, status `scheduled`, that have at least one follower (home team, away team, competition or the match), and upserts one row per match:

   ```text
   type       = kickoff_reminder
   dedupe_key = kickoff_reminder:<match_id>          (unique)
   due_at     = greatest(kickoff_at − 15 min, now)
   audience   = {"kind": "match_followers", "match_id": <id>}
   ```

   `ON CONFLICT (dedupe_key) DO UPDATE … WHERE status IN ('pending', 'cancelled')`, so a moved kickoff moves a pending row and a sent or failed one is never touched or duplicated; a row that was `cancelled` and whose match qualifies again (a postponed match that is scheduled again, a TBD match that gets a time, a kickoff that moved past 24 h and back) goes back to `pending` with the new `due_at`. A second statement cancels pending rows whose match became `time_tbd`, `postponed`, `cancelled`, `abandoned`, `live` or `finished`, whose kickoff has already passed, or whose kickoff moved past 24 h.

2. **Dispatch** — `notifications.dispatch_due` on `notifications`, every minute (`notify-dispatch`) and queued by the scheduler when a row is due now. It reclaims rows stuck in `sending` for more than 10 minutes, claims up to 10 due rows with `FOR UPDATE SKIP LOCKED`, and for each row resolves the audience in pages of 500 with one `SELECT DISTINCT` (`AUDIENCE` in `backend/app/notifications/dispatcher.py`), builds each device's message from the match's visible links and the device's satellites, sends the page through `firebase_admin.messaging.send_each`, and records `sent`, `failed` and `cursor_device_id`. A row whose kickoff has passed, or whose match is `live` or `finished`, is `cancelled` instead of sent: a late reminder never says a started match begins in a minute. A whole-call failure puts the row back to `pending` with its cursor, so a retry resumes where it stopped, and every row claimed behind it goes back to `pending` too (no row is stranded in `sending`). The row's `attempts` column counts those failures; at 5 the row is `failed` and is never claimed again. A token FCM answers `UNREGISTERED` for (or `INVALID_ARGUMENT` naming the registration token) is set to `NULL`, so the device stops receiving. A transient per-message error (503, 500, 429, a timeout) is not final: the sender sends the message again for that device alone, after 1, 2 and 4 seconds (`RETRY_DELAYS` in `sender.py`), and never to a device that already got it. If FCM took nobody on a page after those re-sends, the page is not recorded and the row goes back to `pending` at its cursor through the same `attempts` path as a whole-call failure (the row is never `sent`, and the next minute's dispatch tries the page again). If some devices on the page were delivered and some are still unreachable after the re-sends, the page cannot be repeated without messaging the delivered ones twice, so the unreachable remainder is counted in `failed` and logged (`fcm_messages_unreachable` at WARNING, `push_page_failed` at ERROR) and the row continues; those devices do not get the reminder, which is a known limit. Any other per-message error (a bad message field, for one) counts as `failed` at once and logs `fcm_message_failed` at ERROR; the token is left alone.

3. **Prune** — `notifications.prune_outbox` on `maintenance`, daily at 04:30 UTC (`notify-prune`). Deletes `sent`, `failed` and `cancelled` rows older than 30 days.

Only `app/notifications/sender.py` talks to FCM. Producers only insert outbox rows.

## The FCM service account

1. **Create the key.** In the Firebase console for the project, *Project settings → Service accounts → Generate new private key*. A JSON file downloads once. Never commit it, paste it, or send it in chat (`gitleaks.yml` scans history).
2. **Install it on VPS-2** (the only host that sends). With WireGuard up, copy it with the `madar-vps2` SSH alias ([private-network.md](private-network.md)); `scp` keeps the file's mode 600:

   ```bash
   scp ./fcm.json madar-vps2:/tmp/fcm.json
   ssh -t madar-vps2
   sudo install -d -m 700 -o 10001 -g 10001 /srv/secrets
   sudo install -m 600 -o 10001 -g 10001 /tmp/fcm.json /srv/secrets/fcm.json
   sudo shred -u /tmp/fcm.json
   ```

   `worker-notify` runs as uid 10001 with `cap_drop: ALL`, and `/srv/secrets` is that uid's, mode
   700 (`bootstrap-vps.sh`), so the key is installed **as root** with that owner: the same command
   run as `deploy` fails with EPERM, and a `deploy`-owned key is unreadable to the worker. Prove it:

   ```bash
   docker compose exec worker-notify test -r /srv/secrets/fcm.json && echo 'the key is readable'
   ```

3. **Point the worker at it.** In VPS-2's `/srv/madar/.env`:

   ```text
   FCM_CREDENTIALS_FILE=/srv/secrets/fcm.json
   FCM_DRY_RUN=false
   PWA_ORIGIN=https://<PWA_PREVIEW_HOST>
   ```

   `infra/compose/vps2.yml` mounts that one file read-only into `worker-notify` and no other service. `PWA_ORIGIN` is the web push link's origin (`<PWA_ORIGIN>/match/<id>`): the origin the installed PWA is served from. Until D4 that is the Firebase Hosting preview channel `master` above ([firebase-hosting.md](firebase-hosting.md)); when the first `web-v*` release reaches the live channel, set it to `https://<PWA_HOST>` and recreate `worker-notify` (the `app.<VPS1_IP>.sslip.io` mirror also arrives on D4). A value with a wrong origin sends users to a dead link, and a plain `http://` value is refused at startup (FCM rejects every web message whose `fcm_options.link` is not https).

4. **Restart and check.** On VPS-2:

   ```bash
   dc up -d --force-recreate worker-notify
   dc logs --tail=50 worker-notify | grep -F 'fcm: initialized'
   ```

   The line appears the first time the first message is sent, not at boot: the SDK is imported lazily.

5. **Rotate.** Generate a new key, install it as above (over the old file), `dc up -d --force-recreate worker-notify`. Firestore keeps working: the key is only used by `firebase-admin`. Revoke the old key in *Service accounts → Manage keys* once a reminder has gone through.

`FCM_DRY_RUN=true` uses FCM's own dry run: messages are validated and no notification is delivered. Use it on a staging check, then set it back and restart.

## The types the producers write

| Row | Comes from | `due_at` | Audience |
|---|---|---|---|
| `match_started` | the poller, when a feed match turns live within 15 min of kickoff | now | `match_core` |
| `goal` | the poller's goal bar, one per side per rise | now | `match_core` |
| `goal` with `payload.kind = correction` | accepted score below what was pushed | now | `match_core` |
| `final_score` | a feed finish with a real score, or an editor's `finished` | now | `match_core` |
| `channels_updated` | a link added or removed (A4 or an importer) | first change + 5 min | `match_followers`, `match_only` for a first channel |
| `frequency_changed` | A8's frequency save | first save + 5 min | `channel` |
| `announcement` | A15's composer, or a test send | now or `send_at` | as chosen, or one `device` |

Every row is inserted in the transaction of the change behind it, with `ON CONFLICT (dedupe_key) DO NOTHING`:

```text
match_started:<match>
goal:<match>:<generation>:<side>:<value>
goal_correction:<match>:<generation>
final_score:<match>
channels_updated:<match>:<first change id>
frequency_changed:<channel>:<first save's audit id>
announcement:<uuid>            test:<uuid>
```

A push written by an admin save carries `audit_log_id`, which is how A17 shows the counts behind that
save. After commit the poller or the save queues `dispatch_due`; nothing waits for the next beat.

## The goal bar, the holds and lateness

The bar is pure (`app/notifications/goal_bar.py`, judged per side, never on the shoot-out). A value
above what was pushed goes out only when either two sources agree on it (second-highest, capped at the
accepted score and never below what was pushed), or one source has shown it without a break for three
minutes. The first evaluation of a match stores the baseline and says nothing, so a match that was
already in play when we started following it never sends a backfill.

`channels_updated` and `frequency_changed` wait five minutes from the first change. At dispatch the
frequency hold compares the stored `old` value with the channel now: equal or incomplete cancels with
`no_net_change`. A typo fixed inside the hold therefore leaves no history row and no badge.

Lateness (FR-019): a `goal` or `match_started` older than 15 minutes or whose match finished,
`final_score` or a correction older than 2 hours, `channels_updated` whose match finished, and a
scheduled announcement more than 2 hours late are all cancelled with a reason instead of sent. A goal
whose side has since fallen below the pushed value is cancelled with `score_fell`. A test send never
goes late.

## The off switch (under a minute)

`PUSH_TYPES_OFF` in VPS-2's `/srv/madar/.env` is a comma-separated list of types; a listed type's rows
are cancelled with `error = type_off` and nothing is sent. An unknown name logs an error and is
ignored. `kickoff_reminder` can be listed too.

The key may be missing from `.env` (it is not set before the first match night), so the block
replaces the line when it is there and appends it when it isn't. Only a recreate makes the container
read `.env` again (`restart` keeps the old environment), and the last line fails loudly unless
`worker-notify` itself now reports the list.

```bash
ssh madar-vps2
sudo -iu deploy                 # the rest runs in the deploy shell: /srv/madar/.env is mode 600, owner deploy
cd /srv/madar/infra
export IMAGE_TAG=$(cat /srv/madar/current_tag 2>/dev/null || echo none)
dc() { docker compose --env-file /srv/madar/.env -f compose/vps2.yml "$@"; }

OFF=goal,match_started          # the types to stop, comma-separated, no spaces
if grep -q '^PUSH_TYPES_OFF=' /srv/madar/.env; then
  sed -i "s/^PUSH_TYPES_OFF=.*/PUSH_TYPES_OFF=$OFF/" /srv/madar/.env
else
  printf 'PUSH_TYPES_OFF=%s\n' "$OFF" >> /srv/madar/.env
fi
grep '^PUSH_TYPES_OFF=' /srv/madar/.env                 # exactly one line, with the list
dc up -d --no-deps --force-recreate worker-notify      # re-reads .env; `restart` would not
got=$(dc exec -T worker-notify printenv PUSH_TYPES_OFF)
[ -n "$got" ] && [ "$got" = "$OFF" ] && echo "OFF: $got" || { echo "NOT APPLIED: worker-notify has '$got'" >&2; false; }
```

To turn every type back on, empty the value in the same shell and check that it is empty:

```bash
sed -i 's/^PUSH_TYPES_OFF=.*/PUSH_TYPES_OFF=/' /srv/madar/.env
dc up -d --no-deps --force-recreate worker-notify
got=$(dc exec -T worker-notify printenv PUSH_TYPES_OFF)
[ -z "$got" ] && echo "every type on" || { echo "STILL OFF: $got" >&2; false; }
```

History still happens while the switch is on: a frequency hold that ends writes its
`channel_frequency_changes` row and is only then cancelled, so turning pushes back off and on never
loses what followers were told.

## The composer and the test device

A15 composes from the admin app; the API is `POST /admin/api/notifications/announcements`, and a test
send is `POST /admin/api/notifications/test`. The route is built by the server from the chosen target
(`/`, `/match/<id>`, `/channel/<id>`) and a route as text is refused, as is a card-sharing label
(`422 text_not_allowed`) or a `send_at` in the past (`422 send_at_in_past`).

Before a test send, save the device in A15's "test device" row (`PUT /admin/api/notifications/test-device`,
`If-Match` required). The test send ignores that device's preferences, so it proves the FCM path
without messaging fans; a `422 test_device_not_set` or `test_device_no_token` means exactly that.

Cancelling a pending announcement (`POST /admin/api/notifications/{id}/cancel`, `If-Match` required)
sets `status = cancelled` and `error = admin`; a sent row cannot be cancelled (`409 notification_not_cancellable`).

## The owner's audience review

The audience query is `AUDIENCE` in `backend/app/notifications/dispatcher.py`. It is one statement, bound parameters only, and reads as:

- `devices` joined to `device_follows`, `DISTINCT` on the device row;
- a device with a push token, `id > :cursor` (the page cursor), and any follow that is the match, the competition, the home team or the away team;
- `COALESCE((prefs #>> '{types,kickoff_reminder,on}')::boolean, true)`: a device that switched the reminder off is not sent to. A device that never sent prefs is on (the D3 default).

What to check when you review it: no string interpolation, no write, one device per row, and that it cannot return a device twice (the `DISTINCT`).

## The failure alert

When a row finishes `failed`, or a finished row with at least 10 devices had more than 20 % failures,
the `push` problem opens in `live_problems` (A13 and the alert channel). The next finished row under
that rate closes it. Test sends and cancelled rows never alert, and dead tokens are not failures.

## Read the outbox

In the VPS-1 `psql` shell ([database-migrations.md "Read the state"](database-migrations.md#read-the-state)):

```sql
-- what is waiting and what went out in the last day
SELECT status, count(*) FROM notification_outbox
 WHERE created_at > now() - interval '1 day' GROUP BY status ORDER BY status;

-- the newest rows, with how many devices each reached
SELECT id, dedupe_key, status, due_at, attempts, sent, failed, cursor_device_id, sent_at
  FROM notification_outbox ORDER BY id DESC LIMIT 20;

-- why rows were cancelled or failed (error, with the short reason)
SELECT id, type, status, error, sent, failed FROM notification_outbox
 WHERE status IN ('failed', 'cancelled') AND created_at > now() - interval '1 day' ORDER BY id DESC;

-- stuck in sending: the worker died mid-row
SELECT id, claimed_at, cursor_device_id FROM notification_outbox
 WHERE status = 'sending' AND claimed_at < now() - interval '10 minutes';
```

A stuck row returns to `pending` on the next dispatch (after 10 minutes) and resumes at `cursor_device_id`.

## Re-send a failed row safely

The notification tag is `match_<id>`: a repeat replaces the notification on the device instead of stacking, so re-sending is safe. To start the row over from the first device:

```sql
UPDATE notification_outbox
   SET status = 'pending', claimed_at = NULL, cursor_device_id = 0,
       attempts = 0, failed = 0, sent_at = NULL, due_at = now()
 WHERE id = <id> AND status = 'failed';
```

`attempts = 0` gives the row its five tries again; without it the first failure marks it `failed` once more.

Then let the next `notify-dispatch` (≤ 1 minute) send it, or run it by hand: `dc exec worker-notify celery -A app.workers call notifications.dispatch_due`. Keep `cursor_device_id` instead of resetting it if only the tail failed; the devices before the cursor already received it.

Do not edit a `sent` row: the scheduler will not create a second one, so clearing it is the only way to send a match twice — and it would notify everyone again.

## When a reminder doesn't arrive

1. `SELECT * FROM notification_outbox ORDER BY id DESC LIMIT 5;` — is there a row? If not, nobody followed the match by the last schedule run before kickoff (`device_follows`), or the match is `time_tbd` / postponed / cancelled / outside 24 h. A follow's `created_at` doesn't date it: the app replaces the device's whole set on every change, so all its rows get the time of the last change.
2. Is `due_at` in the past and `status = 'pending'`? Look for `notifications.dispatch_due` in VPS-2's worker logs, and whether `beat` runs at all ([workers.md](workers.md)).
3. `status = 'failed'` with `error`/`failed` counts: the FCM credentials are wrong or the key rotated, or FCM could not take a page for five attempts in a row (an outage; the re-send SQL above is safe once it is back). A `sent` row with a non-zero `failed` is a partial outage: see the dispatch step above. Check `dc logs worker-notify | grep -F 'fcm'`.
4. A device with `push_token = NULL` was told `UNREGISTERED`: FCM says that token no longer exists. The app only sends a token when FCM gives it a new one, so the device stays silent until then; check the device row with `SELECT id, platform, last_seen_at, push_token FROM devices WHERE id = <id>` and ask the user to reopen the app, which re-registers the device (a new `POST /v1/devices` with the same `install_id` keeps the row and rotates its token).
5. `FCM_DRY_RUN=true` on the host means nothing is delivered. Check the value in `/srv/madar/.env`.
6. Android devices with no token at all (`SELECT platform, count(*), count(push_token) FROM devices GROUP BY 1`): registration never reached the server, and the dispatcher skips them. `firebase_messaging_installation_id_enabled` must be `true` in `app/android/app/src/main/AndroidManifest.xml`. Without it FCM calls `onNewToken`, not the `onRegistered` the app waits for, and nothing fails. Builds before `app-v0.2.2` don't have the flag. With the flag on, a phone logs `Push registration failed: <reason>` (`adb logcat -s flutter`), and Crashlytics records the same error. A sleeping phone blocks the app's network, so check with the screen on before reading a failure as a bug.
