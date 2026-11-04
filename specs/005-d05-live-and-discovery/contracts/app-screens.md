# Contract: S6, S7 and S8

Lane M builds them under `app/lib/features/{channel,team,competition}/` with `data/domain/presentation` layers. Before building, read the boards in `madar-design/app-flutter/SCREENS.md`: S6 Channel sheet, S7 Team and S8 Competition.

## Routes and entry points

| Route | Today | D5 | Reached from |
|---|---|---|---|
| `/channel/:id` | `StubPage` | Modal bottom sheet through `pageBuilder`; deep-linkable | S3 carriage rows, S5 channel rows |
| `/team/:id` | `StubPage` | Full page | S3's hero crest or name, S9 |
| `/competition/:id` | `StubPage` | Full page | S2 section header, S3 competition line, S9 |

Tapping a `MatchRow` anywhere opens S3, including a tap on a team inside the row. That keeps the answer one tap from S2 (constitution I), so S7 is reached through S3.

## Data

- A repository per screen, using `CachedDocuments` and SWR: emit the drift copy, revalidate with `If-None-Match`, a `200` updates, a `304` changes nothing.
- Keys: `channel:<id>`, `team:<id>`, `competition:<id>`.
- The age shows through `StaleHint` or `OfflineBanner` by the existing rules.
- Live values on rows come from the existing `/v1/live` provider, merged as on S2.

## S6

Sections, top to bottom: header (`Logo`, name, category, country) · carriage card (satellite, collapsed-free `FrequencyReadout`, copy, `access`, provider or package) · follow · other carriages (My satellites first, free first) · upcoming matches (7 days) · frequency history (last 3, hidden when empty).

- No report action (V2) and no desktop pane (later).
- The follow row uses the board's copy: «تابع القناة · تنبيه عند تغيّر التردد». Alerts begin on D6.

## S7

Header (`TeamCrest`, name, main competition, stadium) · follow toggle · tabs «القادمة» / «النتائج», which use `ListView.builder` · empty state «لا توجد مباريات قادمة». A results tab with no rows uses the board's empty pattern.

## S8

Header (`Logo`, name) · follow toggle · a «حقوق البث» shortcut that scrolls to the section · tabs «القادمة» / «النتائج», grouped by the user's local date · «حقوق البث» section.

- Rights rows aren't tappable until S11 arrives on D7, and show no chevron.
- No hide/show (D8), and no `عرض الكل` link until S11 exists.
- The boards' AdMob slots aren't built (D9, constitution I).

## Follow

Uses `follows_repository` and the existing server mirror. A plain toggle: the S10 sheet is D8. A failed sync keeps the existing retry behaviour.

## Copy, tokens and tests

- Strings go in `lib/core/l10n/app_ar.arb`, and API errors through `error_copy.dart`.
- Each composite row has a merged Arabic semantics label.
- Widget tests cover each state: loading on a true first load, cached, stale, offline, empty, error.
- Goldens cover RTL × {light, dark} × {1.0, 1.3}.
- `live_center`: `app/lib/` reads no feature flag today, so D5 adds no code for it. The Remote Config `features` value is `live_center: false` until D6 (owner, [remote-config](../../../docs/runbooks/remote-config.md)), and that runbook's example changes to match.
