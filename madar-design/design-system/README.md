# Madar

The design system for «مدار», the Arabic-first app that answers one question fast: **which channel shows this match, and how do I tune it?** It serves the Flutter app (Android, iOS PWA, desktop web) and the React admin. «مدار» is a working name until the product name is decided (open decision O1); every mark here is a placeholder built to be swapped.

## Direction: broadcast control room

The interface borrows from the equipment people tune their dishes with: dark ink surfaces, one electric volt accent, and frequency values shown on a dark readout well like a receiver display. It should feel precise and calm, never like a betting app or a sports news site.

1. **The answer first.** On every match the channel, its satellite and its readout are one glance away. Decoration never sits between the user and `11843 H 27500`.
2. **One accent.** `accent` (volt #C8F542) marks the single most important action or selection on a screen. If two things are volt, one of them is wrong.
3. **Red means live.** `live` is reserved for live matches: the pill, the pulsing dot, the minute. Errors use `error`, which is a different red and never pulses.
4. **Readouts are hardware.** The frequency readout keeps its dark well and cyan digits in both themes. It is a display, not a surface.
5. **Arabic is the layout, Latin is an island.** Everything is laid out right-to-left. Channel names, frequencies, scores in some contexts and source codes are left-to-right islands, isolated so they never reorder the sentence around them.
6. **Data is honest.** Unknown stays unknown («لم يُحدد»), estimated live is shown as estimated, stale data says how old it is. Never fill a gap with a plausible guess.

## Color

Dark is the primary theme; light is a full theme, not an afterthought. Both are defined token by token in `tokens.json`. The component stylesheet uses short aliases (`--s1`, `--tx2`, `--rd`…), bound to these tokens in `components/bundle.css`.

| Role | Tokens | Rule |
|---|---|---|
| Ground and surfaces | `bg`, `surface-1` to `surface-3`, `elevated` | Cards sit on `bg`; sheets and dialogs use `elevated` with `shadow-raised`. Separate with `divider`, not borders. |
| Text | `text-primary`, `text-secondary`, `text-tertiary`, `text-disabled` | Tertiary is the smallest text colour allowed for content (4.5:1 on `surface-1`). Disabled is for disabled controls only. |
| Brand | `accent`, `accent-container`, `accent-text`, `on-accent` | Volt fill always carries `on-accent` text. In light theme volt as text becomes `accent-text` (#3F6A06) so it stays legible. |
| Match status | `live`, `halftime`, `postponed`, `cancelled`, `estimated` and their containers | One status per match, shown by StatusBlock only. |
| Access | `free`, `encrypted` | Free is green and positive; encrypted is neutral grey with a lock, never an error colour. |
| Readout | `readout-bg`, `readout`, `readout-dim`, `readout-line`, `readout-glow` | Only inside FrequencyReadout and satellite-finder values. |
| Feedback | `success`, `warning`, `error`, `info`, `changed` | `changed` (violet) flags a frequency that changed recently. |

## Typography

Three families, all on Google Fonts, all with Arabic and Latin coverage where it matters:

- **Changa** (`display`): headings, team names in the hero, kickoff times and scores. Bold and squared, it carries the control-room voice.
- **IBM Plex Sans Arabic** (`sans`): all UI and body text.
- **IBM Plex Mono** (`mono`): frequency readouts, source codes, admin logs. Always LTR, tabular figures.

Body is 14px with 1.6 line height; nothing goes below 11px. Times and scores use tabular, lining figures so a column of matches does not jitter. The app supports system font scaling to 1.3× without truncating team names: two lines are allowed, then ellipsis.

## Space, shape and depth

- 4px grid. The phone gutter is 16px and cards sit 12px from the screen edge. Every control has a 48px touch target, even when the visible shape is smaller.
- Radius grows with the size of the thing: badges `radius-sm` (7), inputs and small buttons `radius-md` (10), buttons `radius-lg` (14), cards `radius-xl` (18), sheets and dialogs `radius-2xl` (26), chips and pills `radius-pill`.
- Depth is quiet. Cards are flat on the ground with a hairline; only floating layers (sheets, dialogs, menus, toasts) get `shadow-raised`.

## Motif: the orbit

«مدار» means orbit. The mark is a volt orbit ring around a small satellite on an ink tile, and the same concentric rings appear in empty states, the splash screen and the login screen. Use rings sparingly: one cluster per screen, never behind data.

## Logos and placeholders

The product shows hundreds of team, competition and channel logos it does not own. Every logo sits in a neutral frame (`surface-2` tile, `radius-md`, inner hairline) so mismatched artwork looks intentional. When a logo is missing:

- Team: the first letter inside a two-colour shield (the club colours when known, otherwise neutral).
- Competition: a trophy glyph.
- Channel: a small screen glyph plus up to three Latin letters (`ON`, `bS1`).
- Commentator: initials in a circle.

## Iconography

24px grid, 1.8px stroke, round caps, drawn as outlines and filled only for the "on" state of a toggle icon (bell, star). Icons take `currentColor`. Directional icons (back, chevrons) mirror in RTL; media, clocks and the satellite do not.

## Voice

Short, direct Arabic. Say what happened and what to do next. Numbers stay as Western digits (0–9) everywhere, matching how channels publish frequencies.

| Say | Not |
|---|---|
| مباشر · استراحة · انتهت · تأجلت · أُلغيت | live / LIVE in Latin letters |
| مجانية · مشفرة | مفتوحة · مقفولة |
| التردد · الاستقطاب · معدل الترميز | فريكونسي |
| تابع / تتابعه | اشترك / مشترك |
| لم يُحدد بعد | — or a guessed time |
| تعذّر تحميل البيانات · إعادة المحاولة | حدث خطأ ما |

## Accessibility

- Text contrast is 4.5:1 or better in both themes; the readout digits are more than 12:1 on their well.
- Status is never colour alone: live has a dot and the word, encrypted has a lock, changed has a clock-history glyph.
- Focus is a 2px `focus-ring` outline with a 2px offset on web and admin.
- Screen readers get full sentences: «الأهلي ضد الزمالك، مباشر، الدقيقة 67، النتيجة 1 مقابل 0».
- Respect reduced motion: the live pulse and score flash become a static highlight.

## Platforms

- **Flutter app:** tokens become a `ThemeExtension` (`MadarColors`, `MadarType`, `MadarSpace`) generated from `tokens.json`, with dark and light instances. Widget names match the component names here (`MatchRow`, `StatusBlock`, `FrequencyReadout`, `CarriageRow`…). The 360px phone is the design baseline; desktop web uses a 92px navigation rail and a 420px list pane beside the detail pane.
- **React admin:** load `tokens.css`, then `components/bundle.css`; set `data-theme` on `<html>`. The admin is desktop-first, RTL and dense (13.5px base), with the sidebar on the right.
