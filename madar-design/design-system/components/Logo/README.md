# Logo

The placeholder brand mark and wordmark, and the neutral frames every third-party logo sits in.

## Brand mark
An ink tile (`on-accent` ground, `radius-md`) with a volt orbit ring around a small satellite. Sizes 28, 40 and 64. On busy or volt grounds use the bare ring (`.mk.bare`) or the single-ink version (`.mk-mono`). The wordmark sets «مدار» in Changa 800 beside the mark, with an optional Latin `ADMIN` tag in mono for the admin.

These are placeholders until the product name is decided: keep the clear space (half the mark's width) and the sizes, swap the artwork.

## Entity placeholders
| Entity | Missing-logo fallback |
|---|---|
| Team | first letter inside a two-colour shield |
| Competition | trophy glyph |
| Channel | screen glyph plus up to three Latin letters |
| Satellite | satellite glyph |
| Commentator | initials in a circle |

All of them, and real logos, sit in the same neutral tile (`surface-2`, `radius-md`, inner `divider`) so mixed artwork looks intentional. Never place a logo directly on a coloured ground.

## Code
Flutter `BrandMark`, `TeamCrest`, `LogoTile` · CSS `.mk` (`.m40`, `.bare`), `.mk-mono`, `.wm`, `.crest`, `.lt` (`.l40`, `.l48`, `.ch`), `.av`.
