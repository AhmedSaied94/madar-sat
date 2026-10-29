# DataTable

The admin's dense, keyboard-first table for matches, channels, teams and the rest: sortable header, competition group rows, row actions on hover, bulk selection, warning rows and locked-field markers.

## States
header (sortable columns show a sort glyph) · group row (competition with count) · hover (`surface-2`, row actions appear) · selected (`accent` inset edge, bulk bar appears) · warning (`postponed-container`, e.g. no channels) · locked (lock glyph: an editor's value the importer will not overwrite).

## Rules
- Rows are 48px; numbers are tabular and end-aligned.
- Source chips show where a value came from (YSS, LST, SEZ, YK, API, يدوي).
- Keyboard: J and K move, X selects, E edits, Ctrl K searches everywhere.
- Bulk actions name their effect and count («حذف 20 مباراة»).

## Code
React `<DataTable columns rows groupBy selectable />` · CSS `.tw`, `.tbl` (rows `.grp`, `.sel`, `.warn`), `.cb`, `.bulk`, `.bb`, `.rowact`, `.src` (`.man`), `.lockc`.
