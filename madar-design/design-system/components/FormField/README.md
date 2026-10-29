# FormField

A labelled admin input with hint and validation, including the locked state for values an editor protected from the importer.

## States
default · focus (`focus-ring` outline) · error (`error` outline and message under it) · locked (lock glyph in the label, hint «لن يغيّره الاستيراد») · disabled.

## Rules
- Labels sit above the input, never as placeholders.
- Validation runs on blur and on save; messages say what is valid («الاستقطاب يجب أن يكون H أو V أو L أو R»).
- Frequency inputs are mono and LTR.
- Saving with If-Match: a conflict opens the ConfirmDialog conflict variant instead of overwriting.

## Code
React `<Field label hint error locked>` · CSS `.fld`, `.in` (`.focus`, `.err`, `.lk`, `.ta`), `.hint` (`.e`), `.fgrid`.
