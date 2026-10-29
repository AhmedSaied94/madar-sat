# Token aliases

The screen stylesheets (`app-flutter/styles/app.css`, `admin-react/styles/admin.css`) use short variable names to keep the mockup CSS compact. Each one is a design-system token. When you read a value such as `background:var(--s1)` in a screen file, implement it with the token in the second column, never with a raw colour.

| Screen CSS | Design-system token (tokens.css) | Flutter (`MadarColors` / `MadarShadows`) |
|---|---|---|
| `--bg` | `--bg` | `bg` |
| `--live` | `--live` | `live` |
| `--free` | `--free` | `free` |
| `--info` | `--info` | `info` |
| `--s1` | `--surface-1` | `surface1` |
| `--s2` | `--surface-2` | `surface2` |
| `--s3` | `--surface-3` | `surface3` |
| `--el` | `--elevated` | `elevated` |
| `--segon` | `--segmented-on` | `segmentedOn` |
| `--ov` | `--overlay` | `overlay` |
| `--dv` | `--divider` | `divider` |
| `--dv2` | `--divider-strong` | `dividerStrong` |
| `--fr` | `--focus-ring` | `focusRing` |
| `--tx` | `--text-primary` | `textPrimary` |
| `--tx2` | `--text-secondary` | `textSecondary` |
| `--tx3` | `--text-tertiary` | `textTertiary` |
| `--txd` | `--text-disabled` | `textDisabled` |
| `--oninv` | `--text-on-inverse` | `textOnInverse` |
| `--ac` | `--accent` | `accent` |
| `--acc` | `--accent-container` | `accentContainer` |
| `--act` | `--accent-text` | `accentText` |
| `--onac` | `--on-accent` | `onAccent` |
| `--snk` | `--snackbar-action` | `snackbarAction` |
| `--livec` | `--live-container` | `liveContainer` |
| `--ht` | `--halftime` | `halftime` |
| `--htc` | `--halftime-container` | `halftimeContainer` |
| `--pp` | `--postponed` | `postponed` |
| `--ppc` | `--postponed-container` | `postponedContainer` |
| `--cx` | `--cancelled` | `cancelled` |
| `--est` | `--estimated` | `estimated` |
| `--freec` | `--free-container` | `freeContainer` |
| `--enc` | `--encrypted` | `encrypted` |
| `--encc` | `--encrypted-container` | `encryptedContainer` |
| `--sp` | `--sports` | `sports` |
| `--spc` | `--sports-container` | `sportsContainer` |
| `--en` | `--entertainment` | `entertainment` |
| `--enc2` | `--entertainment-container` | `entertainmentContainer` |
| `--rdb` | `--readout-bg` | `readoutBg` |
| `--rd` | `--readout` | `readout` |
| `--rd2` | `--readout-dim` | `readoutDim` |
| `--rdl` | `--readout-line` | `readoutLine` |
| `--rdg` | `--readout-glow` | `readoutGlow` |
| `--chg` | `--changed` | `changed` |
| `--chgc` | `--changed-container` | `changedContainer` |
| `--ok` | `--success` | `success` |
| `--warn` | `--warning` | `warning` |
| `--err` | `--error` | `error` |
| `--errc` | `--error-container` | `errorContainer` |
| `--sh` | `--shadow-raised` | `shadowRaised` |
| `--sh2` | `--shadow-subtle` | `shadowSubtle` |
| `--f-ui` | `--font-sans` | `MadarFonts.sans` |
| `--f-d` | `--font-display` | `MadarFonts.display` |
| `--f-m` | `--font-mono` | `MadarFonts.mono` |

In the screen files the values are set per theme by the `.t-dark` and `.t-light` classes at the top of `app.css`; the numbers match `tokens.json` exactly.
