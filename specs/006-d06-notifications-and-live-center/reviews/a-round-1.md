# Implementation review: 006-d06-notifications-and-live-center, lane A, round 1

- Date: 2026-11-09 · Reviewer: Claude Code (Opus 5.5, `claude-opus-5-5`), with two Sonnet layer reviewers; every HIGH re-checked on Opus
- Branch: `d06-a` · Base: `e20a5dc` (B2's merge #47, which this branch was rebased on; the lane's own commits are `bef8ea3`..`af31032`) · Head: `af31032`, plus 0 uncommitted files
- Change: 6 commits, 43 files (0 in another lane's folders), +4 534 −85
- Verdict: **CHANGES REQUESTED** · CRITICAL 0 · HIGH 8 · MEDIUM 13 · LOW 6

The lane is already merged into the spec branch (PR #48, 2026-11-08).

## Checks

| Check | Command | Result |
| --- | --- | --- |
| typecheck | `pnpm typecheck` (clean copy of `d06-a`) | exit 0 |
| lint | `pnpm lint` | exit 0 (6 warnings, 0 errors) |
| unit tests | `pnpm test` | first run exit 1 under heavy load (3 Composer tests timed out at 5 s); `Composer.test.tsx` alone passed twice; full re-run exit 0, 367/367 in 37 files |
| build | `pnpm build` | exit 0 |
| literals | `./scripts/check-literals.sh` | exit 0 |
| token copy | `./scripts/check-token-copy.sh` | exit 0 |
| generated client current | `pnpm orval` then `diff -r` against the committed `src/api/generated` | exit 0, no diff |
| Playwright smoke | `pnpm e2e` | NOT RUN (needs Prism and a browser); `e2e/smoke.spec.ts` is unchanged |
| CI on PR #48 | `gh pr checks 48` | admin `check` and gitleaks pass |

## Findings

### CRITICAL

None.

### HIGH

#### A-R1-1: A16's edit, deactivate, reactivate and reset, and A15's cancel, send the list's `ETag` as `If-Match`
- Layer admin · Source US3 scenarios 4, 8, 10, FR-042, FR-043, constitution VI · `admin/src/features/users/UsersPage.tsx:59, 71, 92`; `admin/src/features/notifications/NotificationsPage.tsx:102, 118` · CONFIRMED
- Problem: the server compares `If-Match` with the row's own version; these screens send the dataset `ETag` of the list response (`W/"…"`, 15–30 s bucket). The tests pin the wrong value (`UsersPage.test.tsx:200, 216` `'"users-1"'`, `NotificationsPage.test.tsx:310-331` `'"outbox-1"'`) and MSW never compares it. The lists also keep React Query's default structural sharing, which can drop the symbol-held `ETag` after a refetch (PLAUSIBLE `428`).
- Failure scenario: on the real API every role change, deactivation, reset and cancel answers `409 edit_conflict`, and `ConflictDialog` opens with an empty diff.
- Fix direction: depends on B1-R1-2 (per-row `etag` on `AdminUserRow` and `NotificationRow`). Then regenerate, send each row's own version, and rewrite the tests to assert it.

#### A-R1-2: A16's edit drawer keeps the previous account's state, so a save can write one account's name and role onto another
- Layer admin · Source FR-043, contracts/admin-screens.md A16 ("cleared on close") · `admin/src/features/users/UsersPage.tsx:278-294` (no `key`), `:368-373` (`useState` from props), `:390` · CONFIRMED
- Failure scenario: open edit for A (admin), then ⋮ → تعديل on B (editor): the same instance stays, the form still shows A's name and role, and saving sends them as B's, a silent promotion. After a reset of A, opening B shows A's temporary password.
- Fix direction: key the drawer by account (and reset its state on open), or build it on `EditorDrawer` like the other editors. Add a test that opens two accounts in turn.

#### A-R1-3: A17's entity filter and links use names the server never writes, and «فتح القناة» goes to a route that doesn't exist
- Layer admin · Source US3 scenario 9, FR-045 · `admin/src/features/audit/AuditPage.tsx:24-34, 247-256`; `admin/src/i18n/ar.ts:896-905` · CONFIRMED
- Problem: the filter sends `channel`, `match`, `team`, `competition`, `satellite`, `commentator`, `admin_user`; B1 stores `channels`, `matches`, `teams`, `competitions`, `satellites`, `commentators`, `admin_users` (each service's `ENTITY`) and filters with `=`. Links check `entity === 'channel'`/`'match'`. `/channels/:id` has no route in `App.tsx`.
- Failure scenario: النوع = قناة returns nothing; a real channel entry shows no link and the raw word "channels"; the channel link, if shown, lands on ComingSoon.
- Fix direction: key on the names B1 writes (settle them in the contract), and make the channel link open the channel's editor.

#### A-R1-4: A17's period filter sends date-only bounds that exclude today
- Layer admin · Source US3 scenario 9, FR-045, `admin/CLAUDE.md` "Times" · `admin/src/features/audit/AuditPage.tsx:44-48, 97-111` · CONFIRMED (client side)
- Problem: `from` and `to` are browser-UTC `YYYY-MM-DD` dates for `date-time` params, and `to` is today 00:00 while the server filters `created_at <= to`.
- Failure scenario: «اليوم» returns nothing; «آخر 7 أيام» leaves out everything from today. If the server is strict it answers 422 (the bug lane A already fixed in the match picker, 8773167).
- Fix direction: Cairo-day instants from `cairoDayBounds`, with `to` at the end of today; test the select.

#### A-R1-5: A17 can't filter by importer
- Layer admin · Source US3 scenario 9 ("filters by user or importer"), FR-045 · `admin/src/features/audit/AuditPage.tsx:63-74, 129-136` (only `admin_user_id` is ever sent) · CONFIRMED
- Fix direction: an importer option that sends `source`, with a test.

#### A-R1-6: The composer's match picker shows the first 8 matches only, with no search
- Layer admin · Source US3 scenario 2, FR-016, FR-042 · `admin/src/features/notifications/MatchPicker.tsx:27, 38-41, 66` · CONFIRMED
- Problem: `slice(0, 8)` of an 8-day list ordered by competition priority; no search, paging or day choice; no selected state in audience mode; the loading line shows «اكتب عنواناً ونصاً قبل الإرسال»; no error or empty state.
- Failure scenario: tonight's match isn't among the first 8 (yesterday's top-competition matches come first), so it can't be the deep link or the «متابعو المباراة» audience.
- Fix direction: search or day-scoped paging, a selected state, and real loading, empty and error states.

#### A-R1-7: The deep link can only be a match
- Layer admin · Source US3 scenario 2 ("a match or channel picker"), contracts/admin-screens.md composer, FR-059 (S6 as an announcement route) · `admin/src/features/notifications/Composer.tsx:52, 83, 229-231` · CONFIRMED
- Problem: `target.type` allows `channel` and the API accepts it, but only `MatchPicker` is offered and `pickTarget` always sets `match`. `ChannelPicker`'s new single-select mode has no test.
- Fix direction: offer the channel picker for the deep link and test both target types end to end.

#### A-R1-8: The test send reports «أُرسل» before anything was sent
- Layer admin · Source FR-042 ("an honest test-send result"), contracts/admin-screens.md ("never faked"), T073 ("reporting the true result") · `admin/src/features/notifications/Composer.tsx:150-164`, `admin/src/i18n/ar.ts:810` · CONFIRMED
- Problem: any `201` toasts «أُرسل التجريبي إلى android · 0.6.0+60»; the returned row (`pending` at that moment) is ignored, and the raw platform is concatenated into Arabic. `Composer.test.tsx:317` only matches the text.
- Fix direction: report the row's real status (queued, then sent or failed from the log row), with the platform from `composer.platforms` in an LTR island; test pending and failed.

### MEDIUM

- **A-R1-9** Time columns show `HH:mm` only (`formatCairoTime`), with no date or ص/م: a 10-day-old login and next week's schedule both read as a clock time (`NotificationsPage.tsx:202`, `AuditPage.tsx:172, 221`, `UsersPage.tsx:187`).
- **A-R1-10** «إلغاء الإعلان» is shown to editors (`NotificationsPage.tsx:181`), who then get 403 after the destructive confirm (FR-047).
- **A-R1-11** Failed or loading reads look true or empty: `FrequencyHistory.tsx:53-59` says «لم يتغيّر تردد هذه القناة بعد» on error; A17's detail says «اختر تغييراً…» while loading or failed; the log says «لا إشعارات بعد» when filters emptied it.
- **A-R1-12** The forced change-password page has no sign-out (`App.tsx:44-50`); a flagged user can't leave the session.
- **A-R1-13** A16's drawer and the composer are plain `useState` forms, not RHF + Zod (`UsersPage.tsx:368-373`, `Composer.tsx:47-62`).
- **A-R1-14** Refusals the client can tell aren't disabled: self in the row menu and the role radios, and the last active admin (`UsersPage.tsx:238-249, 425-448`). A reset `edit_conflict` shows a toast, not `ConflictDialog`.
- **A-R1-15** A16's drawer is a hand-rolled `<aside role="dialog">` with no focus trap, Escape or `aria-modal`, placed over the sidebar, instead of `EditorDrawer`/`Modal` (`UsersPage.tsx:393-514`).
- **A-R1-16** The log's filters omit `match_started` and `sending`, with raw English labels; a test send's target shows «جميع الأجهزة» (`NotificationsPage.tsx:27-43, 196`).
- **A-R1-17** The all-devices confirm reads «سيصل إلى ≈ 48,200 جهاز جهازاً», and still sends when the reach is unknown («—») or stale for 300 ms after an audience switch (`ar.ts:792, 799`, `Composer.tsx:376`).
- **A-R1-18** A saved test device can't be replaced, and `has_push_token: false` is never shown before sending (`Composer.tsx:330-350`).
- **A-R1-19** Tests were changed with the code they cover: `NotificationsPage.test.tsx:170-190` dropped five status-word assertions in 9227866; several assertions are too weak to fail (refetch interval only, preview counts, a 2031 date).
- **A-R1-20** No screenshot next to the boards (delivery-plan §8.1 item 12). T086 is correctly open, but PR #48 merged without them, and owner-actions still says "attach to the PR".
- **A-R1-21** `admin/CLAUDE.md` is untouched: no `FormControls`, `DiffView`, `NotPermitted`, role-aware navigation, the change-password choke point, or the temporary-password rule.

### LOW

- **A-R1-22** `temporary` and `failure` aren't cleared when a panel closes (`UsersPage.tsx:73, 285-288, 316`).
- **A-R1-23** Hard-coded «محرر»/«مدير» (`UsersPage.tsx:437, 443`); `admin_user_not_found`, `notification_not_found`, `audit_not_found` have no copy.
- **A-R1-24** A17's push line says «إلى 0 جهازاً من 0» for a pending or failed push; `action` and `summary_fields` are unused, so the board's sentence is missing; `DiffView`'s `tone` is never passed.
- **A-R1-25** `useAdmins()` runs before the role gate, so an editor's direct address fires a 403.
- **A-R1-26** Conditional classes by template string, not clsx (four files); `Segmented` uses `bg-accent-container`, not the `segmented-on` surface; dead copy keys.
- **A-R1-27** `reasonOf` maps any unknown stopped reason to «غير مُعدّ» on the A13 card (`SourcesPage.tsx:199`).

## Requirements

| Requirement | Built in | Proven by | Status |
| --- | --- | --- | --- |
| US3-1 the log | `NotificationsPage.tsx` | `NotificationsPage.test.tsx` | Partly (A-R1-9, -16) |
| US3-2 compose, pickers, audience, schedule, previews | `Composer.tsx`, `MatchPicker.tsx` | `Composer.test.tsx` | **Partly (A-R1-6, -7)** |
| US3-3 test send | `Composer.tsx` | `Composer.test.tsx:317` | **Result faked (A-R1-8)**, A-R1-18 |
| US3-4 cancel | `NotificationsPage.tsx` | `NotificationsPage.test.tsx:310` | **Fails on the real API (A-R1-1)** |
| US3-5 all-devices confirm | `Composer.tsx` | `Composer.test.tsx:211` | Partly (A-R1-17) |
| US3-6 editor limits | `navigation.ts`, `NotPermitted` | `App.test.tsx`, `navigation.test.tsx` | OK (A-R1-10) |
| US3-7 temporary password, forced change | `UsersPage.tsx`, `ChangePasswordPage.tsx`, `http.ts` | `UsersPage.test.tsx`, `ChangePasswordPage.test.tsx`, `http.test.ts` | OK on the client (the server doesn't flag new accounts: B1-R1-3) |
| US3-8 deactivate / reset end sessions; self and last admin refused | `UsersPage.tsx` | `UsersPage.test.tsx` | **Fails on the real API (A-R1-1)**, A-R1-2, A-R1-14 |
| US3-9 A17 filters, diff, links | `AuditPage.tsx`, `DiffView.tsx` | `AuditPage.test.tsx`, `DiffView.test.tsx` | **Fails (A-R1-3, -4, -5)**; diff OK |
| US3-10 conflict dialog | `ConflictDialog` | `UsersPage.test.tsx` | **Fails on the real API (A-R1-1)** |
| FR-040 Zod on every response | `http.ts` `responseSchemas` | `http.test.ts` | OK |
| FR-041 new rows without reload | `queries.ts` 30 s refetch | weak test | OK |
| FR-044 change-password step | `App.tsx`, `ChangePasswordPage.tsx` | tests | OK (A-R1-12) |
| FR-046 A8 history | `FrequencyHistory.tsx` | `ChannelsPage.test.tsx` | OK (A-R1-11) |
| FR-047 role hiding | `navigation.ts` | tests | OK |

## Task audit

Ticked 19, verified 12, not done 0, partly done 7. T086 is unticked and correctly open (screenshots, and the WireGuard walk after deploy).

| Task | Mismatch |
| --- | --- |
| T072 | Filter options incomplete; refetch and time cells weakly tested (A-R1-16, -19) |
| T073 | Channel deep link and channel picker untested; the test-send result is faked; cancel uses the wrong version (A-R1-7, -8, -1) |
| T074 | Wrong `If-Match` pinned; drawer state leaks; reset's no-trace check missing (A-R1-1, -2) |
| T075, T083 | A17's entity names, period and importer filter (A-R1-3, -4, -5) |
| T080 | Filter options (A-R1-16) |
| T081 | Picker capped at 8, match-only deep link (A-R1-6, -7) |

## Owner must review

- A15 (`NotificationsPage.tsx`, `Composer.tsx`), A16 (`UsersPage.tsx`), A17 (`AuditPage.tsx`) and A8's history next to `madar-design/admin-react/screens/03-operations/*.png` and `02-content/Channels.png`, at 1440 and 1024 in both themes (T086). No screenshot is committed or attached.
- `admin/src/api/http.ts` and `admin/src/app/App.tsx`: the forced password-change choke point.

## Outside this change

- `SourcesPage.tsx`'s run row prints `started_at` twice (pre-existing).
- `etagOf` reads a symbol property that React Query's structural sharing can drop; other editors already pass `structuralSharing: false`.
- The owner-actions "Open now" anchor `#006-d06-…` doesn't match the heading (pre-existing).

## Not reviewed

- `pnpm e2e` was not run.
- Visual fidelity to the boards: no captures exist to compare.
