# Implementation review: 003-d03-follow-push-sources, lane A, round 1

- Date: 2026-11-01 · Reviewer: Claude Sonnet 5.5 (lead) with two Sonnet 5.5 layer reviewers (admin code/security; UI/spec/tests), each run twice. The lead re-opened every HIGH finding below; MEDIUM and LOW findings are the reviewers' own (read in code unless marked PLAUSIBLE).
- Branch: 003-d03-follow-push-sources (all four lane PRs merged; no lane branch was checked out, at the owner's request) · Base: origin/master (merge base 5323669) · Head: 8405dd2, plus 0 uncommitted files
- Change: Lane A's commits `b6127c9`, `cb48ed4`, `f534647` (PR #18) plus the merge `d091dce`; 61 files owned by A (+8,550 −269), of which 6 generated files are B1's generator output (`admin/src/api/generated/`). Lane A touched nothing outside `admin/`, `docs/runbooks` and its own `docs/owner-actions.md` section, and ticked `specs/002-d02-core-flows/tasks.md` T106/A-F1/A-F2 as T090/T091 instruct.
- Verdict: **CHANGES REQUESTED** · CRITICAL 0 · HIGH 8 · MEDIUM 20 · LOW 11

## Checks

| Check | Command | Result |
| --- | --- | --- |
| install | `cd admin && pnpm install --frozen-lockfile` | exit 0. The first run of every check failed only because `@dnd-kit/core` and `@dnd-kit/sortable`, declared in `package.json` and `pnpm-lock.yaml`, were missing from the local `node_modules` (environment); the lockfile is consistent |
| tsc | `pnpm typecheck` | exit 0 (after install) |
| eslint | `pnpm lint` | exit 0, 0 errors, 6 warnings (`tailwindcss/enforces-shorthand` in `matches/editor/ChannelsSection.tsx` and `StatusSection.tsx`, D2 files, outside this change) |
| vitest | `pnpm test` | exit 1: 218 passed, 1 failed (`MatchEditor.test.tsx` "offers the teams with country and competitions, and accepts free text": a 5,000 ms timeout while a backend pytest run, an app test run and ten agents were using the machine). Re-run alone: `pnpm vitest run src/features/matches/MatchEditor.test.tsx` → 44 passed, exit 0. Flaky under load, not a defect of this change |
| build | `pnpm build` | exit 0 |
| literals, token copy | `./scripts/check-literals.sh`; `./scripts/check-token-copy.sh` | exit 0 and exit 0 |
| Generated client matches the spec | `pnpm orval` and a diff | NOT RUN: it rewrites tracked files. By history only B1's commit `23603f5` touches `src/api/generated/` |
| Playwright | — | NOT RUN: arrives on D4 (delivery-plan §7) |

Ways around the checks: none. A diff scan of `admin/` (non-generated) for `.skip(`, `.only(`, `xit`, `@ts-expect-error`, `@ts-ignore`, `eslint-disable`, `any`, non-null `!` found one hit: `eslint-disable-next-line jsx-a11y/media-has-caption` in `AudioPlayer.tsx` with a justification comment. No change to `tsconfig`, ESLint, vitest, Tailwind or coverage config. The test edits in `App.test.tsx`, `DataTable.test.tsx`, `MatchesPage.test.tsx`, `http.test.ts` and `MatchEditor.test.tsx` are fixture/selector updates (but see the `colgroup` note in MEDIUM).

## Previous round

Round 1: none.

## Findings

### CRITICAL

None.

### HIGH

#### A-R1-1: A6 and A7 reorder read each row's version at save time, so a stale list is never detected
- Layer: admin · Source: spec US4 scenarios 3 and 4, edge case "Two editors reorder competitions at once. The second save gets 409, never a silent mix", T101, `contracts/admin-api.md` "Ordering" · `admin/src/features/competitions/CompetitionsPage.tsx:37-47`, `admin/src/features/satellites/SatellitesPage.tsx:38-45` · CONFIRMED (the code comment at `CompetitionsPage.tsx:37` records the gap)
- Problem: `AdminCompetition` and `AdminSatellite` list rows carry no `etag`, so `saveOrder` calls `getCompetition(id)` / `getSatellite(id)` for every row and sends the version it has just read. The server's per-item `If-Match` check can then never trip.
- Failure scenario: editors A and B open A6; B drags and saves; A, still showing the old order, drags; `saveOrder` fetches B's fresh versions and the PUT succeeds, silently overwriting B's order. The quickstart's two-browser reorder step cannot produce a 409. The tests assert the current design (the ETags come from the detail GET at save time), so they cannot catch it. Each drop also costs N GETs plus one PUT.
- Fix direction: B1 adds `etag` to the competition and satellite list rows (additive contract change, both clients regenerated); then each row sends the version it was rendered with and the GET fan-out goes. The gap is recorded in tasks.md but T101 is ticked. Task `A-R1-1` asks B1.

#### A-R1-2: Four editors handle a 409 by refetching, so the next Save silently overwrites the other editor's change
- Layer: admin · Source: spec US4 scenario 9 ("the 409 conflict dialog"); `.claude/skills/speckit-review-implementation` 4.G ("handle a 412 with a conflict state, not a silent overwrite") · `admin/src/features/channels/ChannelEditor.tsx:177,230,236-240`, `satellites/SatelliteEditor.tsx:220`, `commentators/CommentatorEditor.tsx:131`, `competitions/CompetitionEditor.tsx:125-126` · CONFIRMED (ChannelEditor read by the lead; the other three by the reviewer)
- Problem: on `edit_conflict` each editor shows a one-line error and calls `detail.refetch()`. The `If-Match` it sends is the live `etagOf(detail.data)`, while the draft and baseline stay at the old values (the seed guard at `ChannelEditor.tsx:177` stops reseeding). `CompetitionEditor.tsx:125` says why: "so the next save is made against the version that exists". Only `TeamEditor.tsx:205-225` opens `ConflictDialog` and shows the diff.
- Failure scenario: two editors change the same channel; B saves first; A saves and gets 409 with no diff; A clicks Save again and the PATCH (A's changed fields only) goes out under B's ETag and succeeds, overwriting B's value of any field A touched. `edit_conflict` is tested only for A5, the A6 ordering dialog, A4 and A3.
- Fix direction: keep the ETag together with the baseline it belongs to (as `MatchEditor`'s baseline does), open `ConflictDialog` through `lib/conflict.ts` as `TeamEditor` does, and block Save until the editor reloads or discards; a test per editor. Task `A-R1-2`.

#### A-R1-3: A10 delete sends no `If-Match`, so it can never succeed
- Layer: admin · Source: spec US4 scenario 6, D2 `contracts/admin-api.md:15` ("every PATCH and DELETE needs If-Match") · `admin/src/features/commentators/CommentatorsPage.tsx:46` (`await deleteCommentator(person.id)`), `backend/app/services/admin/commentators.py:108-111` and `writer.py:122-123` (`if_match is None` → `precondition_required()` before `refuse_if_in_use`) · CONFIRMED (lead read both sides)
- Problem: the generated `deleteCommentator(id, options)` takes no header and `adminHttp` adds none, so the server answers 428 on every delete.
- Failure scenario: the editor confirms «حذف» in the dialog that shows the usage count and gets the toast «أعد تحميل الصفحة ثم حاول مرة أخرى», which is wrong advice, on every attempt. A commentator in use never gets the `409 in_use` refusal either, because 428 is checked first. `CommentatorsPage.test.tsx:68-88` registers a DELETE handler that returns a bare 204 and asserts neither the header nor the UI outcome (the PATCH test beside it does assert `If-Match`).
- Fix direction: send the commentator's version on DELETE (list rows carry no `etag`: read the detail first, or have B1 add it) and assert both the header and the outcome, including the `409 in_use` toast. Task `A-R1-3`.

#### A-R1-4: None of the five D3 editors uses React Hook Form + Zod
- Layer: admin · Source: constitution VIII ("The admin MUST use … RHF + Zod"), `admin/CLAUDE.md`, the A-F1 precedent (T090) · `admin/src/features/teams/TeamEditor.tsx:92-98`, `competitions/CompetitionEditor.tsx:44-49`, `satellites/SatelliteEditor.tsx:111-116,144-145`, `channels/ChannelEditor.tsx:153-158`, `commentators/CommentatorEditor.tsx:53-57` · CONFIRMED (a grep for `useForm|zodResolver` over `admin/src` finds only `matches/patchForm.ts` and `auth/LoginPage.tsx`)
- Problem: every editor keeps a `useState` draft and validates by hand (`draft.name.trim() === ''`, `carriageError()`, an `^https:\/\/\S+$` regex) instead of through the Orval Zod schemas. What the form accepts can drift from what the API accepts; a refusal comes back as a generic `validation_error` with no field hint.
- Note: A-F1 itself is a shim. `matches/patchForm.ts:16-33` builds two `useForm` instances with a `zodResolver`, then `reset(patch)` and `trigger()` to validate an already-assembled patch; no field is registered, and `MatchEditor.tsx:575` sends `built`, not the parsed value. It is not a regression, but it does not meet T090's "the one React Hook Form form resolves through the Orval schema" (002's tasks.md T106 still carries the stale "resolver is not wired" text).
- Fix direction: move each editor onto `useForm` with `zodResolver` over the generated schema and show field errors. If the owner prefers controlled drafts, that is an amendment of constitution VIII, not a silent choice. Task `A-R1-4`.

#### A-R1-5: Completing a platform placeholder as a satellite channel is rejected by the API
- Layer: admin (needs B1) · Source: spec US4 scenario 5, FR-031, T097, `contracts/admin-api.md` "Channels" · `admin/src/features/channels/ChannelEditor.tsx:117-125,198-203`, `backend/app/services/admin/channels.py:127-131` (`kind_errors` forbids `satellite_id`/`frequency_mhz` on a `platform` row), `backend/app/adapters/livesoccertv_links.py:38` · CONFIRMED (cross-lane)
- Problem: the importers create placeholders as `kind='platform'`; `ChannelPatch` has no `kind`, so the editor can set the `<select>` to «satellite» locally, send `satellite_id` and `frequency`, and get 422 `not_allowed`, shown only as «راجع البيانات المدخلة». Only the "platform + shown on match pages" half works, which shows the channel in the app with no frequency. `ChannelsPage.test.tsx` builds its placeholder with `...bein` (`kind:'satellite'`), a fixture the importer never produces, so the passing test hides the gap.
- Fix direction: B1 adds `kind` to `ChannelPatch` (with the platform→satellite rule); the test fixture uses `kind:'platform'`; until then hide or disable the satellite choice for platform rows. T097 is ticked and the gap is only in the notes. Task `A-R1-5` asks B1.

#### A-R1-6: The A5 logo is not previewed on dark and light tiles
- Layer: ui/spec · Source: spec US4 scenario 2, T095 (ticked), Logo README (neutral frame) · `admin/src/features/teams/TeamEditor.tsx` (logo block: one `size-12 bg-bg` tile; `teams.editor.logoOnDark` / `logoOnLight` exist in `i18n/ar.ts` and nothing uses them) · CONFIRMED (reviewer)
- Problem: T095 says "logo upload previewed on dark and light tiles in the Logo frame"; there is one tile and no test of logo upload or preview. A dark-only crest cannot be judged on a light ground, which is the point of two tiles.
- Fix direction: two tiles (dark and light `surface-2` frames) in a shared logo field, plus a test. Task `A-R1-6`.

#### A-R1-7: Satellite ordering has no test
- Layer: tests · Source: T101 ("tests for both paths", ticked), spec US4 scenario 4 · `admin/src/features/satellites/SatellitesPage.test.tsx` (3 tests: list, https hint, frequency PATCH) · CONFIRMED (a grep finds no `satellites/order` or `orderSatellites` in any test; only `CompetitionsPage.test.tsx` covers PUT order and the 409 dialog)
- Problem: the satellite PUT body, its per-row version and its conflict dialog are unproven; `SatellitesPage.test` "refuses a reception link that is not https" asserts only the hint text, so removing the check in `save()` leaves it green.
- Fix direction: mirror the A6 keyboard-reorder and 409 tests for A7; assert the https refusal on save. Task `A-R1-7`.

#### A-R1-8: The frequency and position readouts are not the dark cyan well in the dark theme
- Layer: ui · Source: constitution IV ("`FrequencyReadout` MUST stay a dark well with cyan IBM Plex Mono digits, LTR, in both themes"), root CLAUDE.md · `admin/src/features/channels/ChannelsPage.tsx:82`, `admin/src/features/satellites/SatellitesPage.tsx:112` (both `bg-text-primary … text-text-on-inverse`), `admin/src/styles/tokens.css:15,19,41-44` · CONFIRMED (lead read the classes and tokens)
- Problem: in the dark theme `--text-primary` is `#f1f4f7` and `--text-on-inverse` is `#07090c`, so the chip is pale with dark text. The tokens `--readout-bg`, `--readout`, `--readout-dim` and the `.readout` class exist and are unused; there is no admin `FrequencyReadout` component, only two ad-hoc pills. The board (Satellites.png) shows cyan on dark.
- Fix direction: build the admin `FrequencyReadout` once from the readout tokens and use it in A7, A8 and the dashboard; golden or token test in both themes. Task `A-R1-8`.

### MEDIUM

- **`SatelliteEditor` silently clears the orbital position on a malformed number** (`SatelliteEditor.tsx:72-75,194-196,263,288`): `Number("7..5")` is `NaN`, so `orbitalPosition` returns `null` and the PATCH sends `orbital_position: null` with no error; the hint prints `?? 0`. Ticking «أقوى تردد» with MHz/SR empty also saves as "no frequency" silently.
- **Lists silently truncate at 100 and the header counts are wrong** (`ChannelsPage.tsx:39`, `TeamsPage.tsx:28`, `CommentatorsPage.tsx:38`: `limit: 100`; `next_cursor` is read only in `SourcesPage`): the old data has 2,418 channels and 1,513 teams, A8 prints «100 قناة», and the "missing logo"/"placeholders" filters over more than 100 matches cannot reach the rest.
- **A13/A2 health chip ignores `paused`** (`SourcesPage.tsx:23-27,76-78`, `DashboardPage.tsx:35-37,54`): a paused source with a closed breaker shows green «سليم» and counts as healthy in the KPI; `near_limit` is labelled «جزئي» including when the last run `failed`; the pause flag shows only as a text suffix.
- **Times print twice and lose the date** (`SourcesPage.tsx:237`, `SourceRunPage.tsx:97`: `{formatCairoTime(x)} · {formatCairoTime(x)}`; `lib/cairoTime.ts:31-34` returns `HH:mm` only): runs from different days look alike and «آخر نجاح 06:00» on a source silent for three days looks fresh (stale data shows its age, constitution II).
- **A10 editor has no unsaved guard and no player** (`CommentatorEditor.tsx:148,198-202`: `onClose={onClose}`, only the uploaded file's name is shown); scenarios 6 and 9 require both. Clip durations all read "--:--" (`durationMs` is never passed). Photo and clip upload are untested.
- **`SortableList` resets to the old order when a drop starts saving** (`SortableList.tsx:107-109`, effect on `[items, itemKey, lifted]`; both pages pass an inline `itemKey` and `saving` flips in the same event): the dropped row snaps back for the whole save, then jumps (CONFIRMED by reading, not run).
- **dnd-kit's default English screen-reader text remains** (`SortableList.tsx:195` passes no `accessibility` prop and the handle spreads `attributes` including `aria-describedby`); T092 says Arabic announcements. `FrequencyField.tsx:44,55,78` also has English `aria-label` words outside `ar.ts`.
- **Missing keyboard focus rings** (constitution IV): `ChannelEditor` access radios, `SatelliteEditor` E/W radios, and the upload labels in all five editors (`hover:` but no `focus-within:` over an `sr-only` input) have none; the radios have no arrow-key roving.
- **Nested modals break Tab** (`Modal.tsx:41-77`): each open Modal adds a `document` keydown trap with a last branch that pulls focus into its own panel; the editors render `EditorDrawer` and the unsaved-guard `ConfirmDialog` as siblings, so both traps are live and Tab never reaches the dialog's second button. Fix: only the top-most modal traps.
- **The A13 card shows no "items found" figure** (`SourcesPage.tsx`: the sparkline is `aria-hidden` with no number and `sources.itemsSparkline` is unused); scenario 7 lists it and `Sources.png` prints it.
- **`AudioPlayer` sticks on "loading" after a buffering stall** (`AudioPlayer.tsx`): handlers for `waiting`, `pause` and `error`, none for `playing`/`canplay`; sound plays under «جارٍ تحميل المقطع» and a click restarts instead of pausing. The 5 tests never fire `waiting`.
- **Reorder is not discoverable by keyboard**: the hint says «اسحب لإعادة الترتيب» and the board advertises "Alt ↑ ↓"; Space/Enter-to-lift is mentioned nowhere in the UI.
- **Loading, error and empty states are dishonest on A6, A7, A2 and A13**: while loading, the pages show the empty-state copy («أضف أول بطولة…»); errors ignore `error.code` and have no retry; A2's error body reads «جارٍ تحميل لوحة المتابعة»; A13 shows a run's loading copy and a retry button labelled «المزيد».
- **Run history does not poll** (`sources/queries.ts:11-13`): only `useSources` does (30 s); FR-032 says "both refresh while open". Pause and resume clicks, the 30/60 s refetch and run-detail states are untested.
- **No screenshot next to the design PNGs** (delivery-plan §8.1 item 12): T106/T107 are honestly open. Compared by reading: A2 lacks the board's header actions, last-updated stamp, 4-KPI row, coverage bars and source sparklines; A7 rows lack channel count; the A13 stage pipeline of `SourceRun` is replaced by count blocks; the drawer opens on the right where the boards put the editor on the left.
- **A-F2 is partly done** (T091): `MatchesPage` keeps a local `Skeleton` and its own empty states and `DataTable`'s `loading`/`emptyMessage` are unused; `DataTable` changed `scope="rowgroup"` to `"colgroup"` and the A3 test moved from `rowheader` to `columnheader` (markup changed to fit the assertion; small a11y regression).
- **B1's commit edited a Lane A file** (FR-051): `admin/src/features/matches/queries.ts` (`SourceItem` → `SourceHealth`), documented as forced by the regeneration.
- **Contract gaps shipped as feature gaps** (recorded in tasks.md, owner decisions): no aliases in A5/A6 (scenarios 2 and 3 name them), no «بلا صورة»/«بلا صوت» filters on A10, no `kind` on `ChannelPatch` (A-R1-5).
- **Test breadth gaps**: the A6 editor, create/patch and logo upload are untested; `409 already_exists` on A8 and the focus trap/guard are untested; the A10 test contradicts the contract (it deletes a commentator with `usage.matches: 23` and returns 204, while D2 says `409 in_use`) and the dialog body promises the delete will succeed.
- **`activeSection('/import-runs/9123')` has no match** and returns `dashboard`, so the sidebar highlights A2 on a run page; no test asserts A2 is the landing page.

### LOW

- `AudioPlayer.tsx:97` adds `eslint-disable-next-line jsx-a11y/media-has-caption` (commented; the only new suppression); `src` has no scheme or host check (an `<audio src>` does not run `javascript:`); the module-level `activeElement` leaks between tests.
- A hand-written Zod envelope for `POST /sources/{}/run` (`http.ts:105-112`) because the spec has no 202 body schema (a B1 contract gap).
- `as Category` / `as Access` casts on select values and `(failure.meta as { stale_ids?: number[] })` are unvalidated.
- `SourcesPage.tsx:166` titles every failure toast «تشغيل الآن», including pause and resume; `TeamsPage.tsx:185` uses the error copy as a retry button label; Teams search sends a request per keystroke.
- `KpiCard`: a linked card's `aria-label` replaces the figure and context in the accessible name; dashboard KPI hrefs are the bare `/matches` and `/channels`, not the filtered lists (the filter is local state).
- The kebab menu in `CommentatorsPage` uses `role="menu"` with no arrow keys, Escape or focus return.
- A missing ETag on an ordering item is sent as `null`; the backend fails closed with 428 and Arabic copy exists (`ar.ts:698`), so this is LOW. The API has no 412, only 409 and 428.
- `useRefreshAdmin` invalidates every query after any write (broad, harmless).
- `ChannelEditor`'s access radios use template-string classes instead of `clsx`.
- `CompetitionsPage.tsx:51` repeats the literal `new ApiError('network_error', null)` where `NETWORK_ERROR` exists.
- `SatelliteEditor`'s unsaved-changes guard and the board's drawer side were not exercised in a browser.

## Requirements

| Scenario | Built in | Proven by | Status |
| --- | --- | --- | --- |
| 1 A-F1 / A-F2 | `matches/patchForm.ts`; `MatchesPage.tsx` + `DataTable` | existing MatchEditor/MatchesPage tests (fixture-only edits) | Partial (A-F1 is a facade, A-F2 keeps local markup) |
| 2 A5 teams | `TeamsPage`, `TeamEditor` | `TeamsPage.test`: filters, list, PATCH + If-Match, create, 409, guard | Partial (A-R1-6; no aliases; truncation) |
| 3 A6 competitions | `CompetitionsPage`, `SortableList` | keyboard PUT, 409 dialog | Partial (A-R1-1; editor untested; no aliases) |
| 4 A7 satellites | `SatellitesPage`, `SatelliteEditor` | list, frequency PATCH | Partial (A-R1-1, A-R1-2, A-R1-7, A-R1-8) |
| 5 A8 channels | `ChannelsPage`, `ChannelEditor` | filters, marker, complete (wrong fixture), copy-to-satellite | Partial (A-R1-2, A-R1-5, A-R1-8) |
| 6 A10 commentators | `CommentatorsPage`, `CommentatorEditor`, `AudioPlayer` | cards, delete-with-usage (contradicts contract), rename, 5 player states | **Partial: delete cannot succeed (A-R1-3)** |
| 7 A13 sources | `SourcesPage`, `SourceRunPage` | health, 409 run, cursor, run detail | Partial (items found, dates, paused chip) |
| 8 A2 dashboard | `DashboardPage`, `KpiCard` | values 2/14/50 %, links, tiles, recent lines | Built; loading/error/empty and 60 s refetch untested |
| 9 common states, unsaved guard, conflict dialog | skeleton only in Teams/Channels/Matches | n/a | Partial (A-R1-2; A10 has no guard) |
| FR-033 Orval client + Zod on every response | `http.ts` `responseSchemas` | every new endpoint registered; one hand-written 202 envelope | Built |
| FR-034 keyboard focus, RTL, tokens | components | `check-literals.sh` passes | Partial (focus rings, readout) |

## Task audit

Ticked 19 (T088–T105 and T108), verified 12, not done 0, partly done 7.

| Task | Mismatch |
| --- | --- |
| T090 `[x]` (A-F1) | RHF only wraps a `safeParse`; no field is registered (A-R1-4). |
| T091 `[x]` (A-F2) | `MatchesPage` keeps a local `Skeleton`/empty states. |
| T092 `[x]` | Announcements are Arabic, the dnd-kit instructions stay English; the list snaps back on drop. |
| T095 `[x]` | One logo tile, no preview test (A-R1-6). |
| T097 `[x]` | The platform→satellite completion cannot work (A-R1-5). |
| T098 `[x]` | Delete cannot succeed and its test hides it (A-R1-3). |
| T101 `[x]` | Reorder conflict check is off and A7 has no test (A-R1-1, A-R1-7). |
| T106, T107 `[ ]` | Honestly open: the WireGuard walk and the screenshots are owner-gated. |

## Owner must review

- `admin/src/api/http.ts`: the mutator, `responseSchemas` and the hand-written 202 envelope.
- The five editors' write paths (`If-Match` and conflict handling): `ChannelEditor.tsx`, `SatelliteEditor.tsx`, `CommentatorEditor.tsx`, `CompetitionEditor.tsx`, and the reorder pages (A-R1-1, A-R1-2).
- Each screen next to its design PNG once T107's screenshots exist: A2 `Main`, A5 `Teams`, A6 `Competitions`, A7 `Satellites`, A8 `Channels`, A10 `Commentators`, A13 `Sources` and `SourceRun` (`madar-design/admin-react/screens/`).
- The `@dnd-kit` pins in `admin/package.json` (6.3.1, 10.0.0; MIT, current npm `latest`, React 18 peers satisfied; justified in plan.md and research R22).

## Outside this change

- The 6 `tailwindcss/enforces-shorthand` eslint warnings are in D2 files (`matches/editor/ChannelsSection.tsx`, `StatusSection.tsx`).
- Backend gaps Lane A depends on (to be raised with B1 by the owner): `etag` on the competition, satellite and commentator list rows; `kind` on `ChannelPatch`; `409`/`202` body schemas.
- `pwa.yml` runs `flutter build web` without the Firebase web config writer (Lane M's review, B2's file).

## Not reviewed

- Rendering in a browser (no screenshot exists, T107 open): spacing, the 1024 px layout, theme contrast, drawer side.
- Test files beyond the lines quoted by the reviewers; not seeing the tests fail first (test-first) is unverified.
- `Field`, `ConflictDialog`, `ConfirmDialog` internals (does `ConfirmDialog` support typed confirmation?), `EmptyState`, `Toast`; `admin.zod.ts` / `admin.msw.ts` against `backend/openapi/admin.json` beyond the git-history evidence.
- Whether the server's `PUT order` bumps per-row versions the way the client assumes (B1's round reads the server side).
