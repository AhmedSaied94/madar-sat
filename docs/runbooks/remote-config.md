# Remote Config

The app's hosts and switches come from Firebase Remote Config, so a host or a floor can move without a store release (system-design §5.1, research R28). The app ships every key as a **bundled default**: a phone that has never reached Firebase, a console that has no parameters yet, or a flight-mode start all run on the defaults, and a value is accepted only when it is usable.

Code: `app/lib/core/config/remote_config.dart` (the keys, the validation and the bundled defaults) and `app/lib/core/config/remote_config_repository.dart` (the fetch on start). `env/<flavor>.json` holds the bundled host per flavor.

## The keys D3 reads

| Key | Bundled default | What it does | Accepted |
| --- | --- | --- | --- |
| `api_base_url` | `API_BASE_URL` from `env/<flavor>.json` | The host every `/v1` request goes to | `https`, no userinfo, a host, at most 2048 characters. Anything else keeps the bundled host |
| `media_base_url` | `MEDIA_BASE_URL` from `env/<flavor>.json` | The only host images may load from | same rule as `api_base_url` |
| `min_supported_build` | `0` | The lowest build that may run; a lower build sees S0's forced update and nothing else | a whole number; `0` never blocks |
| `latest_build` | `0` | The newest published build. Read now; the soft-update banner that shows it arrives on D8 | a whole number |
| `live_poll_interval_s` | `30` | How often `/v1/live` is polled while a live or imminent match is on screen | 10–600 seconds; anything else keeps 30 |

`maintenance`, `ads` and `features` are read but nothing renders them until D8–D9 (plan.md Complexity Tracking).

## Set the parameters

1. Open the Firebase console → your project → **Remote Config**.
2. Add each key above with its **production** value, then **Publish changes**.
3. Keep the value equal to the bundled default when you have nothing to change: a parameter that differs from the bundle is one more thing to explain later.

The app fetches on start with a 10-second timeout. Release builds keep the console's one-hour minimum fetch interval (a parameter change reaches a phone within an hour of its next start); debug builds refetch on every start so you can try a value.

## Change a host safely

The hosts are baked into every cached ETag and drift key, so a change applies on the **next launch** and the cache starts cold for the new host. That is on purpose (R28): switching hosts mid-session would mix two servers' answers in one cache.

1. Bring the new host up and check it answers `/healthz` and `/v1/matches` with the environment's data.
2. Set `api_base_url` (and `media_base_url` if the media host moved) to the new address, `https` only.
3. Publish, then close and reopen the app on a phone. The old host stops being used on the next start.
4. Keep the old host answering for at least one release cycle: a phone that has not opened the app since the change still asks the old one.

If the value fails validation the app keeps the bundled host, which is the address that host had when the build was made; that is why the flavors' files must stay current.

## Raise the floor (forced update)

`min_supported_build` compares with the build number the app reports (`app/lib/core/config/build_info.dart`, which repeats `pubspec.yaml`'s version). Raising it above a build **blocks that build behind S0's forced-update screen**: no tab, no cache, only «تحديث الآن».

1. Release the new build first and confirm Play serves it.
2. Set `min_supported_build` to that build's number and publish.
3. Watch the first day: a phone still on the old build sees the update screen at its next launch. The Android button opens Play; the installed PWA reloads.
4. **Do not** raise it in the same hour as the release: a phone that updates through Play between the two steps is fine, but a publish ahead of the store listing blocks everyone with nowhere to go.

`latest_build` drives the softer "update available" banner that arrives on D8; raising it today has no visible effect.

## The live interval

`live_poll_interval_s` reaches the poller (`app/lib/features/live/live_poller.dart`) and the live-state expiry (twice the interval) without a release. Keep it at 30 unless the API's cache or the upstream feed asks for less: each poll is one `/v1` request per device on a live screen.

## Check it worked

- On a debug build, the app logs nothing about Remote Config by design; open S16 → الإعدادات and check that the screens still load, which proves `api_base_url` is a host that answers.
- Deliberately set a bad value (`http://…`): the app keeps the bundled host and keeps working. Set it back.
- `min_supported_build`: set it above the installed build, relaunch, and confirm the forced-update screen appears. Then set it back.

## The web push worker

The PWA's service worker needs the public Firebase web identifiers, which are not in Remote Config but in the bundle. `./tool/write_firebase_config.sh env/prod.json` writes `web/firebase-config.js` from the flavor file; run it before `flutter build web` ([store-releases.md](store-releases.md#push-setup) has the whole push setup).
