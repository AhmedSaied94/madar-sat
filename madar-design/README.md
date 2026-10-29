# Madar UI design — implementation package

The complete UI design for «مدار» (working name, open decision O1), exported 2026-10-29. It covers:

| Folder | What it is |
|---|---|
| [`design-system/`](design-system/) | The Madar Design System: tokens (JSON, CSS, Dart, TypeScript), brand book, 24 documented components, fonts. |
| [`app-flutter/`](app-flutter/SCREENS.md) | The Flutter app: 46 boards covering S0–S16, desktop web and V2 concepts, each as PNG + HTML. |
| [`admin-react/`](admin-react/SCREENS.md) | The React admin: 21 boards covering A0–A17, login and shared states, each as PNG + HTML. |
| [`HANDOFF.md`](HANDOFF.md) | The design handoff note: direction, key tokens, conventions, data caveats. |

Specs come from `new_app/docs/product-business.md` (screens S0–S20, A0–A17, §13 design system) and `new_app/docs/system-design.md`.

```
madar-design/
├── README.md                     ← you are here
├── HANDOFF.md
├── design-system/
│   ├── README.md                 brand book: principles, colour roles, type, RTL, voice, accessibility
│   ├── tokens.json               SOURCE OF TRUTH for every colour, type style, space, radius, shadow
│   ├── tokens.css                generated: CSS custom properties + one class per type style
│   ├── TOKEN-ALIASES.md          short names used in the screen CSS → token names → Dart fields
│   ├── components.css            component classes used by the previews (app + admin), bound to tokens.css
│   ├── components/
│   │   ├── INDEX.md              every component, its code name and the CSS classes that draw it
│   │   └── <Component>/          README.md (spec) · preview.html · preview-dark.png · preview-light.png
│   ├── code/
│   │   ├── flutter/madar_tokens.dart   generated ThemeExtensions, text styles, spacing, radii, buildMadarTheme()
│   │   ├── react/tokens.ts             generated typed tokens for the admin
│   │   └── generate_tokens.py          regenerates tokens.css, .dart and .ts from tokens.json
│   ├── fonts/                    Changa, IBM Plex Sans Arabic, IBM Plex Mono (TTF, OFL) + fonts.css
│   └── cover/                    the system's cover image
├── app-flutter/
│   ├── SCREENS.md                index: screen ID → files, size, default theme, notes
│   ├── styles/app.css            the stylesheet every app screen uses (all measurements live here)
│   └── screens/<NN-section>/<Board>.png|.html
└── admin-react/
    ├── SCREENS.md
    ├── styles/app.css, admin.css
    └── screens/<NN-section>/<Board>.png|.html
```

## How to use this when implementing (for Claude Code and developers)

Read in this order, and treat each layer as the authority for what it covers:

1. **Tokens decide values.** Colours, type, spacing, radii and shadows come only from `design-system/tokens.json`, through the generated files: `madar_tokens.dart` in Flutter, `tokens.css` / `tokens.ts` in the admin. Never copy a hex value or a pixel size out of a screen file; find the token it stands for (`TOKEN-ALIASES.md` maps the short names such as `--s1` or `--tx2`).
2. **Component READMEs decide behaviour.** States, rules, accessibility and naming for each reusable piece are in `design-system/components/<Component>/README.md`. Build each component once and reuse it. `components/INDEX.md` tells you which CSS classes in a screen are which component.
3. **Screen HTML decides structure and content.** Each `screens/**/<Board>.html` is a static snapshot of a design board: element order, hierarchy, Arabic copy, which states appear, and exact measurements via the classes in `styles/`. It is mockup HTML, not production markup: rebuild it with real widgets and components; do not paste it.
4. **Screen PNG shows the intended result.** Use it to check your build visually. Phone boards are at 2× (720 px wide for a 360 dp screen).

When building a screen, open its row in `SCREENS.md`, look at the PNG, read the HTML, then implement it from tokens and components.

### Rules that are easy to get wrong

- **RTL first.** Arabic is the layout direction everywhere. Back arrows point right. Home team sits on the right.
- **LTR islands.** Channel names, satellite positions, frequencies and source codes are left-to-right inside Arabic text: wrap them in an LTR isolate (`Directionality`/`TextDirection.ltr` or `<bdi dir="ltr">`). When one is too long it truncates at its own end, keeping the start visible.
- **Frequency readout.** `11843 H 27500` in IBM Plex Mono on a dark well with cyan digits, in both themes. It never flips direction and never changes colour with the theme.
- **Red means live.** `live` is only for live matches. Errors, red cards, failures and deletes use `error`.
- **One accent per screen.** Volt (`accent`) marks the single most important action or selection.
- **Honest data.** Unknown kickoff shows «لم يُحدد»; estimated live has a dashed pill and no score; stale data shows its age. Never invent a value to fill a gap.
- **Western digits, tabular figures** for all times, scores and counts.
- **Touch targets** are at least 48 dp even when the visible shape is smaller.

### Flutter setup

1. Copy `design-system/code/flutter/madar_tokens.dart` to `lib/theme/madar_tokens.dart`.
2. Copy the TTFs from `design-system/fonts/` to `assets/fonts/` and declare them:

```yaml
flutter:
  fonts:
    - family: Changa
      fonts:
        - { asset: assets/fonts/Changa-Regular.ttf, weight: 400 }
        - { asset: assets/fonts/Changa-Medium.ttf, weight: 500 }
        - { asset: assets/fonts/Changa-SemiBold.ttf, weight: 600 }
        - { asset: assets/fonts/Changa-Bold.ttf, weight: 700 }
        - { asset: assets/fonts/Changa-ExtraBold.ttf, weight: 800 }
    - family: IBM Plex Sans Arabic
      fonts:
        - { asset: assets/fonts/IBMPlexSansArabic-Regular.ttf, weight: 400 }
        - { asset: assets/fonts/IBMPlexSansArabic-Medium.ttf, weight: 500 }
        - { asset: assets/fonts/IBMPlexSansArabic-SemiBold.ttf, weight: 600 }
        - { asset: assets/fonts/IBMPlexSansArabic-Bold.ttf, weight: 700 }
    - family: IBM Plex Mono
      fonts:
        - { asset: assets/fonts/IBMPlexMono-Regular.ttf, weight: 400 }
        - { asset: assets/fonts/IBMPlexMono-Medium.ttf, weight: 500 }
        - { asset: assets/fonts/IBMPlexMono-SemiBold.ttf, weight: 600 }
```

3. Wire the theme and Arabic locale:

```dart
MaterialApp(
  theme: buildMadarTheme(Brightness.light),
  darkTheme: buildMadarTheme(Brightness.dark),
  themeMode: ThemeMode.system, // user setting: system / light / dark (S15)
  locale: const Locale('ar'),
  supportedLocales: const [Locale('ar')],
  localizationsDelegates: GlobalMaterialLocalizations.delegates,
  // ...
);

// in widgets
final c = context.madarColors;
Text('8:00', style: MadarText.rowTime.copyWith(color: c.textPrimary));
Container(decoration: BoxDecoration(color: c.surface1, borderRadius: BorderRadius.circular(MadarRadii.xl)));
```

### React admin setup

1. Copy `design-system/tokens.css` and `design-system/fonts/` into the admin and load `fonts/fonts.css` and `tokens.css` globally.
2. Set `<html lang="ar" dir="rtl" data-theme="dark">` and switch `data-theme` to `light` for the light theme.
3. Style components with the token variables (`var(--surface-1)`, `var(--space-4)`, `var(--radius-lg)`) or the type classes (`.text-body`, `.readout`). Use `code/react/tokens.ts` where JavaScript needs a value (charts, canvas).
4. `components.css` shows how each component was drawn in the mockups. Use it as a reference, not as the production stylesheet.

### Changing tokens

Edit `design-system/tokens.json`, then run `python3 design-system/code/generate_tokens.py`. That rewrites `tokens.css`, `madar_tokens.dart` and `tokens.ts`. Copy the regenerated files into the apps.

## Suggested CLAUDE.md lines

Add to the project's `CLAUDE.md`, adjusting the path to where you unzip this:

```md
## UI design
- The design package is in `design/madar-design/`; start with its README.md.
- Use design tokens only: `lib/theme/madar_tokens.dart` (Flutter) and `tokens.css` (admin). No raw colours, sizes or font names in widgets.
- Before building or changing a screen, open its PNG and HTML listed in `app-flutter/SCREENS.md` or `admin-react/SCREENS.md` and match structure, copy, states and spacing.
- Reuse the components in `design-system/components/` (see INDEX.md); follow each README's states and rules.
- RTL first; Latin names and frequencies are LTR islands; red is only for live; the frequency readout stays dark in both themes.
```

## Live sources

The editable originals are on claude.ai: the app canvas (https://claude.ai/artifact/CMHz4rrdB4r149NGLADxyE), the admin canvas (https://claude.ai/artifact/6DJjgPAeXeXYb7YnpQgdCy) and the design system (https://claude.ai/artifact/6T3Jt4odvH1Qniu38SrY5m). This package is a snapshot; re-export it after design changes.
