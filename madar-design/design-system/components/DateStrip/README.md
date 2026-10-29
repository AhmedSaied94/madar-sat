# DateStrip

The horizontal day picker at the top of Matches: weekday plus date number per cell, today marked, one day selected.

## States
default · pressed (`surface-2`) · today (dot marker) · selected (`accent` fill, `on-accent` text) · keyboard focus (`focus-ring`). A «اليوم» button appears when the selected day scrolls out of view.

## Rules
- Days run right to left (RTL), today centred on open.
- Cells are 44px wide and 56px tall; the whole cell is the target.
- Weekday labels are short Arabic names; «اليوم» replaces today's name.

## Code
Flutter `DateStrip(days:, selected:, onSelect:)` · CSS `.ds`, `.dcell` (`.today`, `.on`, `.focus`), `.today-btn`.
