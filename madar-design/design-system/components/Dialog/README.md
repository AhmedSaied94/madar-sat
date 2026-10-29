# Dialog

A modal confirmation for irreversible actions only, such as deleting device data. Everything else uses a bottom sheet or an undo snackbar.

## Anatomy
`elevated` panel, `radius-2xl`, `shadow-raised`, over `overlay`. Title in `heading-2`, one or two lines of consequence in `text-secondary`, then actions at the end: ghost cancel and the action itself (danger for deletes).

## Rules
- The action button repeats the verb in the title («حذف»), never «نعم».
- Back and tapping the scrim cancel.
- Focus moves to the dialog and returns to the trigger on close.

## Code
Flutter `showMadarDialog(...)` · CSS `.dlg`.
