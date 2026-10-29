# ListRow

A settings or menu row: icon tile, title with optional subtitle, and a trailing value with chevron, or a toggle.

## Rules
- Rows group into `surface-1` cards with `divider` between them; group titles sit above in `text-caption`.
- The whole row is the target; a toggle row flips the toggle.
- Values are short («تلقائي», «داكن»); long choices open a sheet.

## Code
Flutter `MadarListRow(icon:, title:, subtitle:, trailing:)` · CSS `.lr`, `.ii`, `.tt`, `.sub`, `.val`, `.go`.
