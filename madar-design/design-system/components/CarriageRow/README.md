# CarriageRow

One channel carrying a match on one satellite: logo tile, channel name, access badge, satellite and FrequencyReadout; it expands in place to the full tuning details and actions.

## Anatomy
- **Collapsed:** channel tile (40px), name as an LTR island in `text-strong`, access badge at the end, then satellite badge and readout on the second line, chevron.
- **Expanded:** a details grid (satellite and orbital position, frequency in MHz, polarization in words, symbol rate, access, category), the CommentatorRow when known, and actions: copy frequency, follow channel, how to receive this satellite, view channel.

## Rules
- Rows on the user's satellites are grouped first under «على أقمارك».
- Only one row is expanded at a time.
- Copy is the primary action and also happens on tapping the readout.
- Platforms without a satellite (streaming, regional) go in a RegionGroup instead, without a readout.

## Code
Flutter `CarriageRow(carriage:, expanded:)` · CSS `.cr` (`.open`), `.bd`, `.l1`, `.l2`, `.cn`, `.xd`, `.acts`, `.chev`.
