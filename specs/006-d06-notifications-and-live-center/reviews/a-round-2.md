# Implementation review: 006-d06-notifications-and-live-center, lane A, round 2

- Date: 2026-11-09 · Reviewer: Claude Code (Opus 5.5, `claude-opus-5-5`), layers reviewed directly (no subagents)
- Branch: `d06-a` · Base: `origin/master` (merge base `b7fd7d9`) · Head: `7b630c0`, plus 0 uncommitted files
- Change: 19 commits, 310 files (239 in another lane's folders), +38 280 −560. The lane's own work is `bef8ea3`..`af31032` (round 0, reviewed in round 1) and `7b630c0` (round-1 fixes, 19 files). The other-lane files come from the merges of PRs #46 (B1), #47 (B2) and #49 (M) into the spec branch, which `d06-a` carries; they are not lane A's work and aren't reviewed here. The one other-lane file in a lane A commit is `backend/openapi/admin.json` (A-R2-4).
- Verdict: **CHANGES REQUESTED** · CRITICAL 0 · HIGH 1 · MEDIUM 2 · LOW 5

## Checks

| Check | Command | Result |
| --- | --- | --- |
| typecheck | `pnpm typecheck` (in `admin/`) | exit 0 |
| lint | `pnpm lint` | exit 0 |
| literals | `./scripts/check-literals.sh` | exit 0 |
| token copy | `./scripts/check-token-copy.sh` | exit 0 |
| unit tests | `pnpm test -- --maxWorkers=4`, then `pnpm test` | exit 1 both times, at load average 23–25 (other review agents running): 396/402 then 399/402. Every failure is in `Composer.test.tsx`: `counts the title to 65…` times out at 5 s and its typing runs on into the next tests (A-R2-3) |
| unit tests, composer alone | `npx vitest run src/features/notifications/Composer.test.tsx` (twice) | exit 0, 18/18 both times (`counts the title…` takes 2.3 s) |
| build | `pnpm build` | exit 0 |
| generated client current | `pnpm orval` in a scratch copy, then `diff -r` against `src/api/generated` | exit 0, no diff |
| contract source | `git diff --quiet d06-b1 HEAD -- backend/openapi/admin.json` | identical to B1's export (`0d945f2`) |
| Playwright smoke | `pnpm e2e` (Prism mock) | exit 0, 4/4 |
| Ways around the checks | `git show 7b630c0` grep for `.skip(`, `.only(`, `eslint-disable`, `@ts-expect-error`, `@ts-ignore`; removed assertions | none; the two removed preview assertions were re-added scoped to the preview panel |
| CI | `gh run list --branch d06-a` | the round-1 fixes are not pushed (`origin/d06-a` is `af31032`), so no CI has run on them |

## Previous round

| Finding | Now |
| --- | --- |
| A-R1-1 row `ETag` as `If-Match` | fixed: `UsersPage.tsx:71, 92` and `NotificationsPage.tsx:118` send `row.etag`; the reset reopens the drawer with the returned row's version. Tests refuse any other version (`UsersPage.test.tsx:94-96`). Needs B1-R1-2's schema, which is on the spec branch |
| A-R1-2 drawer state leaks | fixed: keyed per account (`UsersPage.tsx:282`), tests at `UsersPage.test.tsx:263, 287` |
| A-R1-3 entity names and links | fixed: plural server names, channel editor opened in place (`AuditPage.tsx:31-40, 282-303`). Three written entities still have no filter option (A-R2-7) |
| A-R1-4 period bounds | fixed: `periodBounds` uses Cairo-day instants ending at the end of today; tested per option with a fixed clock |
| A-R1-5 importer filter | fixed: `source` in the URL, clearing the user and vice versa; tested |
| A-R1-6 match picker capped at 8 | fixed: day-scoped list, search, selected state, loading/empty/error; `MatchPicker.test.tsx` |
| A-R1-7 channel deep link | fixed: `ChannelPicker` single-select, `/channel/{id}` as the server builds it (`services/admin/notifications.py:278`); tested for the announcement and the test |
| A-R1-8 honest test-send result | **partly fixed**: queued and `failed` rows are honest, but a row the dispatcher finishes as `sent` without delivering still reads «أُرسل» (A-R2-1) |
| A-R1-9 time without date | still open |
| A-R1-10 cancel shown to editors | still open (`NotificationsPage.tsx:181` has no role check) |
| A-R1-11 failed reads look empty | still open |
| A-R1-12 no sign-out on the change-password page | still open |
| A-R1-13 not RHF + Zod | still open |
| A-R1-14 self / last admin not disabled | still open |
| A-R1-15 hand-rolled drawer | still open |
| A-R1-16 log filter options | still open (`NotificationsPage.tsx:27-43`) |
| A-R1-17 «جهاز جهازاً», send with unknown reach | still open (`ar.ts:798, 805`) |
| A-R1-18 test device can't be replaced | still open |
| A-R1-19 weak assertions | partly fixed: the new tests are strong; the old ones are unchanged |
| A-R1-20 no screenshots | still open (T086, owner) |
| A-R1-21 `admin/CLAUDE.md` untouched | still open |
| A-R1-22 `temporary`/`failure` not cleared | fixed (`UsersPage.tsx:221, 291`) |
| A-R1-23 hard-coded role words, missing `*_not_found` copy | still open (`UsersPage.tsx:440, 446`) |
| A-R1-24 «إلى 0 جهازاً من 0», unused `summary_fields` | still open |
| A-R1-25 `useAdmins()` before the role gate | still open (`AuditPage.tsx:85`) |
| A-R1-26 template-string classes | partly fixed: the new code uses `clsx`; `AuditPage.tsx:195`, `Composer.tsx:316` still don't |
| A-R1-27 `reasonOf` fallback | still open |

## Findings

### CRITICAL

None.

### HIGH

#### A-R2-1: The test send still reports «أُرسل» for a push that reached nobody
- Layer admin · Source FR-042 ("an honest test-send result"), task A-R1-8 ("sent or failed with its reason"), contracts/admin-screens.md composer ("never faked") · `admin/src/features/notifications/Composer.tsx:439-440`; `admin/src/features/notifications/Composer.test.tsx:169-175` · CONFIRMED
- Problem: `TestResult` picks its wording from `row.status` alone. The dispatcher sets `status = 'sent'` whenever it has walked the audience (`backend/app/notifications/dispatcher.py:653`), whatever the counts: a token FCM calls `UNREGISTERED` is cleared and counted in neither `sent` nor `failed` (`backend/app/notifications/sender.py:151-152`), and a non-transient per-message error adds to `failed` only (`sender.py:155-158`, recorded at `dispatcher.py:631-636`). `failed` as a status is reached only after `MAX_ATTEMPTS` whole-page retryable errors. The test mock models a failure only as `status: 'failed'`, so nothing exercises the real shape.
- Failure scenario: the admin's saved phone reinstalled the app, so its token is stale. They tap «إرسال تجريبي لجهازي»; the row ends `status: sent, sent: 0, failed: 0`; the composer says «أُرسل التجريبي إلى Android · 0.6.0+60» and nothing arrives. The same happens for a rejected token (`sent: 0, failed: 1`).
- Fix direction: treat a finished row as delivered only when `sent ≥ 1`; a `sent` row with `sent: 0` reads as not delivered, with the failed count and the reason when there is one. Test `{status: 'sent', sent: 0, failed: 1}` and `{status: 'sent', sent: 0, failed: 0}`.

### MEDIUM

- **A-R2-2** The test-send poll gives up on a lifetime counter (`admin/src/features/notifications/queries.ts:43, 51-52`): `dataUpdateCount` counts every read of the shared `['…notifications', {limit: 20}]` query, not this send's. After one send that waits 30 reads (a busy dispatcher on a match night), or about 30 reads across earlier sends, every later test send shows «لم يؤكد صندوق الإرسال النتيجة بعد» at once and `refetchInterval` returns `false`, so it never reads its row. Count reads from the send (remember the count when the send starts, or key the read by row id). CONFIRMED by reading.
- **A-R2-3** `pnpm test` fails under load: `Composer.test.tsx:196` types about 245 characters with `userEvent` (2.3 s when idle) against the 5 s default; at load average 23 it times out, and its typing keeps going into the next tests (the next title arrives as «بلبيبفبرب…»), failing two to five more. Round 1 saw the same. CI's 4-core runner has more margin, but the round-1 fixes have not been through CI. Fill the long values with one `paste`/`fireEvent.change`, or give the long tests their own timeout.

### LOW

- **A-R2-4** `backend/openapi/admin.json` (B1's contract) is committed in lane A's `7b630c0`. It is byte-identical to B1's export in `0d945f2` and was committed at the same moment, and the spec branch merges B1 first, so nothing diverged; but `d06-a` alone has the contract ahead of its schema (`backend/app/schemas/admin.py:881-895, 953-964` lack `etag`), so `backend.yml`'s contract check would fail on `d06-a` by itself. Next time, wait for B1's merge, or say in the commit that the file is B1's export.
- **A-R2-5** «كل الأيام» in the match picker (`MatchPicker.tsx:76-80`) asks for eight Cairo days; in the week that spans the end of Cairo's summer time (last Thursday of October) that is 8 days + 1 hour, and `validate_window` (`backend/app/domain/time.py:66`) refuses it, so the option shows the error state. `today` is also fixed at mount, so a composer left open past midnight offers yesterday as «اليوم».
- **A-R2-6** The match search is case-sensitive (`MatchPicker.tsx:91`, `name.includes(needle)`): «liverpool» doesn't find «Liverpool».
- **A-R2-7** A17's entity filter leaves out three names the server writes, `unresolved_name`, `source` and `hidden_channel_names` (`unresolved_names.py:33`, `sources.py:30`, `lists.py:292`), and `hidden_channel_names` has no Arabic label (`AuditPage.tsx:31-40`, `ar.ts` `audit.entities`).
- **A-R2-8** Explicit `from`/`to` in the URL are sent as typed (`AuditPage.tsx:95-96`), so a hand-written date-only link sends date-only bounds; `AuditPage.test.tsx:146` pins that form.

## Requirements

| Requirement | Built in | Proven by | Status |
| --- | --- | --- | --- |
| US3-1 the log | `NotificationsPage.tsx` | `NotificationsPage.test.tsx` | Partly (A-R1-9, A-R1-16) |
| US3-2 compose, pickers, audience, schedule, previews | `Composer.tsx`, `MatchPicker.tsx`, `ChannelPicker.tsx` | `Composer.test.tsx`, `MatchPicker.test.tsx` | OK (A-R2-5, A-R2-6) |
| US3-3 test send | `Composer.tsx`, `queries.ts` `useTestOutcome` | `Composer.test.tsx:376-465` | **Not honest when the row ends `sent` with nothing delivered (A-R2-1)**, A-R2-2 |
| US3-4 cancel | `NotificationsPage.tsx:118` | `NotificationsPage.test.tsx:319, 349` | OK with B1-R1-2 (A-R1-10 open) |
| US3-5 all-devices confirm | `Composer.tsx:159-162, 405-412` | `Composer.test.tsx:229` | Partly (A-R1-17) |
| US3-6 editor limits | `navigation.ts`, `NotPermitted` | `App.test.tsx`, `navigation.test.tsx` | OK (A-R1-10) |
| US3-7 temporary password, forced change | `UsersPage.tsx`, `ChangePasswordPage.tsx`, `App.tsx` | `UsersPage.test.tsx`, `ChangePasswordPage.test.tsx` | OK (A-R1-12) |
| US3-8 deactivate / reset, self and last admin | `UsersPage.tsx` | `UsersPage.test.tsx:305-385` | OK (A-R1-14) |
| US3-9 A17 filters, diff, links | `AuditPage.tsx`, `DiffView.tsx` | `AuditPage.test.tsx` | OK (A-R2-7, A-R2-8) |
| US3-10 conflict dialog | `ConflictDialog` | `UsersPage.test.tsx:387`, `NotificationsPage.test.tsx:349` | OK |
| FR-040 Zod on every response | `http.ts` `responseSchemas` | `http.test.ts` | OK |
| FR-041 new rows without reload | `queries.ts` 30 s refetch | `NotificationsPage.test.tsx:281` | OK |
| FR-042 composer | as US3-2/3/5 | | **Partly (A-R2-1)** |
| FR-043 A16 | `UsersPage.tsx` | `UsersPage.test.tsx` | OK |
| FR-044 change-password step | `App.tsx`, `ChangePasswordPage.tsx` | tests | OK |
| FR-045 A17 | `AuditPage.tsx` | `AuditPage.test.tsx` | OK |
| FR-046 A8 history | `FrequencyHistory.tsx` | `ChannelsPage.test.tsx` | OK (A-R1-11) |
| FR-047 role hiding | `navigation.ts` | tests | OK |

## Task audit

Ticked 27 (T068–T085, T087, A-R1-1 … A-R1-8), verified 26, not done 0, partly done 1. T086 is unticked and correctly open (screenshots and the WireGuard walk are the owner's).

| Task | Mismatch |
| --- | --- |
| A-R1-8 | A finished row is reported from its status only, so a `sent` row with nothing delivered reads «أُرسل» (A-R2-1) |

## Owner must review

- A15 (`admin/src/features/notifications/NotificationsPage.tsx`, `Composer.tsx`, `MatchPicker.tsx`), A16 (`admin/src/features/users/UsersPage.tsx`) and A17 (`admin/src/features/audit/AuditPage.tsx`) next to `madar-design/admin-react/screens/03-operations/*.png`, at 1440 and 1024 in both themes (T086). No screenshot is committed or attached yet; the composer's match picker and channel deep link changed this round.
- `backend/openapi/admin.json` in `7b630c0`: B1's per-row `etag` on `AdminUserRow` and `NotificationRow` (identical to B1's `0d945f2`), and the regenerated client.

## Outside this change

- 239 files owned by B1, B2 and M arrive through the merges of PRs #46, #47 and #49 into the spec branch, which `d06-a` carries; they are those lanes' to review.
- `tasks.md` in `7b630c0` also adds the other three lanes' round-1 blocks (written by their round-1 reviews); the spec branch holds the same blocks, since ticked.
- `SourcesPage.tsx`'s run row prints `started_at` twice (pre-existing).

## Not reviewed

- Visual fidelity to the boards: no captures exist to compare (T086).
- The quickstart A walk against the real API over `wg0`: needs a deploy.
- A clean `pnpm test` at normal load: the machine was shared with three other reviews; the failing file passes alone.
