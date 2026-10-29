# Button

Actions in five emphasis levels, plus the follow and bell toggles used on teams, competitions and channels.

## Variants
| Variant | Use | Tokens |
|---|---|---|
| primary | the one main action on a screen | `accent` fill, `on-accent` text |
| secondary | common actions (copy, share) | `surface-2` fill |
| outline | alternative paths (view channel) | `divider-strong` outline |
| ghost | skip, cancel, low emphasis | text only |
| danger | delete, reset | `error` on `error-container` |

Sizes: default 48px, `sm` 40px, `xs` 32px (inside rows); all keep a 48px target. States: hover, pressed, focus (`focus-ring`), disabled (`surface-3`, `text-disabled`), busy (spinner and a verb in the present: «جارٍ الحفظ»).

## Follow and bell
FollowButton toggles «تابع» / «تتابعه» with an outline star that fills. BellButton toggles reminders: off, on (filled, `accent-text`), muted.

## Rules
- One primary per screen or sheet.
- Labels are verbs, two words at most.
- Icon-only buttons need an accessible label.

## Code
Flutter `MadarButton(variant:, size:)`, `FollowButton`, `BellButton` · CSS `.btn` with `.btn-p|-s|-o|-g|-d`, `.btn-sm|-xs`, `.dis`, `.focus`; `.fb` (`.on`); `.ib.fill` (`.on`).
