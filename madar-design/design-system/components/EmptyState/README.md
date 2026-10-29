# EmptyState

What a screen shows when there is nothing to list or loading failed: the orbit-ring illustration, a title, one line of help and at most one action.

## Variants
empty (search glyph, neutral) · error (alert glyph on `error-container`, «إعادة المحاولة») · all clear (check glyph on `free-container`, e.g. no matches without channels in the admin).

## Rules
- Say what is missing and what to do; never blame the user.
- The illustration is the orbit motif only: rings and one small satellite dot, no scenes.
- One action at most, usually secondary.

## Code
Flutter `EmptyState(kind:, title:, body:, action:)` · CSS `.empty`, `.illus`.
