# Bug-bash script: D4 · MVP launch

Run every step on each platform:

- **AND:** the Android release build from the closed track.
- **IOS:** the PWA installed on an iPhone with iOS ≥ 16.4, opened from its icon.
- **WEB:** desktop Chrome at 1440 × 900.

Record each step as pass, fail or n/a in `bug-bash-results.md` (format in [data-model.md](data-model.md#bug-bash-results-bug-bash-resultsmd-lane-m)). A **crash** is the app closing, a white or red screen, or a frozen UI. A **blocker** is a step that can't be finished. Both are fixed with a test before the gate. Everything else is cosmetic: list it with a target day.

Setup: a fresh install (WEB and IOS: clear the site data first). B1 or the owner creates a match for a team you will follow, kicking off about 25 minutes after step R1 starts, with a channel on Nilesat.

## O · Onboarding

| # | Step | Expect |
|---|---|---|
| O1 | Launch | The splash, then S1.1, with no flash of unstyled content (WEB, IOS) |
| O2 | S1.1: pick فاتح, then داكن | The preview tiles and the whole app switch at once |
| O3 | S1.2: search «الاهلي», then «الأهلي» | The same results, grouped by competition. Choose the test match's team and one more |
| O4 | Close the app in S1.2 and reopen it | It resumes at S1.2 with both teams still chosen |
| O5 | S1.3: choose Nilesat and Hotbird | Continue works, and «حدد أقمارك» is not shown later |
| O6 | S1.4 (AND, WEB): «تفعيل التنبيهات» / allow | The system prompt appears, and allow works. IOS installed: the prompt appears after the tap |
| O7 | Turn airplane mode on during S1.2's search | The error state with «إعادة المحاولة». Retry after reconnecting works (M-T045-3) |

## S · Matches and the answer

| # | Step | Expect |
|---|---|---|
| S1 | S2 today | Grouped by competition, channel line on rows, Western digits, times in the device zone |
| S2 | Page the date strip ±3 days; pull to refresh | Each day loads. The refresh indicator ends |
| S3 | The live filter chip | Only live or estimated matches. No score on estimated ones |
| S4 | Open a match with few channels (S3) | The answer is visible without scrolling, My satellites are first, the readout is dark LTR |
| S5 | Open a match with 130+ channels | The first answer in under 1 s, with smooth scrolling |
| S6 | Copy a frequency; play a commentator clip | The copy confirmation appears; the clip plays and stops |
| S7 | A match with no channels | «لم تُضف القنوات الناقلة بعد» with «تابع المباراة», which follows it |
| S8 | S4: switch satellite | Only that satellite's matches |
| S9 | S5.1 → S5.2: change category; search `11843` | The results update, and the readout stays visible |

## F · Follow and settings

| # | Step | Expect |
|---|---|---|
| F1 | S9 | The two teams and «مبارياتي القادمة». Remove one team, then add it back |
| F2 | S15: time zone GMT+3, then automatic | Times on S2 change and come back |
| F3 | S15: 12 / 24 h, theme, font 1.3× | Every screen follows, and nothing clips at 1.3× |
| F4 | S15: my satellites → Badr only | S3's order changes |
| F5 | S16 | Rows as in PB S16 today. IOS Safari, not installed: «تثبيت التطبيق» opens S1.5. AND and WEB: no install row |

## R · Reminder

| # | Step | Expect |
|---|---|---|
| R1 | Leave the app in the background before the test match's kickoff − 15 min | One notification: «‹home› × ‹away› بعد 15 دقيقة», naming a channel on your satellites |
| R2 | Tap it | Opens that match's S3 |

## X · System states

| # | Step | Expect |
|---|---|---|
| X1 | Airplane mode after using S2 | The offline banner with the data's age; cached screens still open |
| X2 | Clear the data, go offline, launch | The no-connection screen; «إعادة المحاولة» works after reconnecting |
| X3 | Owner raises `min_supported_build` in Remote Config | The forced-update screen blocks the app; restore the value |
| X4 | AND: back on a root tab | The exit snackbar |
| X5 | WEB, IOS: a new `web-v*` release is published while the app is closed | On the next open or two, the new release loads (`release.json` hash in DevTools / About) with no broken screen |
| X6 | WEB: Fast 4G, cleared site data, first open; then reopen | First data < 5 s; reopen < 1.5 s (record both) |
