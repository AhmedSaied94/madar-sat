# Contract: admin screens

Lane A owns `admin/`, against B1's regenerated client and Zod schemas. Each screen is rebuilt from its board with shared components and tokens. Copy goes per feature in `ar.ts`. Every response schema is registered in `responseSchemas` (`http.ts:123-187`), because a missing entry throws.

`FormControls` and `Skeleton` are in `INDEX.md` and unbuilt in the admin. The select and segmented control these screens need are built once under `FormControls`.

`.diff` is already built: `INDEX.md` lists it under ConfirmDialog, and `ConflictDialog.tsx:81` renders it. It's extracted as `components/ConfirmDialog/DiffView.tsx`, taking `changes: readonly ConflictChange[]` and `layout: 'stacked' | 'columns'`. `ConflictDialog` keeps `stacked`, its `conflict-diff` test ID and its existing tests, which stay unchanged. A17 uses `columns`, the قبل / بعد grid on `Audit.html`.

## Routes and roles

Registered in `App.tsx` as eager imports (:7-20) and `SignedInShell` children (:54-68). They hit `ComingSoon` today, so `App.test.tsx:91-98` moves to a route still unbuilt.

| Route | Screen | `editor` | `admin` |
|---|---|---|---|
| `/notifications` | A15 log | Read | Read and compose |
| `/users` | A16 | Not-permitted | Yes |
| `/audit` | A17 | Not-permitted | Yes |
| `/change-password` | Forced step | Yes | Yes |

The shell hides what a role can't use, read from `session.admin.role`. A direct address shows a shared not-permitted state, using the `forbidden` copy. The server's refusal is the real check.

A13 stays open to editors, though the A16 board says otherwise. That inconsistency is older than this spec and is noted for the owner.

## Change password

No board draws it, so it follows A1's form: current, new, confirm, validated with RHF and Zod.

- `http.ts`'s `requestWithRetry` catch (:379-394) is the one choke point. On `403 password_change_required` it reports through a new `bindSession` handler (:219, :231), and the session sets a flag.
- `SignedInShell` (`App.tsx:24-41`) redirects to `/change-password` on the flag or on `session.admin.must_change_password`. Nothing else renders until it's done.
- `refreshOnce` bypasses that catch, and a `403` on refresh ends the session (`http.ts:250-268,277`), so `auth/refresh` staying exempt on the server is what keeps this working. A test covers it.

## A15: the log

| Column | Source |
|---|---|
| النوع | `type`, or «تصحيح» for `is_correction`, or a test chip for `is_test` |
| الهدف | `target.label`, else «جميع الأجهزة» |
| المستقبلون، نجح، فشل | `recipients`, `sent`, `failed`, tabular |
| الوقت | `sent_at`, else `due_at`, in the admin's zone |
| الحالة | Status with reason, like the board's «فشل · FCM 503» |

- **Filters:** type and status, kept in the URL.
- **Paging:** `DataTable` has no cursor, so it follows `SourcesPage.tsx:193-202,321-346`.
- **Refresh:** `refetchInterval` 30 s, as `sources/queries.ts:8`.
- **Reasons** map to Arabic: `late`, `match_finished`, `score_fell`, `no_net_change`, `type_off`, `admin`. Any other text shows raw as an LTR island.
- **States the board omits:** empty, loading and error, using `EmptyState` and the shared patterns.

### Composer

Inline on the page, as on the board. Admin only.

- **Fields:** title with a 65-counter, body with a 180-counter, deep link, audience, now or a time.
- **Deep link and audience pickers:** a new match picker (`features/notifications/MatchPicker.tsx`) and a channel picker. `ChannelPicker` is `onAdd` only (`features/matches/ChannelPicker.tsx:11-15`), so it gains a single-select mode rather than being copied.
- **Audience:** all five kinds from FR-016. The board draws only «كل الأجهزة» and a match's followers («متابعو ليفربول أو تشيلسي»), so the others follow that option's look.
  - `match` and `channel` use the pickers above.
  - `team` uses `features/matches/TeamPicker.tsx`. It also allows free text, which isn't an audience, so sending stays disabled until `teamId` is set.
  - `competition` uses the `FormControls` select over `useCompetitions()`.
- **Reach:** `GET notifications/reach`, debounced on audience change, with its age shown.
- **Time:** `cairoWallTimeToUtc`, as `FieldsSection.tsx:48-69`. A past time is refused in the form and by the server.
- **Previews:** Android and iPhone, updating as you type, with the board's look.
- **Test send:** «إرسال تجريبي لجهازي» shows the saved device's platform and app version. With none saved, it asks for the device ID from S15. Saving one sends `If-Match` from the `GET`, and a conflict reloads the saved device. The result reports what the outbox row did, and it's never faked.
- **All devices:** `ConfirmDialog` showing the reach, before sending.
- **Cancel:** on a pending announcement's row, sending `If-Match`. A conflict uses `ConflictDialog`.

## A16: users

Columns as on the board: المستخدم، الدور، الحالة، آخر دخول, the TOTP column as the board's V2 mark, and a menu.

| Status | When |
|---|---|
| نشط | `is_active`, not locked |
| مقفل مؤقتاً · 11 د | `locked_for_s` set, shown in minutes |
| معطّل | `!is_active` |

- `HealthChip` lacks the disabled tone (`Users.html:96`), so it gains one.
- **Drawer:** create or edit, including the role, with `If-Match` on edits.
- **Menu:** edit, deactivate or reactivate by status, and reset.
- **Temporary password:** shown once with copy, and regenerated only through reset. It's held in component state only, never in React Query's cache, and is cleared on close.
- **Refused actions:** `cannot_change_self` and `last_admin` are shown in the drawer, and the options are disabled when the client can tell.
- **Reset and deactivate** go through `ConfirmDialog`.

## A17: audit

List plus detail pane, as on the board.

- **Filters:** user or importer, entity, period, kept in the URL.
- **Diff:** `[old, new]` pairs side by side, through `DiffView` with `layout="columns"`. Any other shape shows raw on both sides, and never throws. A test feeds it `{"password": "changed"}`.
- **Links:** the entity's editor, «فتح القناة» for a channel, and the push with its counts when `notification` is set.
- **Restore:** not built (FR-045).

## A8: frequency history

In `ChannelEditor.tsx`, between :488 and :490, edit mode only. «سجل التردد» as on `Channels.html:127-129`: date, old → new, actor. Readouts stay dark and LTR. Empty state: no row is drawn, with a one-line note.

## A13: stopped runs

`SourceHealth.last_run.status = stopped` shows the reason in Arabic: «غير مُعدّ» for `not_configured` and «بلغ الحد اليومي» for `budget_reached`. The card's health tone stays neutral, because neither is a fault.

## Tests

Beside the code, with MSW over the generated types. Each new screen is tested as `admin` and as `editor`. Also the forced change-password flow, the diff's raw fallback, the composer's counters and confirmation, and the temporary password leaving no trace after close. Playwright screenshots at 1024 and 1440 cover the three boards.

## Noted, not changed

A2's «من N مباراة اليوم» sums the missing groups (`DashboardPage.tsx:55,71`), rather than the day's total. Out of scope.
