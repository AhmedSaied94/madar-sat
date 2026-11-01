# Push notifications

How the reminder gets made and sent, how to set up and rotate the FCM service account, how to read the outbox, and what to do when a row fails. Background: system-design §6.8, constitution VII, `specs/003-d03-follow-push-sources/` research R6–R9, and `backend/app/notifications/`.

## How a reminder is made

Three steps, no HTTP request in the path (FR-007):

1. **Schedule** — `notifications.schedule_reminders` on the `notifications` queue, every 5 minutes (`notify-schedule`). It takes `lock:notifications:schedule` (4 min) so two beats cannot double-schedule, selects matches with `kickoff_at` in `(now, now + 24 h]`, `time_tbd = false`, status `scheduled`, that have at least one follower (home team, away team, competition or the match), and upserts one row per match:

   ```text
   type       = kickoff_reminder
   dedupe_key = kickoff_reminder:<match_id>          (unique)
   due_at     = greatest(kickoff_at − 15 min, now)
   audience   = {"kind": "match_followers", "match_id": <id>}
   ```

   `ON CONFLICT (dedupe_key) DO UPDATE … WHERE status = 'pending'`, so a moved kickoff moves a pending row and a sent one is never touched or duplicated. A second statement cancels pending rows whose match became `time_tbd`, `postponed`, `cancelled` or `abandoned`, or whose kickoff moved past 24 h.

2. **Dispatch** — `notifications.dispatch_due` on `notifications`, every minute (`notify-dispatch`) and queued by the scheduler when a row is due now. It reclaims rows stuck in `sending` for more than 10 minutes, claims up to 10 due rows with `FOR UPDATE SKIP LOCKED`, and for each row resolves the audience in pages of 500 with one `SELECT DISTINCT` (`AUDIENCE` in `backend/app/notifications/dispatcher.py`), builds each device's message from the match's visible links and the device's satellites, sends the page through `firebase_admin.messaging.send_each`, and records `sent`, `failed` and `cursor_device_id`. A whole-call failure puts the row back to `pending` with its cursor, so a retry resumes where it stopped; after 5 retries the row is `failed`. A token FCM answers `UNREGISTERED` (or an invalid registration token) is set to `NULL`, so the device stops receiving.

3. **Prune** — `notifications.prune_outbox` on `maintenance`, daily at 04:30 UTC (`notify-prune`). Deletes `sent`, `failed` and `cancelled` rows older than 30 days.

Only `app/notifications/sender.py` talks to FCM. Producers only insert outbox rows.

## The FCM service account

1. **Create the key.** In the Firebase console for the project, *Project settings → Service accounts → Generate new private key*. A JSON file downloads once. Never commit it, paste it, or send it in chat (`gitleaks.yml` scans history).
2. **Install it on VPS-2** (the only host that sends). Copy it over the WireGuard jump:

   ```bash
   scp -J ubuntu@10.8.0.1 ./fcm.json ubuntu@10.1.0.118:/tmp/fcm.json
   ssh -J ubuntu@10.8.0.1 ubuntu@10.1.0.118
   sudo install -d -m 700 -o deploy -g deploy /srv/secrets
   sudo install -m 600 -o deploy -g deploy /tmp/fcm.json /srv/secrets/fcm.json
   shred -u /tmp/fcm.json
   ```

3. **Point the worker at it.** In VPS-2's `/srv/madar/.env`:

   ```text
   FCM_CREDENTIALS_FILE=/srv/secrets/fcm.json
   FCM_DRY_RUN=false
   PWA_ORIGIN=https://app.<ip1>.sslip.io
   ```

   `infra/compose/vps2.yml` mounts that one file read-only into `worker-notify` and no other service. `PWA_ORIGIN` is the web push link's origin (`<PWA_ORIGIN>/match/<id>`); a value with a wrong origin sends users to a dead link.

4. **Restart and check.** On VPS-2:

   ```bash
   dc up -d --force-recreate worker-notify
   dc logs --tail=50 worker-notify | grep -F 'fcm: initialized'
   ```

   The line appears the first time the first message is sent, not at boot: the SDK is imported lazily.

5. **Rotate.** Generate a new key, install it as above (over the old file), `dc up -d --force-recreate worker-notify`. Firestore keeps working: the key is only used by `firebase-admin`. Revoke the old key in *Service accounts → Manage keys* once a reminder has gone through.

`FCM_DRY_RUN=true` uses FCM's own dry run: messages are validated and no notification is delivered. Use it on a staging check, then set it back and restart.

## The owner's audience review

The audience query is `AUDIENCE` in `backend/app/notifications/dispatcher.py`. It is one statement, bound parameters only, and reads as:

- `devices` joined to `device_follows`, `DISTINCT` on the device row;
- a device with a push token, `id > :cursor` (the page cursor), and any follow that is the match, the competition, the home team or the away team;
- `COALESCE((prefs #>> '{types,kickoff_reminder,on}')::boolean, true)`: a device that switched the reminder off is not sent to. A device that never sent prefs is on (the D3 default).

What to check when you review it: no string interpolation, no write, one device per row, and that it cannot return a device twice (the `DISTINCT`).

## Read the outbox

In the VPS-1 `psql` shell ([database-migrations.md "Read the state"](database-migrations.md#read-the-state)):

```sql
-- what is waiting and what went out in the last day
SELECT status, count(*) FROM notification_outbox
 WHERE created_at > now() - interval '1 day' GROUP BY status ORDER BY status;

-- the newest rows, with how many devices each reached
SELECT id, dedupe_key, status, due_at, sent, failed, cursor_device_id, sent_at
  FROM notification_outbox ORDER BY id DESC LIMIT 20;

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
       failed = 0, sent_at = NULL, due_at = now()
 WHERE id = <id> AND status = 'failed';
```

Then let the next `notify-dispatch` (≤ 1 minute) send it, or run it by hand: `dc exec worker-notify celery -A app.workers call notifications.dispatch_due`. Keep `cursor_device_id` instead of resetting it if only the tail failed; the devices before the cursor already received it.

Do not edit a `sent` row: the scheduler will not create a second one, so clearing it is the only way to send a match twice — and it would notify everyone again.

## When a reminder doesn't arrive

1. `SELECT * FROM notification_outbox ORDER BY id DESC LIMIT 5;` — is there a row? If not, nobody follows the match (`device_follows`) or the match is `time_tbd` / postponed / cancelled / outside 24 h.
2. Is `due_at` in the past and `status = 'pending'`? Look for `notifications.dispatch_due` in VPS-2's worker logs, and whether `beat` runs at all ([workers.md](workers.md)).
3. `status = 'failed'` with `error`/`failed` counts: the FCM credentials are wrong or the key rotated. Check `dc logs worker-notify | grep -F 'fcm'`.
4. A device with `push_token = NULL` was told `UNREGISTERED`; it registers again the next time the app opens.
5. `FCM_DRY_RUN=true` on the host means nothing is delivered. Check the value in `/srv/madar/.env`.
