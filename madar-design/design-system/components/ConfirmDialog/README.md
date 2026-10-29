# ConfirmDialog

Admin modals for the two moments that must not be clicked through: destructive bulk actions (typed confirmation) and edit conflicts (If-Match failed).

## Variants
- **Typed confirmation:** the action stays disabled until the editor types the phrase shown («حذف 20»).
- **Conflict:** names who saved first and when, shows the field diff, and offers: view changes, re-apply my edits, discard my edits.

## Rules
- State the scope and consequence in numbers (20 matches, their channels and follows).
- Never default focus to the destructive button.

## Code
React `<ConfirmDialog phrase>`, `<ConflictDialog diff>` · CSS `.mdl`, `.diff` (`.ln.add`, `.ln.del`).
