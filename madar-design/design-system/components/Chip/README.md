# Chip

Filter chips for the match list (all, my matches, live) and the sport switcher, each with an optional count.

## States
default · hover · selected (inverted: `text-primary` fill, `text-on-inverse` label) · focus · disabled.

## Rules
- Single select within a row.
- Counts are tabular and dimmed; hide a count of zero rather than showing 0.
- The live chip carries the pulsing `live` dot, the only chip allowed a status colour.
- Rows scroll horizontally; never wrap to two lines on phone.

## Code
Flutter `FilterChipRow`, `SportSwitcher` · CSS `.chips`, `.chip` (`.on`, `.focus`), `.cnt`.
