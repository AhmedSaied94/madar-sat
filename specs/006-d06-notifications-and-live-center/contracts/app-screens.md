# Contract: app screens

Lane M owns `app/`, against B1's regenerated client. Copy goes in the ARB files, values come from tokens, and digits stay Western with tabular figures. Rules for each decision are in research [R13–R18](../research.md#r13-showing-events-quickly-without-more-polling).

## Flags

`RemoteConfigValues.features`, read as JSON in `fromRaw`. It also needs the constructor, the bundled values, `setDefaults` and the key list in `remote_config_repository.dart`.

```json
{ "live_center": false, "lineups": false }
```

Bad JSON or a wrong type keeps the bundled value. Thin providers: `liveCenterEnabledProvider`, `lineupsEnabledProvider`. Values apply on the next launch.

## S3: the live center

Placed right after `MatchHero`, before `ManualBroadcasterCards` and «أين تشاهد» (`match_detail_page.dart:260-288`).

| State | Shows |
|---|---|
| `live_center` off | Nothing, and goldens unchanged (SC-013) |
| On, no events and no lineups | Nothing, with no empty frame |
| On, events or lineups, not estimated | Tabs if lineups show, otherwise the timeline alone |
| `estimated: true` | Only the note «بدون نتيجة», as `StatusBlock`'s preview and the match lists word it, with no timeline, score or minute |
| Offline, cached | Cached events with `StaleHint`'s age, and no live treatment |

`detailWithLiveState` keeps events during an estimated state, so the estimated gate is its own check.

### Tabs

Screen-local, not in `INDEX.md`. «الأحداث» and «التشكيل». The التشكيل tab needs `lineups` on and data for at least one side.

### Timeline

`EventTimeline` is in `INDEX.md` and unbuilt, so it's built here as `EventTimelineItem(event:)`, following its README. A pure function, `buildTimeline(events, score, status) → rows`, gives the order: newest first while live, chronological once finished. Three columns as on `Match-Live.html`: home's cell on the right, the minute on the spine in mono and LTR (`45+2′`), away's cell. Rows use a sliver builder. Each row carries an Arabic screen-reader label (PB §13.8).

| Event | Label |
|---|---|
| Goal | «هدف» with a running score when known |
| Own goal | «عكسي», PB S3's word and the push's |
| Penalty | «ركلة جزاء» |
| Missed penalty | «ركلة جزاء ضائعة» |
| Red card | «بطاقة حمراء», using `error`, with an icon |

- **Markers.** Derived from the minute and placed by the same order: «بداية المباراة» at the match's start, «الشوط الثاني» at the first minute over 45+, «إضافي» (the existing `extraTime` string, PB's word for extra time) at the first over 90+. A stoppage minute like `45+2` belongs to its half.
- **Running score.** Only when the goal-type events per side equal the score's sides. Otherwise no goal row shows one, and none is invented (FR-053).
- **No player.** The row shows type and minute only.

### Lineups

A pitch needs, for a side: 11 starters, exactly 1 goalkeeper, and each starter's `position` in the four FilGoal groups. Otherwise that match shows two lists. Goal.com's lineups always give lists, as `position` is null there.

- The pitch places rows by group, home at the bottom as on `Match-Lineups.html`. Numbered circles use tokens, as `TeamRef` has no colours.
- Formation is a label, and an empty one isn't shown.
- Goal and red-card marks appear only on an exact name match with an event.
- Two lists: starters then substitutes, in S3's row style, since no board draws them.

### Score highlight

The hero becomes aware of the previous score through a small `ScoreFlash` wrapper around `StatusBlock`. It highlights once, for `.big-sc.flash`'s 1.2 s, when either side rises while on screen. There's no flash on first paint or on a fall, and none under `MediaQuery.maybeDisableAnimationsOf(context)`.

### Re-reads

`ref.listen` on the match's live state (`match_detail_page.dart:143`): invalidate the detail when `score`, `status` or `event_count` changes. Ignore nulls, because live states expire to null (`live_poller.dart:67`). The 60 s timer stays, and live values still come only from `/v1/live`.

### Follow note (FR-060)

In `MatchFollowButton`, which today gets only the match ID and kickoff. Passing the status and live state, "covered" means an in-play status with `estimated` false.

## S5.2 and S6

- `CarriageRow` gains a parameter that shows `ChangedBadge`, passed only from `channel_list.dart`, when `frequencyChangedAt` is within 30 days. S3's use of the row is unchanged.
- S6 shows `recent_frequency_changes` as already specified. A filled list is the only new state to test.

## Push routes

One Dart function, `parsePushRoute(String) → PushRoute?`, accepts exactly the [four shapes](public-api.md#routes-and-tags), with `<id>` as digits only. `push_service.dart:199` and `push_route_listener.dart:28-36` both use it. Anything else opens the app and goes nowhere.

| Event | Behaviour |
|---|---|
| Tapped, app closed or in background | Go to the route |
| Received while open (`onMessage`) | A banner with the title, body and «عرض». Only «عرض» navigates. The test at `push_service_test.dart:177` changes with it |
| `/match/<id>?section=channels` | Open S3, then one `ensureVisible` on a key at the toolbar (`where_to_watch_slivers.dart:84`), after load. A sliver not built yet: scroll it into range first |
| `/channel/<id>` | `go('/')`, then `push`, so the sheet has something under it |
| A valid route to a missing record | S3 and S6's existing not-found states |

The web worker (`app/web/firebase-messaging-sw.js:35-49`) mirrors the shapes with a tested regex, and falls back to `openWindow` if `client.navigate` rejects. It needs a first test.

## S15: the notification group

Sits before satellites, as on `Settings.html:41-59`.

| Row | Copy | Default |
|---|---|---|
| Master | «السماح بالإشعارات» | On |
| Type | «تذكير قبل المباراة» | On |
| Type | «بداية المباراة» | **Off** |
| Type | «الأهداف» | On |
| Type | «النتيجة النهائية» | On |
| Type | «تحديث القنوات» | On |
| Type | «تغيير التردد» | On |
| Type | «إعلانات التطبيق» | On |

- «التذكير الافتراضي» stays hidden until D8.
- Master off dims the types and keeps their values.
- **Storage.** A new key in `app_settings` needs no migration: `SettingsKeys` and `AppSettingsValue`.
- **Sync.** `_sendDevice` (`device_sync.dart:181`) sends prefs, the listener (:52-66) compares them, and the dirty flag covers offline. Nothing syncs before onboarding ends (:84), as today.

### Platform state

`PushMessaging` gains `Future<PushPermission> permission()`, and the four test fakes change.

| State | Shows |
|---|---|
| Allowed | The switches, and «مسموح على هذا الجهاز» |
| Denied | The steps to enable, using `FollowSheet.html:45`'s copy |
| iPhone browser, not installed (`installGuideProvider.needsInstallSteps`) | A link to `/install`, with no switches |

Constitution 1.4.0 adds a fourth state to PB S15: no Google Play services, «الإشعارات غير متاحة على هذا الهاتف لأنه لا يدعم خدمات Google Play». Its delivery-plan row places that with the ad and store work, not in D6, so it isn't built here. Keep the state as an enum, so that work adds one case.

## S15: device ID

A row under عن التطبيق after the version (`settings_page.dart:234`), with a copy action like `channel_sheet.dart:73`. Hidden until known.

`DeviceRepository.update` keeps `device_id` from `PUT`'s response in `app_settings`, and `forget()` clears it. If it's missing on start, one sync is forced, because existing installs return early (`device_repository.dart:37`).

## Tests

Run with `RTEST_HOST=flutter-tests rtest`, never on the laptop.

- Widget and golden tests, for the timeline and lineups: RTL, both themes, 1.3×, flags on and off.
- Unit tests: `buildTimeline`, the pitch rule, `parsePushRoute`, `features` parsing.
- S3: re-read on `event_count`, reduced motion, the estimated gate.
- S15: each platform state, offline sync, master off keeping types.
- `app/web`: the worker's route check.
