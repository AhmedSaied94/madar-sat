# KpiCard

A dashboard figure: label with glyph, a big tabular number with its context, and an optional progress bar or link to the work behind it.

## Rules
- Lead with work to do (matches without channels, unresolved names), not vanity totals.
- The number takes `postponed` only when it needs attention; otherwise `text-primary`.
- Every card links to the filtered list it counts.

## Code
React `<KpiCard label value context progress href />` · CSS `.box.kpi`, `.k`, `.v`, `.bar`.
