# React admin — screen index

The admin panel. IDs (A0–A17) refer to `new_app/docs/product-business.md`.

Boards are 1440×900–1000 desktop frames; the layout fills the window (sidebar fixed at 248 px on the right, content fluid).

Each screen has two files side by side: `<Board>.png` (how it looks in its default theme) and `<Board>.html` (the exact structure, Arabic copy, order and states, styled by `../styles/`). Open the HTML in a browser to inspect spacing; switch the root class `t-dark` ↔ `t-light` to see the other theme.

Fixtures, channels, frequencies, commentators and rights holders are real data from the 2026-10-28 snapshot. Live scores, events, lineups, health metrics and admin names are sample values; team crests are coloured placeholders.


## Design system

Folder: `screens/00-design-system/`

| Screen | Files | Size | Theme | Notes |
|---|---|---|---|---|
| Brand, color & type (shared with the app) | [png](screens/00-design-system/DS-Tokens.png) · [html](screens/00-design-system/DS-Tokens.html) | 1680×1240 | dark | component / foundation sheet |
| Admin components · all states | [png](screens/00-design-system/Comp-Admin.png) · [html](screens/00-design-system/Comp-Admin.html) | 1440×1320 | dark | component / foundation sheet |

## A0–A2 · Shell & dashboard

Folder: `screens/01-shell-dashboard/`

| Screen | Files | Size | Theme | Notes |
|---|---|---|---|---|
| A2 Dashboard in the A0 shell (dark) | [png](screens/01-shell-dashboard/Main.png) · [html](screens/01-shell-dashboard/Main.html) | 1440×1000 | dark | fills the window |

## A3–A12 · Content

Folder: `screens/02-content/`

| Screen | Files | Size | Theme | Notes |
|---|---|---|---|---|
| A3 Matches | [png](screens/02-content/Matches.png) · [html](screens/02-content/Matches.html) | 1440×1000 | dark | fills the window |
| A4 Match editor (light) | [png](screens/02-content/MatchEditor.png) · [html](screens/02-content/MatchEditor.html) | 1440×1260 | light | fills the window |
| A5 Teams + merge tool | [png](screens/02-content/Teams.png) · [html](screens/02-content/Teams.html) | 1440×1000 | dark | fills the window |
| A6 Competitions · drag priority | [png](screens/02-content/Competitions.png) · [html](screens/02-content/Competitions.html) | 1440×900 | dark | fills the window |
| A7 Satellites | [png](screens/02-content/Satellites.png) · [html](screens/02-content/Satellites.html) | 1440×900 | dark | fills the window |
| A8 Channels + editor drawer (light) | [png](screens/02-content/Channels.png) · [html](screens/02-content/Channels.html) | 1440×1000 | light | fills the window |
| A9 Rights holders | [png](screens/02-content/Rights.png) · [html](screens/02-content/Rights.html) | 1440×960 | dark | fills the window |
| A10 Commentators | [png](screens/02-content/Commentators.png) · [html](screens/02-content/Commentators.html) | 1440×900 | dark | fills the window |
| A11 Lists | [png](screens/02-content/Lists.png) · [html](screens/02-content/Lists.html) | 1440×900 | dark | fills the window |
| A12 Feeds | [png](screens/02-content/Feeds.png) · [html](screens/02-content/Feeds.html) | 1440×900 | dark | fills the window |

## A13–A17 · Operations

Folder: `screens/03-operations/`

| Screen | Files | Size | Theme | Notes |
|---|---|---|---|---|
| A13 Sources + unresolved names | [png](screens/03-operations/Sources.png) · [html](screens/03-operations/Sources.html) | 1440×1000 | dark | fills the window |
| A13 Run detail | [png](screens/03-operations/SourceRun.png) · [html](screens/03-operations/SourceRun.html) | 1440×960 | dark | fills the window |
| A15 Notifications · outbox + composer | [png](screens/03-operations/Notifications.png) · [html](screens/03-operations/Notifications.html) | 1440×1000 | dark | fills the window |
| A14 Reports [V2] | [png](screens/03-operations/Reports.png) · [html](screens/03-operations/Reports.html) | 1440×900 | dark | fills the window; V2 — not in the first release |
| A16 Admin users (light) | [png](screens/03-operations/Users.png) · [html](screens/03-operations/Users.html) | 1440×900 | light | fills the window |
| A17 Audit log + diff | [png](screens/03-operations/Audit.png) · [html](screens/03-operations/Audit.html) | 1440×1000 | dark | fills the window |

## Login & common states

Folder: `screens/04-login-and-states/`

| Screen | Files | Size | Theme | Notes |
|---|---|---|---|---|
| A1 Login · error + lockout | [png](screens/04-login-and-states/Login.png) · [html](screens/04-login-and-states/Login.html) | 1440×900 | dark | fills the window |
| Conflict, typed confirm, unsaved guard, toasts, empty, skeleton | [png](screens/04-login-and-states/Dialogs.png) · [html](screens/04-login-and-states/Dialogs.html) | 1440×1000 | dark |  |
