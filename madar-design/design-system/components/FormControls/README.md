# FormControls

The app's input controls: search field, segmented control, toggle, radio, checkbox and stepper.

## Controls
- **Search field:** `surface-2`, `radius-lg`, 48px; a clear button appears with text. Results update as you type after 2 characters.
- **Segmented control:** `surface-2` track, selected segment `segmented-on` with `shadow-subtle`. Two to four options.
- **Toggle:** off `surface-3`, on `accent` with `on-accent` knob. Used in settings rows; the row label is the target.
- **Radio and checkbox:** `divider-strong` outline off, `accent` fill on.
- **Stepper:** font size and similar ordered values; shows the value in words.

## Rules
- Every control has a visible label or sits in a row whose label names it.
- Disabled controls drop to 40% opacity and stay readable.

## Code
Flutter `SearchField`, `Segmented`, `MadarSwitch`, `MadarRadio`, `MadarCheckbox`, `Stepper` · CSS `.sf`, `.seg`, `.tg`, `.rad`, `.tick`, `.stepper`.
