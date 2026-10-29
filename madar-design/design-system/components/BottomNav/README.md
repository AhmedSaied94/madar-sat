# BottomNav

The phone app's five root destinations: Matches, My satellites, Frequencies, Favorites, More.

## Anatomy
Icon in a pill indicator (`accent-container` when active, icon in `accent-text`), label in `text-micro` under it. The Favorites badge counts followed matches that are live right now, so it is the one badge in `live`.

## Rules
- Always five items, in this order, right to left.
- 66px tall above the system gesture area; on Android the ad slot sits above it only after an ad loads.
- Tapping the active item scrolls its list to the top (Matches: back to today).
- Desktop web replaces it with a 92px navigation rail on the right.

## Code
Flutter `MadarBottomNav(current:)` · CSS `.bn`, `.pi`, `.bdg`.
