# Banner

Inline and transient feedback: full-width banners, stale-data hints, the snackbar, the toast, and loading skeletons.

## Variants
- **Banners:** offline (neutral, shows data age), update available (volt icon, primary action), warning (`postponed`, e.g. notifications off).
- **Stale hint:** small clock glyph and the data age in `text-caption`, next to the thing that is stale.
- **Snackbar:** inverted (`text-primary` fill), one line, optional action in `snackbar-action`; for undoable actions («أُخفيت ... · تراجع»).
- **Toast:** short confirmation with a check («تم نسخ التردد»), 2 seconds.
- **Skeleton:** `surface-2` blocks in the shape of the content, shimmer off with reduced motion.

## Rules
- One banner at a time; offline outranks update, update outranks warning.
- Never block content with a banner; it pushes content down.

## Code
Flutter `MadarBanner`, `StaleHint`, `MadarSnackBar`, `MadarToast`, `Skeleton` · CSS `.bnr` (`.off`, `.upd`, `.warn`), `.stale`, `.snack`, `.toast`, `.sk`.
