# MatchRow

One match in a list: home team, StatusBlock, away team, and under them the channel line that answers where it airs.

## Anatomy
- **Teams:** crest (24px in a neutral tile) and name in `text-label`; names may take two lines, then ellipsis. The home team sits on the right (RTL start).
- **StatusBlock** in the centre column, fixed width so rows align.
- **Channel line:** screen glyph, up to two channel names as LTR islands, a `+N` count, and the free marker when a free channel exists.
- **Markers:** bell for a reminder, star after a followed team's name.

## States
default · pressed (`surface-2`) · no channels yet (channel line omitted, never "unknown") · tennis and other individual sports (player names, no crests) · long-press opens quick actions (follow, remind, share).

## Rules
- Rows sit in a `surface-1` card grouped by competition, separated by `divider`.
- A channel on one of the user's satellites is listed first.
- Minimum row height 72px; the whole row is one target that opens Match detail.

## Code
Flutter `MatchRow(match:, onTap:, onLongPress:)` · CSS `.mr`, `.mr-g`, `.tmc` (`.away`), `.tmn`, `.chl`, `.free-m`, `.more-n`, `.bellm`.
