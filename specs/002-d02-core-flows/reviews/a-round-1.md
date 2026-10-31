# Implementation review: 002-d02-core-flows, lane A, round 1

- Date: 2026-10-31 · Reviewer: Claude Code, Opus 5.5 (`claude-opus-5-5`); layer subagents on Sonnet, every finding re-checked here
- Branch: `d02-features` (the four D2 lane PRs, #8–#11, merged into it; not yet on `master`) · Base: `master` (merge base `68f1752`) · Head: `6f81c90`, clean tree
- Change (lane A): 3 commits (`638d4f0`, `b96f1e4`, `168ffa4`, merged as PR #10), 39 files under `admin/` (+13352 −74), plus `docs/owner-actions.md` and Lane A's section of `tasks.md`. Nothing in another lane's folder; `admin/src/api/generated/` changed only in B1's `da17913`.
- Verdict: **CHANGES REQUESTED** · CRITICAL 0 · HIGH 11 · MEDIUM 16 (3 PLAUSIBLE) · LOW 9 (1 PLAUSIBLE)

The plumbing is good:
- the in-memory token, the single-flight refresh and CSRF;
- a Zod schema for each of the 41 operations;
- Cairo time through `date-fns-tz`, with Western digits;
- no `any` or `!`, and no generated file edited by hand.

What it shows the editor doesn't yet work against the real API. Every save of an existing match ends in `428`, because the version read sends no bearer token. Every bulk action fails the same way. «إضافة مباراة» can't save. When the version read is fixed, a second save in the same session conflicts with itself, and a stale view can overwrite another editor's change. The 136 tests pass because the MSW handlers never check `Authorization`.

## Checks

The checks ran in `admin/`, in a `git archive` copy of HEAD `6f81c90`.

| Check | Command | Result |
| --- | --- | --- |
| install | `pnpm install --frozen-lockfile` | exit 0 |
| typecheck | `pnpm typecheck` | exit 0 |
| lint | `pnpm lint` | exit 0, with 26 warnings: 25 `tailwindcss/enforces-shorthand` and 1 `react-hooks/exhaustive-deps` at `MatchesPage.tsx:144` |
| test | `pnpm test` | exit 0: 16 files, 136 tests |
| build | `pnpm build` | exit 0 |
| client current | `pnpm orval && git status --porcelain -- src/api/generated` | exit 0, no diff |
| icons generated | `node scripts/extract-icons.mjs ../madar-design/admin-react/styles/app.css <scratch>/icons.regen.ts` then `diff` with `src/components/Icon/icons.ts` | identical |
| literals | `./scripts/check-literals.sh` | **NOT RUN**: the lean-ctx shell allowlist blocks it and the run was declined. To run it: `lean-ctx allow check-literals.sh` |
| token copy | `./scripts/check-token-copy.sh` | **NOT RUN**: same. To run it: `lean-ctx allow check-token-copy.sh` |
| T107 steps 2–4 (Prism `?mock=`, `pnpm dev:wg` over WireGuard, screenshots) | | **NOT RUN**: owner steps (A-F5) |

I scanned the diff for ways around the checks. Hand-written code has no `eslint-disable`, `@ts-expect-error`, `@ts-ignore`, `.skip(`, `.only(` or `: any`. The 16 new `no-redeclare` disables are all in Orval's output. ESLint, tsconfig, Tailwind and the vitest config are unchanged.

## Findings

### CRITICAL

None. A-R1-3 becomes CRITICAL if A-R1-1 is fixed on its own, so fix them together.

### HIGH

#### A-R1-1: the version read sends no bearer token, so every save of an existing match and every bulk action fails
- Layer `admin` · Source US4 scenarios 3 and 8, FR-009, FR-031, FR-034 ("Zod validates every response"), constitution VIII · `admin/src/api/http.ts:224-231` (`getEntityEtag` calls `http.get` on the bare instance from `:138`, which has no interceptor); the bearer is added only inside `requestWithRetry` (`:175-182`); used at `admin/src/features/matches/MatchEditor.tsx:250-252` and `BulkBar.tsx:30-34` · CONFIRMED
- Failure scenario: the editor opens `/matches/48213`. The ETag GET gets `401`, and `.catch(() => setEtag(null))` swallows it. PATCH goes out with no `If-Match`, the API answers `428 precondition_required`, and reloading changes nothing. In A3 both bulk actions toast «فشل الحفظ». The path also skips the `token_expired` refresh and Zod.
- Fix direction: read the version through the authenticated mutator, with its refresh, retry and schema. Best is to read it from the same response as the data (A-R1-3). Make the MSW handlers reject requests without `Authorization`, so the tests fail before the fix.

#### A-R1-2: the ETag isn't refreshed after a save, so the second save conflicts with itself
- Layer `admin` · Source US4 scenario 8, FR-009 · `admin/src/features/matches/MatchEditor.tsx:231,240,278-303` (`etag` is set only in the load effect; on success it calls `setInitial(state)` and never takes the response's `ETag`); `lockedFields` (`:363`) stays stale too · CONFIRMED
- Failure scenario: Save («تم الحفظ»), fix a typo, Save again. `If-Match` is still v1 against the stored v2, so the API answers `409`, and `ConflictDialog` names the editor themself as the one who changed it («عدّل ‹their own name› هذا العنصر»).
- Fix direction: take the new version and the server's state from each successful save response, and reset the form from them. Add a two-saves test.

#### A-R1-3: `If-Match` doesn't carry the version the editor saw, and `stale_ids` is never shown
- Layer `admin` · Source FR-009, the edge cases "two editors" and "a bulk change with one stale item changes nothing and names the stale rows", constitution VI · `admin/src/features/matches/BulkBar.tsx:29-39` (each item's ETag is fetched at click time; `fail()` ignores `meta.stale_ids`); `MatchEditor.tsx:244-254` (the data comes from one GET, the ETag from a second GET issued after it) · CONFIRMED for bulk, PLAUSIBLE for A4
- Failure scenario: E1 loads A3, showing match M with 0 channels. E2 adds channels to M. An admin selects M and bulk-removes channels. The freshly fetched ETag matches, so E2's channels are deleted silently, instead of the request being refused with M named. In A4, an import that lands between the two GETs is overwritten for every section the editor touches.
- Fix direction: in A4, take the `ETag` from the same response as the data. In bulk, send the version from the list the editor saw. That needs `etag` on `AdminMatchRow` from Lane B1 (already A-F3). Until then, the board must not fetch fresh versions at click time. Show the `stale_ids` rows by name on a `409`.

#### A-R1-4: «إضافة مباراة» opens an editor that can't save, with a create body of the wrong shape
- Layer `admin` · Source FR-031, FR-032, US4 scenario 2 · `admin/src/features/matches/MatchEditor.tsx:232,244-247,279,289-297`; `editor/FieldsSection.tsx:57` · CONFIRMED
- Problem: on `/matches/new` `initial` is never set, so `save()` returns at `if (initial === null)` with no toast, and `dirty` is false, so the unsaved guard never fires. The body spreads the `MatchPatch` shape (`fields: {…}`) into `MatchCreate`, which is flat, and the `as MatchCreate` cast hides the mismatch. The backend's `extra="forbid"` would answer `422`. The date input is disabled under TBD, but `match_date` is required for a TBD create.
- Fix direction: seed an initial state for the create route, build a flat `MatchCreate` with no cast, navigate to `/matches/:id` after a `201`, and keep the date editable under TBD. Add a create test that asserts the request body.

#### A-R1-5: the 409 dialog shows the editor's own edits and a made-up time
- Layer `admin` · Source US4 scenario 8 ("shows the other version"), FR-033, research R24, constitution II, the ConfirmDialog README (conflict variant) · `admin/src/features/matches/MatchEditor.tsx:201-224,307-316,385-392`; `admin/src/components/ConfirmDialog/ConflictDialog.tsx:68,100-116` · CONFIRMED
- Problem: `changes: patchChanges(state, initial)` lists the editor's unsaved edits, not the other version. `at: new Date().toISOString()` ignores `meta.changed_at`, so «حُفظت نسخة أحدث … في HH:mm» states the client's clock as fact. «أعد تطبيق تعديلاتي» is missing. «تجاهل تعديلاتي» only closes the dialog, keeping the edits and the stale ETag.
- Fix direction: on a `409`, fetch the current match, diff it against the version the editor loaded, and use `meta.changed_at`. Implement the README's three actions (view, re-apply, discard), or record dropping one with the owner. Test each.

#### A-R1-6: the team picker can't tell same-name teams apart, and shows no logo
- Layer `ui` · Source US4 scenario 4, FR-032, PB A4, `MatchEditor.png` · `admin/src/features/matches/TeamPicker.tsx:23-26,35-42,54-60` (`<datalist>` with `option value={team.name}`; `choose()` does `teams.find(t => t.name === value)`) · CONFIRMED
- Failure scenario: Saudi «الأهلي» can never be chosen when the Egyptian «الأهلي» comes first in the list.
- Fix direction: a combobox keyed by team id, showing logo, country and competition in each option. Add a test that picks the second of two same-name teams and asserts its id in the body.

#### A-R1-7: the channel picker has no satellite filter
- Layer `ui` · Source US4 scenario 7 ("results filter by satellite and by رياضة / ترفيه"), FR-032 · `admin/src/features/matches/ChannelPicker.tsx:14-45` (only `q`, `category`, `limit: 20`; `satellite_id` exists in `ListChannelsParams` but is unused) · CONFIRMED
- Fix direction: add a satellite select fed by `useListSatellites`, with «منصات بلا قمر», and a test that asserts the `satellite_id` query parameter.

#### A-R1-8: the stage and broadcaster presets are missing, and saving a slot clears its logo
- Layer `admin` · Source US4 scenarios 4 and 6, FR-008, FR-032 · `admin/src/features/matches/editor/BroadcastSlots.tsx`; `MatchEditor.tsx:98-102,184-196` (`fromMatch` and `buildPatch` drop `logo_asset_id`); `editor/FieldsSection.tsx:115-123` (stage is free text only) · CONFIRMED
- Failure scenario: slot 1 «ON Sport 1» has logo 88. The editor changes only its commentator and saves. The server replaces the slot, and the logo is gone. `GET /broadcast-presets` is never called.
- Fix direction: carry `logo_asset_id` through the state, offer the presets from `/broadcast-presets` and the stage presets from the board, and add a logo choice. Add a test that a slot edit keeps `logo_asset_id`.

#### A-R1-9: a blank score is saved as 0–0, penalty-only edits are lost, and minute and period are dropped
- Layer `admin` · Source constitution II (NON-NEGOTIABLE: never present a guess as fact), FR-011, US4 scenario 5 · `admin/src/features/matches/MatchEditor.tsx:145-160` · CONFIRMED (blank score and penalties); PLAUSIBLE (minute and period are cleared server-side)
- Problem: a blank score on `live` or `finished` becomes `Number('' || 0)`, so 0–0 is published as fact with `estimated: false`. Change detection compares only `statusMode`, `scoreHome` and `scoreAway`, so a penalty-only edit is neither dirty nor sent. `status.set` omits `period`, `minute` and `status_label`.
- Fix direction: require an explicit score before a manual `live` or `finished` can be saved. Include the penalties in change detection. Expose minute and period, or carry them through. Add payload tests for all three.

#### A-R1-10: A3 and A4 re-implement `SourceChip` and `Field` instead of reusing them
- Layer `ui` · Source constitution IV, FR-035 · `admin/src/features/matches/MatchesPage.tsx:39-49` (a local `SourceBadge`); `editor/FieldsSection.tsx` (raw `<input>` and `<select>`, a local `LockBadge`) · CONFIRMED
- Problem: `SourceChip` already has the code set, and `Field` has the label, hint, error and locked states. The `DataTable` part of this finding is A-F2 (T105), so it isn't repeated here.
- Fix direction: use `SourceChip` (which also fixes A-R1-13) and move A4's inputs onto `Field`.

#### A-R1-11: A4 isn't a React Hook Form + Zod form
- Layer `admin` · Source constitution VIII, FR-034, US4 scenario 9, T106 · `admin/src/features/matches/MatchEditor.tsx:226-321` (a hand-rolled `useState` object, validated by `patchMatchBody.safeParse`, with one generic error; `editor/TimeField.tsx` from T106 doesn't exist) · CONFIRMED
- Fix direction: this is A-F1 and T106, both open. No new task.

### MEDIUM

- **A-R1-12** `admin/src/features/matches/editor/FieldsSection.tsx:27,80`, `admin/src/i18n/ar.ts:225`: `savedAs(formatCairoTime(utc))` formats the UTC instant in Cairo time again. For a 20:00 Cairo kickoff, stored as 18:00Z, the hint reads «يُحفظ 20:00 UTC». The payload is right; the explanation states a wrong fact (constitution II). Fix: format in UTC. CONFIRMED.
- **A-R1-13** `admin/src/features/matches/MatchesPage.tsx:31-36`: `SOURCE_CODES` maps `legacy` to `LST` (LiveSoccerTV), but `legacy` is the Sat Air snapshot (`0001_base_schema.sql:89`). `kickoff` and `satair_bridge` aren't source names. `MatchesPage.test.tsx` asserts the wrong mapping. Fix: `SourceChip` with the real names (A-R1-10), and correct the test. CONFIRMED.
- **A-R1-14** `admin/src/features/matches/editor/ChannelsSection.tsx:48-61,104,174`: `void hideEverywhere()` and `void showAgain(...)` call `mutateAsync` with no `catch`. A 403, a 5xx or a network failure is an unhandled rejection, with no «فشل الحفظ» and the dialog left open. Fix: handle errors with the toast. CONFIRMED.
- **A-R1-15** `admin/src/features/matches/MatchEditor.tsx:335-337,345`: there is no `isError` branch, so a `404 match_not_found`, a 403 or an offline load shows an empty editor titled « × » with an active Save. The loading text is `copy.saving`. `Number(id)` of `/matches/abc` is `NaN`. Fix: a skeleton and an error `EmptyState` via `copyForErrorCode` (FR-033). CONFIRMED.
- **A-R1-16** `admin/src/features/matches/MatchEditor.tsx:394-408`: «احفظ وغادر» runs `save().then(() => navigate('/matches'))`. It always goes to `/matches`, not where the editor was going, and it leaves even when the save failed. The cancel button reads «إلغاء» where `Dialogs.png` has «ابقَ» (`copy.stay` exists, unused). Fix: on a successful save, `blocker.proceed()`. CONFIRMED.
- **A-R1-17** `admin/src/api/http.ts:237-243,281`: `mockPreferHeader` looks up the literal URL (`PATCH /admin/api/matches/48213`), while `mockExampleStatuses()` is keyed by templates (`{match_id}`). So `?mock=edit_conflict` and `?mock=precondition_required` never reach a parametrised operation, which breaks T107 step 2. Fix: match the template the way `schemaFor` does. CONFIRMED.
- **A-R1-18** `admin/src/features/matches/MatchEditor.tsx:345,387`, `admin/src/i18n/ar.ts:250` (``hideTitle: (name) => `إخفاء «${name}» دائماً؟` ``), `MatchesPage.tsx:402`, `ChannelsSection.tsx:98,116,136`: Latin team and channel names are concatenated into Arabic strings without LTR isolation (constitution III, root `CLAUDE.md` client rules). Fix: render the names as `<bdi dir="ltr">` nodes, or build the strings from isolated parts. CONFIRMED.
- **A-R1-19** `admin/src/api/http.ts:200-211`, `admin/src/features/auth/session.ts:77-79`, `admin/src/app/App.tsx:12-23`: any refresh failure, a network blip included, calls `onExpired`. The redirect to A1 then unmounts A4 without the unsaved prompt, and a `401 refresh_invalid` is reported as `network_error`. Fix: end the session only on a definitive `401`/`403` from refresh, and retry network errors. CONFIRMED.
- **A-R1-20** `admin/src/components/Button/Button.tsx:22-26`: `sm` is `h-8 min-h-12` and `xs` is `h-6 min-h-12`, so all three sizes render 48 px. The README gives default 48, `sm` 40 and `xs` 32, all with a 48 px target, plus a pressed state that isn't built (FR-035). Fix: the README's heights with a 48 px hit area, the pressed state, and a test. CONFIRMED.
- **A-R1-21** `admin/src/features/matches/MatchesPage.tsx:177,195-197,260-262`, `admin/src/components/ConfirmDialog/ConfirmDialog.tsx:55-57`: conditional classes are built with template-literal ternaries. The shared components use `clsx` and `cva`. CONFIRMED.
- **A-R1-22** tests behind ticked tasks (T094, T097, T098, T099):
  - Bulk removal is never submitted (`MatchesPage.test.tsx:196-210`).
  - Nothing tests «مخفية دائماً» with «إظهار», a second save, a create, the 409 dialog's current version, A4's «فشل الحفظ», `beforeunload` or `stale_ids`.
  - The editor's DST test (`MatchEditor.test.tsx:208-222`) covers one side, though its title says each side.
  - `cairoTime.test.ts:15-16` says CI runs under `TZ=UTC` and `TZ=Asia/Riyadh`; neither `admin.yml` nor `package.json` does.
  - No handler asserts `Authorization` (A-R1-1).

  CONFIRMED.
- **A-R1-23** `docs/runbooks/` has no runbook for how editors reach the admin on D2 (`NODE_EXTRA_CA_CERTS=… pnpm dev:wg`). The command lives only in `admin/CLAUDE.md`, `owner-actions.md`, the spec and quickstart. `admin/CLAUDE.md:41` says Playwright arrives on D11, while the spec and delivery-plan §5 say D4. CONFIRMED.
- **A-R1-24** `admin/src/features/matches/MatchesPage.tsx:348-350`: an unknown kickoff shows «—» instead of «لم يُحدد» (root `CLAUDE.md`: "an unknown kickoff shows «لم يُحدد»"). CONFIRMED. `:89-104` keys groups by `String(row.competition.id)`, so free-text competitions with a null id merge under the first one's name. PLAUSIBLE.
- **A-R1-25** `admin/src/features/matches/MatchEditor.tsx:244-254`: the effect on `[match.data, matchId]` resets the form whenever React Query refetches changed data (on reconnect or focus), wiping unsaved edits without a prompt. PLAUSIBLE.
- **A-R1-26** `admin/src/features/matches/MatchEditor.tsx:242`: `useListCommentators({ limit: 100 })` ignores `next_cursor`, so commentators past 100 can't be chosen, and a set one outside the page shows «بدون معلق». PLAUSIBLE (I didn't count the rows).
- **A-R1-27** `admin/vite.config.ts:47-49`: `changeOrigin: false` forwards `Host: localhost:5173`, while Caddy's site is `https://10.8.0.1` (`infra/Caddyfile:71`), so `dev:wg` may match no route. Settle it in the T107 walk. PLAUSIBLE.

### LOW

- A-R1-28 `MatchesPage.tsx:53`: logos use raw `width={24} height={24}` with no `onError` fallback. The admin CSP `default-src 'self'` (`infra/Caddyfile:79`) will block cross-origin media logos once Caddy serves the admin (D4). PLAUSIBLE.
- A-R1-29 copy drift from PB §14:
  - `halftime` reads «بين الشوطين» where the glossary has «استراحة».
  - The postponed, cancelled and abandoned labels are «مؤجلة/ملغاة/متوقفة», not «تأجلت/أُلغيت/توقفت».
  - The source-conflict prefix «حدّث» should be «عدّل» per the spec's edge case.
  - `unsavedBody` hard-codes "channels and stage".

  CONFIRMED.
- A-R1-30 dead copy and exports:
  - copy keys `matches.showing`, `matches.keyboard`, `matches.teamFilter`, `editor.preview`, `editor.detailsTab`, `editor.historyTab`, `editor.lockedFields`, `editor.noEvents`;
  - `Modal`'s `labelId` and `useDialogHeadingId`;
  - the icons `chevronDown` and `calendar`.

  CONFIRMED.
- A-R1-31 `MatchEditor.tsx:305`: `error as ApiError` is unguarded. The `<select>` value casts at `ChannelPicker.tsx:38`, `MatchesPage.tsx:245` and `StatusSection.tsx:51` are unchecked narrowings. CONFIRMED.
- A-R1-32: the native `<select>`, `<input>` and checkbox controls in A3 and A4 rely on the UA focus ring, not the `focus-ring` token. CONFIRMED.
- A-R1-33 `cairoTime.test.ts:87-92`: the title says "24-hour Cairo day" while the assertion is for 25 hours. `http.test.ts:56` is named "bis: …". Wall times in the DST gap and overlap are neither handled nor tested. CONFIRMED.
- A-R1-34: `ChannelPicker` has no debounce and no paging. Logout and expiry don't clear the React Query cache (`session.ts:66-69`), though `admin/CLAUDE.md` says everything is cleared. The bulk confirm stays enabled while the ETag fan-out runs. Code and tests landed in one commit (`638d4f0`), so test-first (FR-053) can't be shown. CONFIRMED.
- A-R1-35 `admin/src/components/ConfirmDialog/Modal.tsx:24-60`: `onClose` is in the focus effect's deps, and callers pass inline arrows (`BulkBar.tsx:95,124`, `ChannelsSection.tsx:175`, `MatchEditor.tsx:391,403`). So each parent render refocuses the panel, and in `BulkBar` keyboard focus leaves the competition select after every change. CONFIRMED by reading.
- A-R1-36 `pnpm lint`: the `react-hooks/exhaustive-deps` warning at `MatchesPage.tsx:144` and 25 `enforces-shorthand` warnings are new. CONFIRMED.

## Requirements

| Requirement | Status | Where | Test |
| --- | --- | --- | --- |
| FR-030 / US4-1 login, in-memory token, silent refresh, CSRF | Built; a transient failure signs out | `http.ts`, `session.ts`, `App.tsx` | `http.test.ts`, `App.test.tsx`; A-R1-19 |
| FR-031 / US4-2 A3 tabs, filters, groups, rows, «إضافة مباراة» | Built; create broken | `MatchesPage.tsx` | `MatchesPage.test.tsx`; A-R1-4, A-R1-24 |
| US4-3 bulk competition change, admin-only typed removal | **Fails** against the real API | `BulkBar.tsx` | removal never submitted; A-R1-1, A-R1-3 |
| US4-4 team picker, Cairo time, TBD, presets, stadium | **Partial** | `TeamPicker.tsx`, `FieldsSection.tsx` | A-R1-6, A-R1-8, A-R1-12 |
| US4-5 manual status, score, penalties, clear | **Partial** | `StatusSection.tsx`, `MatchEditor.tsx:145-160` | UI enabling only; A-R1-9 |
| US4-6 broadcaster slots | **Partial** | `BroadcastSlots.tsx` | A-R1-8 |
| US4-7 channel picker and channel actions | **Partial** | `ChannelPicker.tsx`, `ChannelsSection.tsx` | A-R1-7, A-R1-14 |
| US4-8 unsaved guard, 409 dialog, toasts | **Partial** | `MatchEditor.tsx`, `ConflictDialog.tsx` | A-R1-2, A-R1-5, A-R1-16 |
| FR-032 A4 parts | **Partial** | `MatchEditor.tsx`, `editor/*` | as above |
| FR-033 common states | **Partial**: A3 yes, A4 no error state | | A-R1-15 |
| FR-034 / US4-9 Orval, Zod, React Query, RHF, `error.code` copy | **Partial**: no RHF | `http.ts`, `i18n/ar.ts` | `http.test.ts`; A-R1-11 (A-F1) |
| FR-035 shared components, new ones once | **Partial** | `Button`, `ConfirmDialog`, `ConflictDialog` | A-R1-10, A-R1-20, A-F2 |
| FR-051 own folders only | Met | | |
| FR-053 tests first | Not shown | | A-R1-34 |

## Task audit

- **Ticked but not done:**
  - T105: not built on `DataTable`; the tick says so (A-F2).
  - T099: the gaps in A-R1-22.
  - T098: bulk removal never submitted.
  - T097, T101: the conflict variant (A-R1-5).
  - T094: the two zones aren't in CI.
  - T096, T100: Button sizes and pressed state (A-R1-20).
  - T090: `changeOrigin` unverified (A-R1-27).
- **Verified done:** T091, T092, T093 (generated files untouched, 41 of 41 schemas, MSW wired), T102, T104, T108.
- **Open, correctly:** T106 (A-F1; also A-R1-4) and T107 (step 1 passes here; steps 2–4 are the owner's, and A-R1-17 and A-R1-27 would break steps 2 and 3).
- **Follow-ups A-F1 to A-F5:** all still needed, and none is repeated in the fix block. A-F3 is Lane B1's contract change that A-R1-3 depends on.

## Owner must review

- The screenshots next to `Matches.png`, `MatchEditor.png` and `Dialogs.png` at 1440 and 1024 (delivery-plan §8.1 item 12; T107 step 4, A-F5). None are in the repo.
- A-R1-5: whether the conflict dialog keeps all three README actions.

## Outside this change

- `LoginPage.tsx:179` (D1) also builds classes by string concatenation.

## Not reviewed

- The generated Orval files, beyond checking them against the generator.
- Behaviour against Prism or the real API in a browser (T107 steps 2–3).
