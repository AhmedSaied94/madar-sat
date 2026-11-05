# Logo

The brand mark and wordmark, and the neutral frames every third-party logo sits in.

## Brand mark
A light planet inside a volt orbit ring, with a three-part satellite on the ring's upper end. The ring passes behind the planet on its far half and across it on its near half, with a clear band around the crossing. The vector is `mark.svg` (a 32-unit grid). Tile, sizes 28, 40 and 64: `on-accent` ground, `radius-md`. The bare mark (`.mk.bare`) is for dark wells; use the single-ink version (`.mk-mono`) on busy or volt grounds. The wordmark sets «مدار» in Changa 800 beside the mark, with an optional Latin `ADMIN` tag in mono for the admin.

Keep the clear space (half the mark's width). The splash and the store assets set the product name «مدار سات» instead of the wordmark.

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
