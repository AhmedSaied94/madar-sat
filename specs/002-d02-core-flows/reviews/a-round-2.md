# Implementation review: 002-d02-core-flows, lane A, round 2

- Date: 2026-10-31 · Reviewer: Claude Code, Opus 5.5 (`claude-opus-5-5`); a layer subagent on Sonnet, every finding re-checked here
- Branch: `d02-features` · Base: `master` (merge base `68f1752`) · Head: `6f81c90` when reviewed, plus 106 uncommitted files (the round-1 fixes of B1, B2 and A). `3ac2bf5` has since committed Lane A's fixes (with Lane M's), and its `admin/` is identical to what was reviewed.
- Change (lane A, this round): 1 commit (`3ac2bf5`), 26 files under `admin/` (+1610 −433, including the Orval output B1 regenerated for `AdminMatchRow.etag`), and `docs/runbooks/admin-access.md` with its README rows. Nothing in another lane's folder.
- Verdict: **CHANGES REQUESTED** · CRITICAL 0 · HIGH 5 · MEDIUM 8 (1 PLAUSIBLE) · LOW 3

The round-1 plumbing is good. `getEntityEtag` is gone, A4 and the bulk bar read versions from the data the editor saw, and the bearer, the refresh retry and the Zod checks all go through the mutator. Five ticked fixes are not done, or are done wrongly:

- The ETag is lost whenever React Query refetches changed data.
- A broadcast preset's own id is sent as a media asset id.
- The Button fix shrank the hit area instead of keeping 48 px.
- `?mock=` still never matches an operation with a path parameter.
- The stage presets are missing.

## Checks

Admin checks ran in a snapshot of this working tree (`git ls-files -co --exclude-standard`).

| Check | Command | Result |
| --- | --- | --- |
| install | `pnpm install --frozen-lockfile` | exit 0 |
| typecheck | `pnpm typecheck` | exit 0 |
| lint | `pnpm lint` | exit 0, 25 warnings (24 `tailwindcss/enforces-shorthand`, 1 `react-hooks/exhaustive-deps` at `MatchesPage.tsx:149`; A-R2-16) |
| test | `pnpm test` | exit 0: 16 files, 165 tests |
| build | `pnpm build` | exit 0 |
| literals | `./scripts/check-literals.sh` | exit 0 |
| token copy | `./scripts/check-token-copy.sh` | exit 0 |
| client current | `pnpm orval && git status --porcelain -- src/api/generated` | exit 0, no diff (the generated diff is Orval's, for `AdminMatchRow.etag`) |
| structural sharing | read `node_modules/.pnpm/@tanstack+query-core@5.105.0/…/build/modern/utils.js:148-176` (`replaceEqualDeep`) | a changed object is rebuilt from `Object.keys`, so a symbol-keyed property is dropped (A-R2-1) |
| secrets | gitleaks v8.30.1 over the snapshot | exit 0 |
| T107 (Prism, `dev:wg`, the screenshots) | | **NOT RUN**: steps 2 to 4 are the owner's, against a running Caddy and WireGuard |

Ways around the checks: no `.skip(`, `.only(`, `eslint-disable`, `@ts-expect-error` or `any` in hand-written code. The Button tests assert the class names that cause A-R2-3.

## Previous round

| Finding | Now |
| --- | --- |
| A-R1-1 bearer-less version reads | **Fixed**; the GET and bulk handlers don't check `Authorization` (A-R2-14) |
| A-R1-2 second save reused the load ETag | **Fixed** (`MatchEditor.tsx:469-476`; test asserts `"v2"`); breaks after a refetch (A-R2-1) |
| A-R1-3 versions from a second GET | **Partly fixed**: A4 and bulk use the data's version, which a changed refetch drops (A-R2-1); a stale `409` is shown by id only and nothing refreshes (A-R2-9) |
| A-R1-4 create | **Fixed** |
| A-R1-5 409 dialog | **Partly fixed**: the time comes from `meta.changed_at` and «تجاهل» really discards; Escape discards too (A-R2-6) and the diff is thin (A-R2-7). «أعد تطبيق تعديلاتي» was dropped and recorded with the owner, which is accepted |
| A-R1-6 same-name teams | **Fixed** by id; the 5-row cap undoes it for a sixth team (A-R2-8) |
| A-R1-7, A-R1-9, A-R1-12 to A-R1-16, A-R1-19, A-R1-21, A-R1-25 | **Fixed**, each with a test that fails on revert |
| A-R1-8 logos and presets | **Partly fixed**: logos survive a slot edit; the preset sends the wrong id (A-R2-2), an overtyped label keeps the old logo (A-R2-12), and there are no stage presets (A-R2-5) |
| A-R1-10 shared components | **Partly fixed**: `SourceChip` and `Field` are used; competition, status, score and the pickers are still raw controls; `DataTable` is A-F2 |
| A-R1-11 RHF + Zod (A-F1) | Still open, correctly unticked (T106) |
| A-R1-17 `?mock=` | **Still open** though ticked (A-R2-4) |
| A-R1-18 `<bdi>` | **Fixed**; the tests check accessible names only (A-R2-14) |
| A-R1-20 Button sizes | **Regressed** (A-R2-3) |
| A-R1-22 test gaps | **Fixed**, with the gaps in A-R2-14 |
| A-R1-23 runbook | **Partly fixed**: the runbook exists and is indexed; its commands are wrong (A-R2-13) |
| A-R1-24 «لم يُحدد» | **Fixed**; `groupByCompetition` still keys by `String(row.competition.id)`, so null-id competitions merge (PLAUSIBLE) |
| A-R1-26 to A-R1-29, A-R1-32, A-R1-33, A-R1-35, A-R1-36 | Still open (A-R1-35 is A-R2-11; A-R1-27 is in A-R2-13; A-R1-36 is A-R2-16) |
| A-R1-30, A-R1-31, A-R1-34 | **Partly fixed** (unused copy keys remain; `<select>` casts remain; the cache isn't cleared on logout, A-R2-10) |
| A-F2 (T105) | **Ticked but not done**: A3 still uses a local `<table>` (`MatchesPage.tsx:313-428`), and T105's tick says so |

## Findings

### HIGH

#### A-R2-1: the ETag rides on a symbol property that React Query drops on a changed refetch, so a save after «إعادة التحميل», or after reopening a match, sends no `If-Match`
- Layer `admin` · Source FR-009, US4 scenario 8, research R24 · `admin/src/api/http.ts:57-71` (`withEtag` with `Object.defineProperty(body, RESPONSE_ETAG, …)`), `:330-332`; `admin/src/features/matches/MatchEditor.tsx:351-359,426,470` · CONFIRMED (library source above; not run)
- Problem: `replaceEqualDeep` keeps the old object when the data is equal, and otherwise builds a new `{}` from `Object.keys(b)`, which has no symbol. Only the first fetch of a match keeps its ETag.
- Failure scenario: a 409 arrives, and `openConflict` calls `match.refetch()`. The server's data differs, so `etagOf(refreshed.data)` is `null` (`:426`). «إعادة التحميل» adopts a baseline with no version. The next save sends no `If-Match` (`:470`) and gets `428`. The same happens after a save: `invalidateQueries()` refetches the changed match, and reopening it from A3 within the 5-minute `gcTime` seeds A4 with `etag: null`, so every save is a 428 until a hard reload.
- Fix direction: carry the version as an ordinary field that survives cloning. Options: return it alongside the data from the query function, turn structural sharing off for this query, or keep a store keyed by match id. Add tests that refetch changed data, then save: once after «إعادة التحميل» and once after a remount. Today's tests only refetch identical data.

#### A-R2-2: the editor sends a broadcast preset's own `id` as `logo_asset_id`
- Layer `admin` · Source US4 scenario 6, FR-008, constitution II · `admin/src/features/matches/editor/BroadcastSlots.tsx:38-41` (`logoAssetId: preset.id`); `admin/src/api/generated/admin.schemas.ts:374-378` (`BroadcastPreset {id, logo, name}`); `backend/app/services/admin/lists.py:267-270` · CONFIRMED
- Problem: `BroadcastPreset.id` is the preset table's key. `logo_asset_id` references `media_assets.id`.
- Failure scenario: the editor picks the «beIN SPORTS» preset (id 3) and saves. The server either refuses asset 3 as not found, or publishes media asset 3, an unrelated image, as that broadcaster's logo. The test fixture gives the preset `id: 32` and the slot `logo_asset_id: 31`, so it can't see the mix-up.
- Fix direction: stop sending a preset id as an asset id. B1 adds `logo_asset_id` to `BroadcastPreset` (`b1-round-2.md` B1-R2-8); until it lands, a preset sets the label and leaves the logo empty. Fix the fixture so the preset's asset id differs from its id.

#### A-R2-3: Button `sm` and `xs` now paint a 16 px and an 8 px fill inside a 32 px and a 24 px target
- Layer `ui` · Source constitution IV (48 dp targets), the Button README ("default 48px, `sm` 40px, `xs` 32px; all keep a 48px target"), A-R1-20 · `admin/src/components/Button/Button.tsx:26-27` (`h-8 border-y-8 border-transparent bg-clip-padding`, `h-6 border-y-8 …`); `admin/src/components/Button/Button.test.tsx:27-43`; the closing note at `specs/002-d02-core-flows/tasks.md:654` · CONFIRMED (CSS box model: preflight sets `border-box`, `h-8` is 32 px from the tokens, `border-y-8` is Tailwind's default 8 px)
- Problem: the borders sit inside the height, so `sm` is a 32 px element with 16 px of transparent band and a 16 px fill (the 13 px label at 1.4 line height overflows it), and `xs` is a 24 px element with an 8 px fill. The band is part of the button, so the targets are 32 and 24 px. The closing note's "keeps a 48 px target" is false. Before this round `min-h-12` gave a real 48 px.
- Failure scenario: A4's Save, the bulk bar, both dialogs and the channel «إضافة» and «إزالة» buttons use `sm` or `xs`. They look broken, and none meets 48 px.
- Fix direction: keep the element 48 px tall and clip the fill. `h-12 border-y-4 border-transparent bg-clip-padding` gives a 40 px fill and `h-12 border-y-8 …` gives 32 px, both with a 48 px target and no new token. A hit-area pseudo-element also works. Assert `h-12` in the test, and correct the closing note and the owner action that asks for `space-10`.

#### A-R2-4: `?mock=` still never matches an operation with a path parameter (A-R1-17 ticked, not fixed)
- Layer `admin` · Source T107, A-R1-17 · `admin/src/api/http.ts:269-284` (`operationTemplate` returns `PATCH /admin/api/matches/{}`); `admin/vite.config.ts:22-35` (`__MOCK_EXAMPLE_STATUSES__` keyed by the spec path, `PATCH /admin/api/matches/{match_id}`) · CONFIRMED
- Problem: the two maps use different keys, so the status lookup at `http.ts:273` is `undefined` for every templated path, and no `Prefer` header is sent. The new test checks `operationTemplate` alone and never the lookup.
- Failure scenario: `/matches/48213?mock=edit_conflict` sends no `Prefer`, so T107 step 2 can't show the 409 dialog from Prism.
- Fix direction: key both maps the same way (normalise `{name}` to `{}` in `vite.config.ts`), and test the lookup with `__MOCK_EXAMPLE_STATUSES__` stubbed.

#### A-R2-5: the stage presets are still missing (A-R1-8 ticked "tests for both preset lists")
- Layer `admin` · Source US4 scenario 4 (`spec.md:139`: «الجولة الأولى، ذهاب/إياب دور 16، ربع النهائي، نصف النهائي، النهائي» or free text), A-R1-8 · `admin/src/features/matches/editor/FieldsSection.tsx:116-121` (a bare `Field`); the only `datalist` in `admin/src` is the broadcaster one (`BroadcastSlots.tsx:51`) · CONFIRMED
- Problem: the stage is free text only.
- Failure scenario: two editors type «ربع نهائي» and «ربع النهائي» for the same round, and the public app shows both spellings.
- Fix direction: offer the five presets (a datalist or combobox that still takes free text), with the copy in `i18n/ar.ts`, and a test that picks one and checks `competition_stage` in the body.

### MEDIUM

#### A-R2-6: Escape on the conflict dialog throws away the editor's edits
- Layer `admin` · Source the ConfirmDialog README (destructive moments are not clicked through), US4 scenario 8 · `admin/src/components/ConfirmDialog/ConflictDialog.tsx:54` (`<Modal onClose={onDiscard}>`); `admin/src/features/matches/MatchEditor.tsx:605-609` · CONFIRMED
- Problem: `Modal` calls `onClose` on Escape, and `onDiscard` resets the form to the baseline.
- Failure scenario: an editor presses Escape to read the page behind the dialog, and loses every unsaved change with no confirmation.
- Fix direction: make Escape a dismiss that keeps the edits (or ignore it), and keep the discard on its button. Test that Escape leaves the state unchanged.

#### A-R2-7: the conflict diff covers six fields, shows raw ids and codes, and invents a time
- Layer `admin` · Source US4 scenario 8, constitution II · `admin/src/features/matches/MatchEditor.tsx:275-307` (`diffStates`), `:416-423` · CONFIRMED
- Problem: only kickoff, competition id, stage, stadium, status mode and the channel count are compared. Teams, scores, penalties, minute, period, broadcasts and commentators are not, so a change to those gives an empty «اعرض التغييرات». The competition shows as `"12"` and the status as `live`. `meta.changed_at ?? new Date().toISOString()` shows the client's clock as the other editor's save time.
- Failure scenario: another editor changes the score. The dialog says the match changed but lists nothing, with "now" as the time.
- Fix direction: diff every `EditorState` field with display names, hide the toggle when there is nothing to show, and say the time is unknown instead of using now. Test a score-only conflict.

#### A-R2-8: the team picker shows 5 results, but the keyboard can move to a hidden sixth
- Layer `ui` · Source A-R1-6, the combobox pattern · `admin/src/features/matches/TeamPicker.tsx:103` (`teams.slice(0, 5)`), `:52-58` (`ArrowDown` bounded by `teams.length - 1`), `:63-67` (Enter picks `teams[active]`) · CONFIRMED
- Problem: `active` can point at an option that isn't rendered, `aria-activedescendant` names a missing id, and the active option has no visible style.
- Failure scenario: an editor presses ↓ six times and Enter, and a team they never saw is picked.
- Fix direction: render every result in a scrolling list, or bound `active` to what is shown; add an active style; reset `active` on a new query. Test ↓ past the fifth row.

#### A-R2-9: a stale bulk `409` names rows by id and leaves the stale list in place
- Layer `admin` · Source the spec edge case "a bulk change with one stale item changes nothing and names the stale rows" · `admin/src/features/matches/BulkBar.tsx:38-49`; `admin/src/features/matches/queries.ts:22-30` (only `onSuccess` invalidates) · CONFIRMED
- Problem: the message reads «…: 48213» though the selected rows, with team names, are at hand, and after a 409 nothing refetches the list.
- Failure scenario: the editor retries and gets the same 409 with the same versions until they change the day tab or reload.
- Fix direction: name the rows («home × away» in `<bdi>`), and invalidate the list on a stale 409. Test both.

#### A-R2-10: logout and session expiry leave the React Query cache in place
- Layer `admin` · Source the admin review checklist (the session and its cache are cleared on logout), FR-030, A-R1-34 · `admin/src/features/auth/session.ts:44-47,66-69`; no `queryClient.clear()` anywhere in `admin/src` · CONFIRMED
- Problem: `signOut` and `onExpired` drop only the session and the token.
- Failure scenario: a second editor signs in on the same tab without a reload and sees the first editor's cached matches and lists, with their versions, including anything only the first editor's role could read.
- Fix direction: `queryClient.clear()` on sign-out and on a final expiry (`SessionProvider` sits inside `QueryClientProvider`). Test that a query's data is gone after sign-out.

#### A-R2-11: `Modal` re-runs its focus effect on every parent render
- Layer `ui` · Source A-R1-35, the dialog focus rules · `admin/src/components/ConfirmDialog/Modal.tsx:24-61` (deps `[open, onClose]`, cleanup refocuses the trigger); `admin/src/features/matches/BulkBar.tsx` (a new arrow each render) · PLAUSIBLE (read, not run in a browser)
- Problem: each re-render runs the cleanup (focus to the trigger) and then the effect (focus to the panel).
- Failure scenario: in the bulk competition dialog, changing the select re-renders the bar, and keyboard focus leaves the select on each change.
- Fix direction: keep `onClose` in a ref and depend on `open` only. Test that focus stays on a control after a parent re-render.

#### A-R2-12: an overtyped broadcaster label keeps the previous broadcaster's logo
- Layer `admin` · Source constitution II, US4 scenario 6 · `admin/src/features/matches/editor/BroadcastSlots.tsx:42-44`; `admin/src/features/matches/MatchEditor.test.tsx:511-522` (the test expects this) · CONFIRMED
- Problem: any label that isn't a preset keeps `at(slot).logoAssetId`.
- Failure scenario: on a «Sky Sport Italy» slot with logo 31, the editor selects all and types «Foo TV». Foo TV is published with Sky's logo.
- Fix direction: keep the logo only while the label is unchanged or is the preset's; otherwise clear it, and show the slot's logo so the editor can see what is kept. Update the test.

#### A-R2-13: `docs/runbooks/admin-access.md` has commands that don't match the code
- Layer `ops` · Source the root `CLAUDE.md` runbook rule, A-R1-23, A-R1-27 · `docs/runbooks/admin-access.md:24`, its `?mock=` table and its login step; `admin/vite.config.ts:49` (`changeOrigin: false`); `infra/Caddyfile:71` · CONFIRMED, except the `dev:wg` host header (PLAUSIBLE)
- Problems:
  - `scp ubuntu@10.8.0.1:/tmp/caddy-root.crt …` copies a file nothing creates. `private-network.md:177` has the working command.
  - The `?mock=` table uses `/matches?mock=edit_conflict`, but the PATCH happens on `/matches/<id>` (and A-R2-4 breaks it anyway).
  - "You land on A3" is wrong: with no `from`, login returns to `/`.
  - `changeOrigin: false` forwards `Host: localhost:5173` to a Caddy whose only site is `https://10.8.0.1`, so `dev:wg` may match no route. PLAUSIBLE until the T107 walk.
- Failure scenario: the owner follows the runbook for T107 and fails at the first command.
- Fix direction: use `private-network.md`'s command, correct the URLs and the landing page, and settle the host header in the T107 walk. No test (docs).

### LOW

- A-R2-14 test gaps: no handler checks `Authorization` on the match GET (`MatchEditor.test.tsx:173`) or on bulk, so a bearer-less read (A-R1-1) would pass again. The A-R1-18 tests check accessible names, which are the same without `<bdi>`. A refused «إظهار» is untested. CONFIRMED.
- A-R2-15 robustness:
  - «احفظ وغادر» isn't disabled while saving (`MatchEditor.tsx:612-619`), so a double click sends two PATCHes under one `If-Match`.
  - `showAgain` updates from a stale `channels` closure after an `await` (`ChannelsSection.tsx:70-77`).
  - `match.isError` replaces the whole editor, even with unsaved state, when a background refetch fails (`MatchEditor.tsx:521`).

  CONFIRMED.
- A-R2-16 polish:
  - `MatchesPage.tsx:149-150` still trips `exhaustive-deps`.
  - The `h-12 w-12` pairs in `StatusSection.tsx:83,97,128,142,156` trip `enforces-shorthand`, and those inputs are 24 px wide inside their padding, so «90+3» clips.
  - A3's filters are `h-8` native controls with no focus-ring token (A-R1-32).
  - The Button's pressed state for `secondary`, `outline` and `ghost` is the same class as hover.

  CONFIRMED.

## Requirements

Only the rows that changed since round 1. Every other row of `a-round-1.md` stands.

| Requirement | Built in | Proven by | Status |
| --- | --- | --- | --- |
| FR-009, R24 the version from the response | `api/http.ts:57-71`, `MatchEditor.tsx:351-359,426` | `MatchEditor.test.tsx:382-400` (identical refetches only) | **Partial**: lost on a changed refetch (A-R2-1) |
| US4-4 presets, Cairo time, TBD, stadium | `FieldsSection.tsx`, `TeamPicker.tsx` | `MatchEditor.test.tsx:309-341,371-380` | **Partial**: no stage presets (A-R2-5), the 5-row cap (A-R2-8) |
| US4-6 broadcaster slots | `BroadcastSlots.tsx` | `MatchEditor.test.tsx:494-554` | **Partial**: wrong preset id (A-R2-2), stale logo (A-R2-12) |
| US4-8 unsaved guard, 409 dialog | `MatchEditor.tsx`, `ConflictDialog.tsx` | `MatchEditor.test.tsx:645-806` | **Partial** (A-R2-1, A-R2-6, A-R2-7) |
| FR-031 bulk, and the edge case "names the stale rows" | `BulkBar.tsx` | `MatchesPage.test.tsx` | **Partial** (A-R2-9) |
| FR-030 session against the real admin API | `features/auth/session.ts`, `api/http.ts` | `http.test.ts` | **Partial**: cache kept on logout (A-R2-10) |
| FR-035, constitution IV shared components and targets | `components/Button`, `ConfirmDialog` | `Button.test.tsx` (class names) | **Not met** for Button sizes (A-R2-3); `DataTable` is A-F2 |
| T107 Prism walk | `api/http.ts:262-284`, `vite.config.ts` | `http.test.ts` (template only) | **Not met** (A-R2-4, A-R2-13) |

## Task audit

Round-1 fix tasks: all ticked; 14 verified, 6 partly done (A-R1-3, 5, 8, 10, 22, 23), 2 not done (A-R1-17, A-R1-20, the latter regressed). Of the follow-ups, A-F3 is done (by B1); A-F1, A-F2, A-F4 and A-F5 are open. T105 is ticked but not done (A-F2).

| Task | Mismatch |
| --- | --- |
| A-R1-3, A-R1-5 | the version is lost after a changed refetch (A-R2-1); Escape discards (A-R2-6); the diff is thin (A-R2-7) |
| A-R1-8 | wrong preset id (A-R2-2), no stage presets (A-R2-5), stale logo (A-R2-12) |
| A-R1-17 | not fixed (A-R2-4) |
| A-R1-20 | regressed (A-R2-3); the closing note's 48/40 px claim is false |
| A-R1-23 | the runbook's commands (A-R2-13) |
| T105 | ticked, though A3 still uses a local table |

## Owner must review

- A3 and A4 next to `Matches.png`, `MatchEditor.png` and `Dialogs.png` at 1440 and 1024 (delivery-plan §8.1 item 12; T107 step 4, A-F5). No screenshots are in the repo, and the Button sizes (A-R2-3) will show there.
- `admin/src/api/http.ts` and `admin/src/features/auth/session.ts`: the token in memory, the refresh retry, the `ETag` on the envelope (A-R2-1) and logout (A-R2-10).
- The owner actions Lane A recorded: «أعد تطبيق تعديلاتي» dropped (accepted here), and the `space-10` request, which A-R2-3's fix makes unnecessary.

## Outside this change

- `BroadcastPreset` has no `logo_asset_id` in B1's contract: asked in `b1-round-2.md` B1-R2-8.
- The `TZ=UTC` and `TZ=Asia/Riyadh` CI runs: the claim was replaced by a `stubEnv('TZ')` test, so nothing is asked of B2.

## Not reviewed

- The T107 walk (Prism, `dev:wg` through WireGuard, the screenshots): the owner's.
- Real browser layout and focus: A-R2-3 and A-R2-11 were judged from the CSS box model and the effect code, not rendered.
- The generated Orval files: checked against the generator, not read.
