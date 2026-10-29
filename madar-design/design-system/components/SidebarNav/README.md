# SidebarNav

The admin's right-hand navigation: brand, grouped sections (content, operations, administration), counts that need attention, and the signed-in user.

## States
default · hover (`surface-2`) · active (`accent-container`, icon in `accent-text`) · focus · count badge (neutral; `postponed` for work waiting; `error` for a failing source) · V2 tag for planned sections.

## Rules
- 248px wide, fixed; content scrolls independently.
- Counts show work waiting (matches without channels, failing sources), not totals.
- V2 items are visible but marked, so editors know the plan.

## Code
React `<SidebarNav active="matches" />` · CSS `.side`, `.brand`, `.nav-g`, `.nav` (`.on`), `.n` (`.w`, `.r`), `.v2`, `.me`.
