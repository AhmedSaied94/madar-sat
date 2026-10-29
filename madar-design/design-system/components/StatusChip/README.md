# StatusChip

Compact admin labels: notification send states, the data source a value came from, user roles, and source health.

## Variants
- **Send state:** أُرسل (`success`) · فشل (`error`) · جزئي (`warning`) · مجدول (neutral) · مباشر (`live`).
- **Source:** YSS, LST, SEZ, YK, API in mono; يدوي (manual) highlighted.
- **Role:** مدير (admin), محرر (editor).
- **Health:** سليم · قرب الحد · مفتوحة (circuit breaker open), with a dot.

## Code
React `<Stat kind>`, `<SourceChip>`, `<RoleChip>`, `<Health>` · CSS `.stat` (`.ok`, `.er`, `.wa`, `.nu`, `.lv`), `.src` (`.man`), `.role` (`.ed`), `.health` (`.ok`, `.half`, `.bad`).
