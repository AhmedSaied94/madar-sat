# Implementation review: 003-d03-follow-push-sources, lane A, round 2

- Date: 2026-11-01 · Reviewer: Claude Code (Opus 5.5 lead; Sonnet typescript-reviewer subagent; every CRITICAL/HIGH re-read by the lead)
- Branch: 003-d03-follow-push-sources (all four lanes' round-1 fixes merged; no lane branch checked out, as in round 1) · Base: master (merge base 5323669) · Head: 5cd804f, plus 0 uncommitted files
- Change: 31 commits, 485 files in all (66 lane A), +54040 −957. Round-1 fix commit: 2dc4f2a
- Verdict: **CHANGES REQUESTED** · CRITICAL 0 · HIGH 2 (both carried from round 1, still open, blocked on lane B1) · MEDIUM 5 new (plus round-1 ones open) · LOW 3 new

## Checks
| Check | Command | Result |
| --- | --- | --- |
| install | `cd admin && pnpm install --frozen-lockfile` | exit 0 |
| tsc | `pnpm typecheck` | exit 0 |
| eslint | `pnpm lint` | exit 0, 0 errors, 6 warnings (D2 files, as in round 1) |
| vitest | `pnpm test` | first run exit 1: a vitest worker crashed ("Worker exited unexpectedly") while the backend pytest and `flutter analyze` ran in parallel; rerun alone: exit 0, 27 files, 236 tests passed |
| build | `pnpm build` | exit 0 |
| literals, token copy | `./scripts/check-literals.sh`; `./scripts/check-token-copy.sh` | exit 0, exit 0 |
| Generated client matches the spec | — | NOT RUN: rewrites tracked files; `src/api/generated/` and `backend/openapi/admin.json` are untouched by 2dc4f2a |
| Playwright | — | NOT RUN: arrives on D4 (delivery-plan §7) |
| Ways around the checks | diff scan of 2dc4f2a | none: no `eslint-disable`, `@ts-*`, `any`, `!`, skip/only, config change; the placeholder-completion test was replaced by a locked-state test, as A-R1-5's task allowed |

## Previous round
| Finding | Now |
| --- | --- |
| A-R1-1 reorder reads versions at save time | **still open** (task unticked): `CompetitionsPage.tsx:40-46`, `SatellitesPage.tsx:37-46` still `getCompetition`/`getSatellite` per row at save; the list rows have no `etag`. Blocked on lane B1 (B1-R2-2) |
| A-R1-2 409 refetch then silent overwrite | fixed: every editor keeps the ETag with its baseline (`adopt()`), opens `ConflictDialog` via `lib/conflict.ts:55-68`, blocks a second Save; one test per editor |
| A-R1-3 A10 delete without `If-Match` | fixed: `CommentatorsPage.tsx:43-64`; test answers 428 without the header |
| A-R1-4 no RHF + Zod | fixed in structure (all five editors, Arabic error map in `lib/validation.ts`); coverage partial (MEDIUM A-R2-3) |
| A-R1-5 placeholder → satellite channel | **still open** (task unticked); admin half done: the carriage select is disabled and explained for platform rows (`ChannelEditor.tsx:199-202,356-386`), test `ChannelsPage.test.tsx:153`. Blocked on lane B1 (B1-R2-2) |
| A-R1-6 logo on dark and light | fixed: `LogoField.tsx:35-59`, test `TeamsPage.test.tsx:222` |
| A-R1-7 satellite ordering untested | fixed: `SatellitesPage.test.tsx:98,149,172,204` |
| A-R1-8 readout not the dark cyan well | fixed: `FrequencyReadout.tsx:52-63`, tests incl. both themes |
| Round-1 MEDIUM/LOW | fixed: orbital position/half-ticked frequency, A10 unsaved guard, upload focus, A10 test vs contract. Still open: lists truncate at 100; source chip ignores `paused`; times print twice; A10 no player; `SortableList` snap-back; English dnd-kit/aria labels; radio focus rings; A13 "items found"; `AudioPlayer` stall; keyboard reorder discoverability; A6/A7 loading/error states; run history not polling; no screenshots (T106/T107 honestly open); A-F2 partial; aliases and A10 filters contract gaps; and the LOW casts |

## Findings
### CRITICAL
None.

### HIGH
No new HIGH. A-R1-1 and A-R1-5 stay open as HIGH under their existing round-1 tasks (unticked, so no new task is added); both wait on lane B1's contract change, now raised as B1-R2-2 in lane B1's section. T101 and T097 stay ticked while their scenarios are not fully met: they close with A-R1-1 and A-R1-5.

### MEDIUM
- **A-R2-1 Nested modals may fight over Tab and Escape during a conflict** (PLAUSIBLE). `components/ConfirmDialog/Modal.tsx:47-72` gives every open Modal its own `document` keydown trap; `ConflictDialog` now opens over `EditorDrawer` in every editor. If the dialog is not inside the drawer's panel, Tab is pulled back and forth and Escape also runs the drawer's close. Settle in a browser; make only the top-most modal handle keys.
- **A-R2-2 No test proves a save after a refetch still uses the load-time ETag.** Conflict stubs answer 409 whatever `If-Match` they get; after a dismiss the `if (conflict) return` guard is off, so a regression to the live ETag would overwrite with no failing test. Stub 409 unless `If-Match` equals the load-time ETag; add dismiss-then-save.
- **A-R2-3 Validation draws only `name` from the generated bodies.** `stadium`, `country`, `display_name`, `provider`, `package` are plain `z.string()` while the generated maxima exist (`admin.zod.ts:204,216`); a 300-char value still gets the generic «راجع البيانات المدخلة».
- **A-R2-4 A10's in-use refusal prints the stale list count.** `CommentatorsPage.tsx:59` shows `person.usage.matches` from the row, not the 409's `meta.usage` (four counts, `services/admin/commentators.py:115-125`); the stub's meta shape is one the API never sends; the confirm copy (`ar.ts:568`) still promises a removal the server refuses.
- **A-R2-5 A8 still offers save paths the API refuses.** Switching a satellite channel to «بدون قمر» sends `satellite_id:null`, `frequency:null` and gets 422 `required` (`channels.py:116-117`); a half-typed frequency with "show on match pages" off is dropped with no toast (`ChannelEditor.tsx:127-137,306-309`); no test now PATCHes a carriage on a satellite channel.

### LOW
- L1 the satellite slug check also applies on edit (`SatelliteEditor.tsx:62-66`) though the slug is create-only.
- L2 "Discard my changes" keeps the old ETag, so the next save is a 409 until Reload (documented behaviour).
- L3 five `zodResolver(...) as Resolver<…>` casts.

## Requirements
| Requirement | Built in | Proven by | Status |
| --- | --- | --- | --- |
| US4 sc. 1–2 editors A5–A8, A10 | `features/{teams,competitions,satellites,channels,commentators}` | page tests | Built |
| US4 sc. 3–4 reorder with stale detection | `CompetitionsPage.tsx`, `SatellitesPage.tsx` | `*Page.test.tsx` (current behaviour only) | **Partial (A-R1-1, blocked on B1-R2-2)** |
| US4 sc. 5 placeholder completion | `ChannelEditor.tsx` | `ChannelsPage.test.tsx:153` (locked state) | **Partial (A-R1-5, blocked on B1-R2-2)** |
| US4 sc. 9 conflict never overwrites | five editors + `lib/conflict.ts` | one test per editor | Built (test gap A-R2-2) |
| A13/A15 sources and dashboard | `SourcesPage.tsx`, dashboard | page tests | Built (round-1 MEDIUMs open) |

## Task audit
Round-1 tasks: ticked 6, verified 6; A-R1-1 and A-R1-5 honestly unticked. Original tasks: T101 and T097 ticked but partly not done (tracked by A-R1-1, A-R1-5).

## Owner must review
- Each A5–A8/A10 editor and A6/A7 lists next to their design PNGs (no screenshots yet: T106/T107).
- `admin/src/lib/conflict.ts` and the editors' baseline/ETag pairing: the guarantee that a stale save never overwrites.

## Outside this change
None.

## Not reviewed
- Browser rendering, contrast and keyboard flow (A-R2-1 needs a browser); the real `PUT …/order` against the deployed API.
