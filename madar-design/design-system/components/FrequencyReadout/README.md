# FrequencyReadout

The equipment-style display of a channel's tuning values (frequency, polarization, symbol rate), always left-to-right on a dark well.

## Anatomy
- **Well:** `readout-bg`, `radius-sm`, 1px `readout-line` outline.
- **Frequency:** `readout` colour, `readout` type style (Plex Mono 600, tabular), `readout-glow` as text shadow.
- **Polarization cell:** one letter, H, V, L or R, in its own outlined cell.
- **Symbol rate:** `readout-dim`.

## Sizes
| Size | Type style | Where |
|---|---|---|
| default | `readout` 13px | match rows, carriage rows, frequency lists |
| `lg` | `readout-lg` 19px | channel sheet, satellite header |
| `xl` | `readout-xl` 26px | desktop channel pane, satellite finder |

## States
default · copied (`success` outline, then the toast «تم نسخ التردد») · strongest and weakest frequency on a satellite · a note instead of values (`UHF 32`) · historical (dimmed, in frequency history).

## Rules
- Keeps its dark well in the light theme: it is a display, not a surface.
- Wrap it in an LTR isolate inside Arabic text; never reorder or translate the digits.
- Tap copies exactly `11843 H 27500`; long-press offers share.
- Screen readers hear «التردد 11843، أفقي، معدل الترميز 27500».

## Code
Flutter `FrequencyReadout(mhz:, polarization:, symbolRate:, size:)` · CSS `.fq` with `.lg`, `.xl`, `.ok`, `.dim`, `.note`, `.fq-good`, `.fq-bad`.
