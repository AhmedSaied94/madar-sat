# StatusBlock

The centre cell of every match row and hero: it shows exactly one of kickoff time, live score with minute, final score, or a status word.

## Variants
scheduled (12h with ص/م, or 24h by setting) · imminent (≤ 60 minutes: countdown in `accent-text`) · live (score + `live` pill with pulsing dot and minute) · halftime (`halftime` pill «استراحة») · extra time · penalties (shoot-out score in brackets) · finished («انتهت», score in `text-primary`) · postponed («تأجلت», `postponed`) · cancelled («أُلغيت», `cancelled`, struck through) · abandoned («توقفت») · estimated live (dashed `estimated` pill, no score: the clock says it should be live but no feed confirms it) · time unknown («لم يُحدد»).

## Rules
- One status at a time; the backend's status wins over the clock.
- Scores are two isolated numbers in a row, each beside its own team, so RTL never flips them.
- A score change flashes `accent-container` for 1.2s (static highlight with reduced motion).
- Kickoff time uses `row-time`; score uses `row-score`; both tabular.

## Code
Flutter `StatusBlock(status:, kickoff:, score:, minute:)` · CSS `.st`, `.tm1`, `.sc.live`, `.pill.p-live|p-ht|p-pp|p-mute|p-est|p-fin`, `.soon`.
