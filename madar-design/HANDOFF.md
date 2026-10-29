# UI design handoff — ‹Brand› (working name «مدار»)

Date: 2026-10-28, updated 2026-10-29 · Built from `new_app/docs/product-business.md` and `system-design.md`.

## Where the designs live
- **Design system (Madar):** `design-system/` in this package; live at https://claude.ai/artifact/6T3Jt4odvH1Qniu38SrY5m. Tokens for dark and light, the brand book, 24 documented components.
- **Flutter app (Android, iOS PWA, desktop web):** `app-flutter/` in this package; live at https://claude.ai/artifact/CMHz4rrdB4r149NGLADxyE. 46 boards across 10 sections: design system, S0–S16, desktop two-pane, V2 concepts.
- **React admin (A0–A17):** `admin-react/` in this package; live at https://claude.ai/artifact/6DJjgPAeXeXYb7YnpQgdCy. 21 boards: design system, shell and dashboard, content, operations, login and common states.
- Every board has a dark and a light theme; the snapshot shows its default.

## Direction
"Broadcast control room" (§13.1):
- deep ink surfaces in dark mode and paper surfaces in light mode;
- one volt accent; red reserved for live (errors, red cards, failing-source counts and deletes use the separate `error` red);
- orbit rings used sparingly as the motif.

**Signature:** the frequency readout is a dark "equipment display" well with cyan tabular digits and the polarization letter in its own cell. It stays dark in light mode as well. It always renders LTR.

## Tokens (dark / light)
The full list, with usage notes, is `design-system/tokens.json`. Summary:

| Token | Dark | Light |
|---|---|---|
| bg | #07090C | #F2F3EF |
| surface-1/2/3 | #0F1318 / #161B22 / #1F262F | #FFFFFF / #ECEEE9 / #E1E4DE |
| text / 2 / 3 | #F1F4F7 / #A9B2BF / #848E9B | #0B0F13 / #475160 / #5E6876 |
| accent (fill) | #C8F542 + ink text | #C8F542 + ink text |
| accent-text | #C8F542 | #3F6A06 |
| live | #FF4D5E | #C81B33 |
| error | #FF6B6B | #C62828 |
| halftime | #FF9E58 | #A64A0C |
| postponed | #FFB627 | #955200 |
| free | #3EE0A1 | #047A55 |
| changed | #B9A2FF | #5B3CC4 |
| readout bg / digits | #020406 / #8FE7FF | #0B0F13 / #8FE7FF |

## Type
| Role | Family |
|---|---|
| Display: wordmark, scores, headings | Changa |
| UI | IBM Plex Sans Arabic |
| Readouts | IBM Plex Mono |

All three are OFL and included in `design-system/fonts/`. Bundle them in the app. Digits are Western with tabular figures.

## Conventions used
- The layout is RTL. Back arrows point right.
- Latin channel and satellite names and frequencies are isolated LTR islands; when too long they truncate at their own end.
- Scores are built from separate parts, with home on the right.
- Logos always sit in a neutral frame. Placeholders are a monogram crest, a trophy, screen plus initials, a satellite glyph, or initials, as in §12.
- Ad slot: Android only, above the bottom nav. The PWA layouts are complete without it.

## Content notes
- Fixtures, channels, frequencies, commentators and rights holders are real data from the 2026-10-28 snapshot.
- Live scores, match events, lineups, health metrics and admin names are sample values.
- Team crests are coloured placeholders, not real logos.
- "Varzesh TV HD" and "beIN SPORTS EN 1" appear in some app boards as sample channels, but they are on the old app's hidden-channels list. Do not treat their presence as a data requirement.
- «مدار» is a placeholder until O1 is decided.
