# TopBar

The bar at the top of every screen: the wordmark and search on root screens, or back, title and up to two actions on detail screens.

## Rules
- Root: wordmark at the start (right), search at the end.
- Detail: back (mirrored arrow), title in `heading-2` truncated to one line, then actions such as follow bell and share.
- 56px tall; actions are 48px targets.
- Becomes `surface-1` with a bottom `divider` once content scrolls under it.

## Code
Flutter `MadarTopBar.root()`, `MadarTopBar.detail(title:, actions:)` · CSS `.tb`, `.wm`, `.tb-t`, `.ib`.
