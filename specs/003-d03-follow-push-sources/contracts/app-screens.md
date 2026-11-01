# Contract: Lane M screens, routes and components (D3)

What Lane M builds and the boards it is checked against. Rows come from `madar-design/app-flutter/SCREENS.md`; read each PNG and HTML before building (CLAUDE.md, Client UI rules).

## Routes (PB §8.4)

| Route | Screen | Notes |
| --- | --- | --- |
| `/onboarding/:step` | S1.1–S1.5 (`welcome`, `teams`, `satellites`, `notifications`, `install`) | Redirect target on first launch until `onboarding_done`; resumes at the stored step |
| `/favorites` | S9 | Tab 4 (was a stub) |
| `/more` | S16 | Tab 5 (was a stub) |
| `/settings`, `/settings/:section` | S15 | `time`, `appearance`, `satellites`, `about`; opened from S16 |
| `/install` | S1.5 | iOS PWA only; also from S16 |
| `/match/:id` | S3 | Push notifications open it (`data.route`) |
| `/update-required` | S0 forced update | Shown before the shell when the build < `min_supported_build` |

## Screens

| Screen | Board(s) | D3 scope |
| --- | --- | --- |
| Splash | `01-onboarding/Splash` | Android 12 splash API: icon on solid color; web shows the same mark until Flutter's first frame |
| S1.1 Welcome + theme | `Onb-Welcome` | داكن / فاتح / تلقائي with live preview tiles |
| S1.2 Teams | `Onb-Teams` | Search via `GET /v1/teams?q` (D1), groups by competition with popular first (competition priority), tray of chosen teams |
| S1.3 My satellites | `Onb-Satellites` | Rows from `/v1/satellites`; «الأكثر استخداماً» on Nilesat and Badr; skip keeps the O10 default |
| S1.4 Notifications | `Onb-Notifications` | Priming card → OS / browser prompt on tap; «ليس الآن» |
| S1.5 iOS install guide | `Onb-InstallIOS` | Three steps; only on iOS Safari when not standalone |
| S9 Favorites | `05-follow-and-search/Favorites` | «مبارياتي القادمة» (next 3, from followed teams and matches), the Teams section with remove, «أضف فرقاً» (→ the S1.2 team picker), empty state. Competitions, Channels and Commentators sections hidden until a screen offers their follow action (S8 on D5, later days) |
| S15 Settings (core) | `06-more-settings-rights/Settings` | التوقيت, المظهر (theme, font size), أقماري, onboarding steps, عن التطبيق (version, privacy policy link, «حذف بيانات جهازي»). Notifications, competitions order and البيانات groups wait (V1, D8) |
| S16 More | `06-more-settings-rights/More` | الإعدادات, شارك التطبيق, سياسة الخصوصية, تثبيت التطبيق (iOS PWA only), about card. حقوق البث, الفيدات and the finder rows wait for their screens |
| S0 | `07-system-and-push/Sys-ForcedUpdate`, `Sys-NoConnection`, `Sys-LoadFailed`, `02-matches/Matches-Banners` | Forced update, no connection, load failed, offline banner, Android exit snackbar. Maintenance and soft update wait for D8 |
| Push | `07-system-and-push/Push` | Kickoff reminder appearance (OS-drawn; the small icon `ic_stat_madar` is a monochrome glyph) |
| S3 changes | D2 boards | No-channels action becomes «تابع المباراة» (follows the match); the «حدد أقمارك» chip when the default set applies; a follow toggle in the header (Button README, follow variant) |

## Components (built once under their INDEX names)

| Component | INDEX entry | States / goldens |
| --- | --- | --- |
| `ListRow` | Navigation · ListRow | default, pressed, focus, disabled, with toggle, with value + chevron; RTL, both themes, 1.0× and 1.3× |
| `MadarButton` follow / bell variants | Controls · Button | following / not following, pressed, focus, loading |
| `MadarDialog` | Feedback · Dialog | the delete-device confirmation |
| `OfflineBanner`, `MadarSnackbar` | Feedback · Banner | offline with age; exit snackbar |
| `MadarToggle`, `MadarRadio`, `MadarCheckbox` | Controls · FormControls | on/off, focus, disabled |
| `ProgressDots` | (onboarding, from the S1 boards) | current, done, upcoming |

## Platform adapters

| Interface | Android | Web |
| --- | --- | --- |
| `PushService` | `firebase_messaging` | `firebase_messaging` web + `firebase-messaging-sw.js` |
| `CrashReporter` | Crashlytics | no-op |
| `InstallGuide` | no-op | standalone detection, S1.5 |

## Remote Config keys read on D3

`api_base_url`, `media_base_url`, `min_supported_build`, `live_poll_interval_s` (bundled defaults for every SD §5.1 key; `latest_build`, `maintenance`, `ads` and `features` are read but unused until D8–D9).
