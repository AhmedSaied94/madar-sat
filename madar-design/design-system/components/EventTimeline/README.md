# EventTimeline

The live and finished match timeline: events on either side of a centre spine of minutes, home on the right, away on the left.

## Event types
goal · own goal · penalty scored · penalty missed · red card. Yellow cards and substitutions are not shown in V1.

## Rules
- The minute sits on the spine in mono (`45+2′`), LTR.
- Goals and penalties use `accent-container` tiles with `accent-text` glyphs; red cards use `error`; misses use `text-tertiary`.
- Player names in `text-strong`, event type in `text-caption`.
- Newest event at the top while live; chronological once finished.

## Code
Flutter `EventTimelineItem(event:)` · CSS `.tl`, `.ev`, `.e` (`.a` for away), `.ei` (`.goal`, `.miss`, `.red`), `.m`.
