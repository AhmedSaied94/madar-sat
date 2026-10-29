# Flutter app — screen index

The phone app (Android, iOS PWA) and its desktop-web layout. IDs (S0–S20, §11) refer to `new_app/docs/product-business.md`.

Phone boards are 360 dp wide (the design baseline; check at 412 dp and font scale 1.3). PNGs of phone boards are rendered at 2×.

Each screen has two files side by side: `<Board>.png` (how it looks in its default theme) and `<Board>.html` (the exact structure, Arabic copy, order and states, styled by `../styles/`). Open the HTML in a browser to inspect spacing; switch the root class `t-dark` ↔ `t-light` to see the other theme.

Fixtures, channels, frequencies, commentators and rights holders are real data from the 2026-10-28 snapshot. Live scores, events, lineups, health metrics and admin names are sample values; team crests are coloured placeholders.


## Design system

Folder: `screens/00-design-system/`

| Screen | Files | Size | Theme | Notes |
|---|---|---|---|---|
| Brand, color & type | [png](screens/00-design-system/Main.png) · [html](screens/00-design-system/Main.html) | 1680×1240 | dark | component / foundation sheet |
| Components · Matches | [png](screens/00-design-system/Comp-Matches.png) · [html](screens/00-design-system/Comp-Matches.html) | 1680×1240 | dark | component / foundation sheet |
| Components · Channels | [png](screens/00-design-system/Comp-Channels.png) · [html](screens/00-design-system/Comp-Channels.html) | 1680×1240 | dark | component / foundation sheet |
| Components · Core, feedback, platform | [png](screens/00-design-system/Comp-Core.png) · [html](screens/00-design-system/Comp-Core.html) | 1680×1240 | dark | component / foundation sheet |

## S1 · Onboarding

Folder: `screens/01-onboarding/`

| Screen | Files | Size | Theme | Notes |
|---|---|---|---|---|
| Splash | [png](screens/01-onboarding/Splash.png) · [html](screens/01-onboarding/Splash.html) | 360×800 | dark |  |
| S1.1 Welcome + theme | [png](screens/01-onboarding/Onb-Welcome.png) · [html](screens/01-onboarding/Onb-Welcome.html) | 360×800 | dark | interactive in the canvas (selection toggles); snapshot shows the default selection |
| S1.2 Teams | [png](screens/01-onboarding/Onb-Teams.png) · [html](screens/01-onboarding/Onb-Teams.html) | 360×800 | dark | interactive in the canvas (selection toggles); snapshot shows the default selection |
| S1.3 My satellites | [png](screens/01-onboarding/Onb-Satellites.png) · [html](screens/01-onboarding/Onb-Satellites.html) | 360×800 | dark | interactive in the canvas (selection toggles); snapshot shows the default selection |
| S1.4 Notifications | [png](screens/01-onboarding/Onb-Notifications.png) · [html](screens/01-onboarding/Onb-Notifications.html) | 360×800 | dark |  |
| S1.5 iOS install guide (PWA) | [png](screens/01-onboarding/Onb-InstallIOS.png) · [html](screens/01-onboarding/Onb-InstallIOS.html) | 360×800 | light |  |

## S2 · Matches

Folder: `screens/02-matches/`

| Screen | Files | Size | Theme | Notes |
|---|---|---|---|---|
| S2 Matches — today (dark, Android) | [png](screens/02-matches/Matches.png) · [html](screens/02-matches/Matches.html) | 360×800 | dark |  |
| S2 Live filter (light, iOS PWA) | [png](screens/02-matches/Matches-Light.png) · [html](screens/02-matches/Matches-Light.html) | 360×800 | light |  |
| S2 First load skeleton | [png](screens/02-matches/Matches-Loading.png) · [html](screens/02-matches/Matches-Loading.html) | 360×800 | dark |  |
| S2 My matches — empty | [png](screens/02-matches/Matches-Empty.png) · [html](screens/02-matches/Matches-Empty.html) | 360×800 | dark |  |
| S2 Long-press quick actions | [png](screens/02-matches/Matches-Actions.png) · [html](screens/02-matches/Matches-Actions.html) | 360×800 | dark |  |
| S0 Offline cache, soft update, exit | [png](screens/02-matches/Matches-Banners.png) · [html](screens/02-matches/Matches-Banners.html) | 360×800 | dark |  |

## S3 · Match detail

Folder: `screens/03-match-detail/`

| Screen | Files | Size | Theme | Notes |
|---|---|---|---|---|
| S3 Live match — full scroll | [png](screens/03-match-detail/Match-Live.png) · [html](screens/03-match-detail/Match-Live.html) | 360×1560 | dark |  |
| S3 Live center — lineups | [png](screens/03-match-detail/Match-Lineups.png) · [html](screens/03-match-detail/Match-Lineups.html) | 360×800 | dark |  |
| S3 Before kickoff — full scroll | [png](screens/03-match-detail/Match-Prematch.png) · [html](screens/03-match-detail/Match-Prematch.html) | 360×1180 | dark |  |
| S3 130 channels — groups + expanded row | [png](screens/03-match-detail/Match-Channels.png) · [html](screens/03-match-detail/Match-Channels.html) | 360×1640 | dark |  |
| S3 No channels yet | [png](screens/03-match-detail/Match-NoChannels.png) · [html](screens/03-match-detail/Match-NoChannels.html) | 360×800 | light |  |

## S4–S6 · Satellites

Folder: `screens/04-satellites-frequencies/`

| Screen | Files | Size | Theme | Notes |
|---|---|---|---|---|
| S4 My satellites | [png](screens/04-satellites-frequencies/MySatellites.png) · [html](screens/04-satellites-frequencies/MySatellites.html) | 360×800 | dark |  |
| S5.1 Satellite list | [png](screens/04-satellites-frequencies/Frequencies.png) · [html](screens/04-satellites-frequencies/Frequencies.html) | 360×800 | dark |  |
| S5.2 Satellite detail | [png](screens/04-satellites-frequencies/Satellite.png) · [html](screens/04-satellites-frequencies/Satellite.html) | 360×800 | dark |  |
| S6 Channel sheet | [png](screens/04-satellites-frequencies/Channel.png) · [html](screens/04-satellites-frequencies/Channel.html) | 360×800 | dark |  |

## S7–S10, S14 · Follow & search

Folder: `screens/05-follow-and-search/`

| Screen | Files | Size | Theme | Notes |
|---|---|---|---|---|
| S9 Favorites | [png](screens/05-follow-and-search/Favorites.png) · [html](screens/05-follow-and-search/Favorites.html) | 360×800 | dark |  |
| S7 Team | [png](screens/05-follow-and-search/Team.png) · [html](screens/05-follow-and-search/Team.html) | 360×800 | light |  |
| S10 Follow notifications sheet | [png](screens/05-follow-and-search/FollowSheet.png) · [html](screens/05-follow-and-search/FollowSheet.html) | 360×800 | dark |  |
| S8 Competition | [png](screens/05-follow-and-search/Competition.png) · [html](screens/05-follow-and-search/Competition.html) | 360×800 | dark |  |
| S14 Search | [png](screens/05-follow-and-search/Search.png) · [html](screens/05-follow-and-search/Search.html) | 360×800 | dark |  |

## S11–S16 · More

Folder: `screens/06-more-settings-rights/`

| Screen | Files | Size | Theme | Notes |
|---|---|---|---|---|
| S16 More | [png](screens/06-more-settings-rights/More.png) · [html](screens/06-more-settings-rights/More.html) | 360×800 | dark |  |
| S15 Settings — full scroll | [png](screens/06-more-settings-rights/Settings.png) · [html](screens/06-more-settings-rights/Settings.html) | 360×2120 | dark |  |
| S11.1–3 Broadcast rights | [png](screens/06-more-settings-rights/Rights.png) · [html](screens/06-more-settings-rights/Rights.html) | 360×800 | dark |  |
| S11.4 Rights holder | [png](screens/06-more-settings-rights/RightsHolder.png) · [html](screens/06-more-settings-rights/RightsHolder.html) | 360×960 | dark |  |
| S12 Feeds | [png](screens/06-more-settings-rights/Feeds.png) · [html](screens/06-more-settings-rights/Feeds.html) | 360×800 | dark |  |

## S0 · System & push

Folder: `screens/07-system-and-push/`

| Screen | Files | Size | Theme | Notes |
|---|---|---|---|---|
| S0 Forced update | [png](screens/07-system-and-push/Sys-ForcedUpdate.png) · [html](screens/07-system-and-push/Sys-ForcedUpdate.html) | 360×800 | dark |  |
| S0 Maintenance | [png](screens/07-system-and-push/Sys-Maintenance.png) · [html](screens/07-system-and-push/Sys-Maintenance.html) | 360×800 | dark |  |
| S0 No connection, nothing cached | [png](screens/07-system-and-push/Sys-NoConnection.png) · [html](screens/07-system-and-push/Sys-NoConnection.html) | 360×800 | light |  |
| S0 Load failed | [png](screens/07-system-and-push/Sys-LoadFailed.png) · [html](screens/07-system-and-push/Sys-LoadFailed.html) | 360×800 | dark |  |
| §11 Notification catalog | [png](screens/07-system-and-push/Push.png) · [html](screens/07-system-and-push/Push.html) | 1040×800 | dark |  |

## Desktop web

Folder: `screens/08-desktop-web/`

| Screen | Files | Size | Theme | Notes |
|---|---|---|---|---|
| Desktop ≥1024 — rail + list + detail (dark) | [png](screens/08-desktop-web/Web-Matches.png) · [html](screens/08-desktop-web/Web-Matches.html) | 1440×900 | dark | fills the window |
| Desktop — frequencies + channel pane (light, hover/focus) | [png](screens/08-desktop-web/Web-Frequencies.png) · [html](screens/08-desktop-web/Web-Frequencies.html) | 1440×900 | light | fills the window |

## V2 concepts

Folder: `screens/09-v2-concepts/`

| Screen | Files | Size | Theme | Notes |
|---|---|---|---|---|
| S18 Satellite finder [V2] | [png](screens/09-v2-concepts/V2-Finder.png) · [html](screens/09-v2-concepts/V2-Finder.html) | 360×800 | dark | V2 — not in the first release |
| S19 Report a problem [V2] | [png](screens/09-v2-concepts/V2-Report.png) · [html](screens/09-v2-concepts/V2-Report.html) | 360×800 | dark | V2 — not in the first release |
| S17 Commentator [V2] | [png](screens/09-v2-concepts/V2-Commentator.png) · [html](screens/09-v2-concepts/V2-Commentator.html) | 360×800 | dark | V2 — not in the first release |
| S20 Widgets + ongoing notification [V2] | [png](screens/09-v2-concepts/V2-Widgets.png) · [html](screens/09-v2-concepts/V2-Widgets.html) | 760×800 | dark | V2 — not in the first release |
