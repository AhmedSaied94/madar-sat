# CommentatorRow

The commentator for a channel's broadcast, with an optional short voice sample so users can tell broadcasts apart by voice.

## States
idle (play) · loading (spinner ring, `aria-busy`) · playing (pause, equalizer bars, progress) · error («تعذّر تشغيل المقطع», retry).

## Rules
- One clip plays at a time across the app; starting another stops the first.
- Playback starts only from a user tap, never automatically.
- No sample: the row shows the name only, without a play button.
- The play button is 40px visible inside a 48px target.

## Code
Flutter `CommentatorRow(commentator:, sampleUrl:)` · CSS `.cm`, `.lbl`, `.nm`, `.play` (`.ld`, `.on`, `.er`), `.eq`, `.prog`.
