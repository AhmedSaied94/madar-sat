# Badges

Small inline markers that answer "can I watch it, and where": access (free or encrypted), satellite, recent frequency change, on-my-satellites, and channel category.

## Variants
| Badge | Tokens | Copy |
|---|---|---|
| Free | `free` on `free-container`, unlock glyph | مجانية |
| Encrypted | `encrypted` on `encrypted-container`, lock glyph, optional provider | مشفرة · beIN |
| Satellite | `text-secondary`, satellite glyph | نايل سات |
| Changed recently | `changed` on `changed-container`, history glyph, date | تغيّر مؤخراً · 20 أكتوبر |
| On my satellites | `accent-text` on `accent-container`, dish glyph | على أقمارك |
| Category | `sports` / `entertainment` pills | رياضة · ترفيه |
| Count | `surface-3` pill, tabular | 171 |

## Rules
- Encrypted is neutral on purpose; it is information, not a warning.
- Every badge pairs colour with a glyph or a word, never colour alone.
- Badges are 11px (`text-micro`), `radius-sm`, and never wrap; truncate the provider first.

## Code
Flutter `AccessBadge`, `SatelliteBadge`, `ChangedBadge` · CSS `.ab.free`, `.ab.enc`, `.satb`, `.chgb`, `.mine`, `.pill.p-sp`, `.pill.p-en`, `.cnt-b`.
