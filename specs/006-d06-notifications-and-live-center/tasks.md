---

description: "D6 · Notifications and live center: tasks per lane"
---

# Tasks: D6 · Notifications and live center

**Input**: Design documents from `specs/006-d06-notifications-and-live-center/`: [spec.md](spec.md), [plan.md](plan.md), [research.md](research.md), [data-model.md](data-model.md), [contracts/](contracts/), [quickstart.md](quickstart.md).

**Tests**: Mandatory (constitution, Quality Gates). In every lane, test tasks come first and must be seen failing before the code they cover.

**Organization**: one `## Lane` section per lane, each an independently testable user story, plus `## Before lanes start` and a final `## Done check`.

- A lane implements and ticks **only its own section** and changes only its own folders. Generated files are never edited by hand.
- Review fix tasks are appended at the end of a lane's section by `/speckit-review-implementation`.
- **Every merge to `master` deploys** (`.github/workflows/backend.yml`). B1's contract PR must be inert for push (T015), and B1's push PR turns every automatic type on for every follower when it deploys (T037).

| Section | Spec story | Story label | Branch | Folders |
| --- | --- | --- | --- | --- |
| Lane B1 | User Story 1 (P1) | `[US1]` | `d06-b1` | `backend/` except `backend/app/adapters/`, `backend/tests/adapters/`, `backend/tests/fixtures/`. Regenerated clients only in T019 |
| Lane B2 | User Story 4 (P4) | `[US4]` | `d06-b2` | `infra/`, `.github/`, `backend/app/adapters/`, `backend/tests/adapters/`, `backend/tests/fixtures/` |
| Lane A | User Story 3 (P3) | `[US3]` | `d06-a` | `admin/` |
| Lane M | User Story 2 (P2) | `[US2]` | `d06-m` | `app/` |

Every lane may also edit `docs/runbooks/` for its own parts and its own section of `docs/owner-actions.md` (FR-070, FR-071).

## Format: `[ID] [P?] [Story] Description`

- **[P]**: can run in parallel (different files, no dependency on an unfinished task).
- **[USn]**: the spec story the task belongs to.
- Paths are repo-relative.

## Dependencies & execution order

### Between lanes

```text
T001 (ads amendment on master) ─▶ T002 (docs and spec on master) ─▶ all lanes
 ├─▶ B1 T003–T019 (0009 + contract PR) ─▶ A T068 on, M T089 on, B2 T047 on
 │     M T088 (S3 baseline golden) comes before any S3 code change, and needs nothing
 ├─▶ B1 T020–T036 (push) ─▶ owner reviews the audiences ─▶ T037 merges ─▶ types on for every follower
 ├─▶ B1 T034 (channel_changes.py) merged ─▶ B2 T050
 ├─▶ B2 T052 (saved pages) ─▶ T053–T058 (sporteventz)
 ├─▶ owner T059 (API-Football checks) ─▶ B2 T060–T064. If it isn't done, the rest of the day goes on
 ├─▶ M T116 (device ID in S15) ─▶ the real test send. A runs on the mock until then
 └─▶ M T119 (new PWA and Android test build out) ─▶ Done check
A real followed match on the deployed hosts ─▶ Done check
```

### Inside each lane

Tests first, seen failing, then code. The tasks are in order unless marked [P].

### Parallel examples

- **B1:** T004–T010 are separate test files. T020–T023 are pure and need no database. T016 and T017 touch different services once T015 sets the pattern.
- **B2:** T044–T046, and T053 with T060.
- **A:** T070–T076, then A16 (T082) and A17 (T083) touch different folders.
- **M:** T091–T095 and T099–T101. T107 and T108 touch different folders, and S15 (T113–T116) shares nothing with S3 (T109–T111).

### Requirement coverage

| Requirements | Tasks |
| --- | --- |
| FR-001–FR-003, FR-007, FR-008 | T020, T024, T029, T033 |
| FR-004–FR-006, FR-009 | T020, T021, T023, T024, T029, T031, T033 |
| FR-010–FR-012 | T023, T025, T031, T034 |
| FR-013–FR-015 | T005, T009, T013, T017, T026, T035 |
| FR-016, FR-017 | T006, T015, T027, T032 |
| FR-018 | T023, T031 |
| FR-019–FR-021 | T022, T027, T030, T032, T037, T040–T042 |
| FR-022 | T004, T013 |
| FR-023–FR-026 | T006–T010, T014–T017 |
| FR-027, FR-028 | T003–T011, T019–T028 |
| FR-029 | T028, T036 |
| FR-030–FR-033 | T010, T018, T038, T039, T044, T047, T052–T058 |
| FR-034–FR-036 | T044, T047, T059–T064 |
| FR-037–FR-039 | T010, T018, T045, T046, T048–T050, T056–T058, T064 |
| FR-040–FR-047 | T070–T084, T086 |
| FR-050–FR-058 | T088, T091, T094–T097, T103, T107–T110 |
| FR-059 | T092, T093, T104–T106 |
| FR-060–FR-063 | T098–T101, T111–T116 |
| FR-064 | T088, T091–T102, T117 |
| FR-070, FR-071 | T002, T040, T043, T065, T067, T087, T119 |

## Implementation strategy

1. **Contract first.** T019 unblocks A, M and B2. Nothing in it sends a push.
2. **The goal bar and its replay before anything else in push** (T020, T021, T029). They're pure, they pin the design, and every number in them is already known.
3. **MVP of the day:** Lane B1 alone gives every push type to fans, on the app as it is.
4. **Deploy in the [quickstart's order](quickstart.md#deploy-order):** the push PR turns every type on, then the new app follows as soon as Lane M finishes.
5. **If the day runs late (§5.3):** cut Lane B2 first, since no fan sees it before D7, then the التشكيل tab (its flag stays off), then A16. The goal bar, off switch, timeline, frequency push, composer test send and A17's diff don't move.

---

## Before lanes start

- [x] T001 Owner: review and merge the constitution 1.4.0 amendment with its doc changes. Merged as [#44](https://github.com/AhmedSaied94/madar-sat/pull/44) on 2026-11-06.
- [ ] T002 Planning session, with the owner's merge: apply FR-071's corrections, then commit them with `specs/006-d06-notifications-and-live-center/` to `master` through a PR, so lane branches cut from `origin/master` have them. The same PR carries the doc edits made after #44, already in the working tree: D9's HTML pages, the later AdSense application, and the `ARM_RUNNER` notes.
  - `docs/product-business.md`: §11 gains the approved copy from the spec's Assumptions (channels with more than one, channels removed, own goal, shootout, correction); S3 gains FR-060's note.
  - `docs/system-design.md`: §6.7's goal bar becomes per goal ([R1](research.md#r1-the-goal-bar-judged-per-goal)); §6.8's key example becomes [R4](research.md#r4-dedupe-keys)'s keys, and it gains the first-channel exception and the `channel_<id>` and `announcement_<id>` tags. §6.8's `final_score` row says a finish at the limit sends nothing (FR-007).
  - `docs/delivery-plan.md`: D6's brief takes `0009` and `api_football`; D7, D8 and Appendix A's rows move per [R24](research.md#r24-boundaries-with-later-days).

---

## Lane B1

**Goal:** a follower gets each kind of alert they asked for, once, with the right copy. A goal one source may have got wrong doesn't go out. The admin API serves the log, composer, accounts and audit.

**Independent test:** with a fake sender, replay the 2026-11-04 capture through the producers: 58 goal messages, 0 corrections, and no false 2–0 for Mouloudia. Save a changed frequency through the admin API and see one history row and one message to that channel's followers ([quickstart B1](quickstart.md#lane-b1)).

### Contract: tests first (B1)

- [x] T003 [US1] In `backend/tests/db/test_0009_notifications_and_accounts.py`, test upgrade and downgrade on an empty database and on the snapshot fixture, per [data-model.md](data-model.md):
  - every new table and column exists;
  - `match_channel_changes` is unique on `(match_id, channel_id, action)`, and `action` is CHECK `added` or `removed`;
  - `channel_frequency_changes.outbox_id` is UNIQUE, with `ON DELETE SET NULL`, and `audit_log_id` has `ON DELETE SET NULL`;
  - `match_live_state.push_memory` is `NOT NULL DEFAULT '{}'`, and `admin_users.must_change_password` is `NOT NULL DEFAULT false`;
  - `ck_matches_locked_fields` allows `broadcasts`, `import_runs` status allows `stopped`, and `dataset_versions` holds `outbox` and `admin_users`;
  - the downgrade rewrites `stopped` runs to `failed`, strips `broadcasts` from every array, then restores each CHECK.
- [x] T004 [P] [US1] In `backend/tests/api/test_other_sports.py`, test FR-022 and SC-010: `GET /v1/matches` with no `sport` returns football only, `sport=basketball` returns basketball, `/v1/live` returns football only, and `poll_window_query` and the watchdog's selection never pick another sport.
- [x] T005 [P] [US1] Test the additive `/v1` changes per [public-api](contracts/public-api.md):
  - in `backend/tests/api/test_live_window.py`, `event_count` equals the rows `match_detail` serves, and is `0` on an estimated state;
  - in `backend/tests/api/test_discovery_details.py`, `recent_frequency_changes` is the last 5, newest first, in `FrequencyChange`'s shape, and a new row changes the `ETag`;
  - in `backend/tests/devices/test_update.py`, `prefs.enabled` is accepted and stored, an unknown key is still refused, a response has `enabled` and every type with SD §6.8's defaults (`match_started` off), a document with no `types` key still reads, and `enabled: false` keeps per-type values.
- [x] T006 [P] [US1] In `backend/tests/admin/test_notifications.py`, test [admin-api notifications](contracts/admin-api.md#notifications):
  - the log: filters, cursor, `recipients`, `target`, `is_test`, `is_correction`, `error`, `ETag` and `304`;
  - reach, by each `kind`;
  - announcements: title "1–65 characters", body "1–180", `find_card_sharing_label` refusing with `422 text_not_allowed`, `send_at` in the past refused with `422 send_at_in_past`, `target` built into a route and any route text refused, `404` for an unknown target or audience ID, audit row with `audit_log_id` set on the outbox row;
  - cancel: `If-Match` required, `409 notification_not_cancellable` on anything but a `pending` non-test `announcement`, `status = cancelled` and `error = admin`;
  - test send: `audience.kind = device`, `422 test_device_not_set`, `422 test_device_no_token`;
  - the test device: `GET` and `PUT` for the caller's own account only, `428` on `PUT` without `If-Match`, `409 edit_conflict` when stale, a login not making it stale, `404 device_not_found`, audited, and `admin_users` bumped;
  - roles: `editor` reads the log and gets `403` on everything else.
- [x] T007 [P] [US1] In `backend/tests/admin/test_users.py`, test [admin-api users](contracts/admin-api.md#users): list, create, `PATCH` with `If-Match`, reset; changing a role, which applies on that account's next request; `temporary_password` of at least 12 characters, returned once with `Cache-Control: no-store`, stored as argon2id; deactivate and reset revoke refresh tokens, and that account's next request is refused (SC-011); reactivating lets it log in again; `409 email_taken`, `409 cannot_change_self`, `409 last_admin`; `locked_for_s` from `auth:locked:<h>`; every route `admin` only. **Assert that no response, no `audit_log` row and, through `caplog` at `DEBUG`, no log line from these routes contains `password_hash` or the temporary password** (FR-025, SC-011), and that reset's diff is `{"password": "changed"}`.
- [x] T008 [P] [US1] Test the forced change per [admin-api](contracts/admin-api.md#password_change_required):
  - in `backend/tests/auth/test_change_password.py`, a flagged account gets `403 password_change_required` on every `require_role` route, while `auth/me`, `auth/refresh`, `auth/logout` and `auth/change-password` work; a change clears the flag, revokes the other refresh tokens and keeps this session; it writes one audit row `{"password": "changed"}` and bumps `admin_users`; `401 invalid_credentials`, `422 password_too_short` (under 12), `422 password_unchanged`; failures count through the login limiter; no response, audit row or `caplog` line holds either password or the hash;
  - in `backend/tests/auth/test_cli_admins.py`, `set-admin-password` clears the flag and `create-admin` doesn't set it;
  - in `backend/tests/auth/test_login.py`, the fifth failure also sets `auth:locked:<h>` with the lock's expiry, and `Session` carries `must_change_password`.
- [x] T009 [P] [US1] In `backend/tests/admin/test_audit.py`, test [admin-api audit](contracts/admin-api.md#audit): filters by `admin_user_id`, `source`, `entity`, `entity_id`, `from`, `to`; cursor; `actor.kind` of `admin`, `importer` and `system`; `diff` returned as stored for old shapes such as `{"password": "changed"}`; `notification` set only when an outbox row links to the entry; `admin` only; no write route exists. In `backend/tests/admin/test_channel_frequency_history.py`, test `GET channels/{id}/frequency-changes`: newest 100, `editor` allowed, `actor` from the row's `audit_log_id`, still named after its outbox row is pruned, and null for an importer.
- [x] T010 [P] [US1] Test the smaller changes:
  - in `backend/tests/admin/test_match_patch.py`, saving broadcaster slots adds `broadcasts` to `locked_fields`;
  - in `backend/tests/admin/test_dashboard.py`, other-sport matches aren't counted in "matches without channels" (FR-039);
  - in `backend/tests/admin/test_sources.py`, a `stopped` run serialises with its reason in `error`;
  - in `backend/tests/contract/test_admin_routes_have_roles.py` and `test_admin_contract.py`, every new route has a role, `auth/me` and `auth/change-password` carry `required_role == "editor"` though `EXEMPT_PREFIXES` skips `auth/`, and each new error code is documented;
  - in `backend/tests/admin/test_writer.py`, `add_audit` returns the row it added, and `save_update`'s `then` runs once with a flushed audit row before the bump, not at all when nothing changed, while `save_update` still returns `bool`.

### Contract: implementation (B1)

- [x] T011 [US1] Write `backend/alembic/versions/0009_notifications_and_accounts.py` (revises `0008`), expand-only, per [data-model.md](data-model.md), dropping and re-adding `ck_matches_locked_fields` and `ck_dataset_versions_name` as `0007` does. T003 passes.
- [x] T012 [US1] Add `ChannelFrequencyChange`, `MatchChannelChange` and the new columns to `backend/app/db/models.py`, and `broadcasts` to `MATCH_LOCKABLE` in `backend/app/domain/lockable.py`.
- [x] T013 [US1] Make the public changes: sport defaulting to football in `backend/app/api/public/matches.py`; `Match.sport == 'football'` in `live_window_query` and `event_count` in `backend/app/services/live.py`; `LiveState.event_count` and `NotificationPrefs.enabled` in `backend/app/schemas/public.py`; `recent_frequency_changes` in `backend/app/services/channels.py`. T004 and T005 pass.
- [x] T014 [US1] In `backend/app/auth/roles.py`, make `require_role` refuse a flagged account unless it's called with `allow_flagged=True`, and add `require_signed_in = require_role("editor", allow_flagged=True)`, which keeps the role check and `required_role` and skips only the flag. Move `me` to it in `backend/app/api/admin/auth.py`, and add `POST auth/change-password`. Add `must_change_password` to `AdminUser` and `Session` in `backend/app/schemas/admin.py`. Add an async twin of `revoke_refresh_tokens` in `backend/app/auth/admins.py`, clear the flag in `set-admin-password`, and set `auth:locked:<h>` in the Lua script in `backend/app/auth/limits.py`. T008 passes.
- [x] T015 [US1] In `backend/app/services/admin/writer.py`, make `add_audit` return its `AuditLog` and add `then` to `save_update`, keeping its `bool` return because `bulk.py:90` ORs it ([what the writer gives](contracts/push-pipeline.md#frequency-changes)). Add `backend/app/services/admin/notifications.py` and `backend/app/api/admin/notifications.py`, register the router in `backend/app/admin.py`, and add the schemas and examples to `backend/app/schemas/admin.py` and `admin_examples.py`. **This PR deploys before the dispatcher understands these rows, so `_CLAIM` in `backend/app/notifications/dispatcher.py` gains `AND type = 'kickoff_reminder'` until T032 removes it**, with a test in `backend/tests/notifications/test_dispatcher.py`. T006 and T010's writer tests pass.
- [x] T016 [P] [US1] Add `backend/app/services/admin/users.py` and `backend/app/api/admin/users.py`. Pass the explicit state `{email, name, role, is_active}` to `writer.py`, never `versions.row_state(row)`, which hashes every column ([R19](research.md#r19-admin-accounts)). T007 passes.
- [x] T017 [P] [US1] Add `backend/app/services/admin/audit.py` and `backend/app/api/admin/audit.py`, and the history route in `backend/app/api/admin/channels.py` with its read in `backend/app/services/admin/channels.py`. Add `outbox` and `admin_users` to the bumps that need them. T009 passes.
- [x] T018 [US1] In `backend/app/services/admin/matches.py` (:244-247, :306), add `broadcasts` when A4 saves slots, because slots aren't columns and `lock_changed_fields` misses them. Add `Match.sport == 'football'` in `backend/app/services/admin/dashboard.py` (:42-47). Add `stopped` to `ImportRunRow.status` in `backend/app/schemas/admin.py`. T010 passes.
- [x] T019 [US1] Run `uv run python -m app.cli export-openapi`, regenerate both clients unedited, run the `oasdiff` check and open the contract PR. **The owner reviews the migration and contract before merge.** Tell A, M and B2 when merged.

### Push: tests first (B1)

- [x] T020 [P] [US1] In `backend/tests/notifications/test_goal_bar.py`, write a table test of `evaluate` per [the goal bar](contracts/push-pipeline.md#the-goal-bar):
  - empty memory gives a baseline and no message; a manual hold moves the baseline, and asks for a correction first if accepted is below pushed;
  - 2 or more readings: second-highest, capped at accepted and floored at pushed. **Pushed 2–0 with readings 2–1 and 1–1 gives one away message carrying 2–1, never 1–1.** The capture has no such case, so T021 can't catch a missing floor;
  - one reading: nothing before 3 minutes, the lowest unbroken value after, and a break resets the hold;
  - one message per side, all carrying the bar's score;
  - accepted falling below pushed asks for a correction, with generation + 1, and a goal scored again gets a new key;
  - `penalties` does nothing, and `home_pen` and `away_pen` never count.
- [x] T021 [P] [US1] In `backend/tests/notifications/test_goal_bar_replay.py`, reuse `POLLS`, `TIMELINES`, the side builders, `_next_state` and `decide` from `backend/tests/live/test_replay.py`, calling `evaluate` after each poll and counting one message per side. Pin: **58 goal messages and 0 corrections**; `MOULOUDIA` gives only `1–0`, 240 s after the source first showed it; `PORTO_NAPOLI` gives 2–1, 3–1 and 4–1 separately, at +495 s, +580 s and +116 s. These numbers were measured on the rules in the contract. If they differ, the code or the contract is wrong, and they aren't to be updated to match.
- [x] T022 [P] [US1] In `backend/tests/notifications/test_policy.py`, test [lateness](contracts/push-pipeline.md#lateness-fr-019) per type on each side of each limit, with its `error` value; a test send never going late; the type defaults; and `PUSH_TYPES_OFF` parsing, where an unknown name is ignored and logged.
- [x] T023 [P] [US1] In `backend/tests/notifications/test_messages.py`, assert exact text, code point for code point, for every row of [the copy table](contracts/push-pipeline.md#copy) and [FCM fields](contracts/push-pipeline.md#fcm-fields): each name, digit, minute and readout isolated; a score never isolated as one string; Western digits; the scorer shown only when goal-type events on that side equal its score; own goal; shootout; channels added, several, and removed only; a channel with no satellite; route and tag per type.
- [x] T024 [P] [US1] In `backend/tests/notifications/test_producers.py` on PostgreSQL, with fake `Deps`, test through `_apply_match`:
  - `match_started`: feed status inside 15 min; none for clock, manual or after 15 min; an in-play first evaluation sets `live_seen` and sends nothing (FR-002, FR-003);
  - rows exist only if the poll committed; a retry, overlapping polls and a restart write nothing twice (SC-003);
  - `kick_dispatch` runs after commit, and only when a row was written;
  - **`evaluate` raising leaves the score saved, and the next poll sends the message (FR-008)**;
  - fans' values are the same with producers on as off;
  - manual status and locked score: no row, and the baseline moves;
  - correction: a row when a goal or final of this generation has `status = sent`, and none otherwise;
  - an editor's save through `matches.update`: lowering a live or finished score below pushed gives one correction with generation + 1, and the next poll gives none; raising it, or clearing a manual status, sends nothing; a match with no `match_live_state` row sends nothing (FR-009);
  - `final_score`: from the feed and from an editor's manual finish, including one over a finish at the limit; none from watchdog `_finish`, or from a later poll of that row; none for a clock-estimated finish, `abandoned`, `postponed` or `cancelled`; once only (FR-007).
- [x] T025 [P] [US1] In `backend/tests/notifications/test_channel_changes.py`, test [channel changes](contracts/push-pipeline.md#channel-changes), sync and async: inside the window one pending row, with its key and `match_followers`; 3 changes in two saves give one row; before the window only a first visible channel, as `match_only`; none with no known kickoff or in a final state; one per direction per channel per match; at dispatch the net against visible links, with hidden names, placeholders and deleted channels excluded; added then removed cancels with `no_net_change`; a retry sends the same message; `is_hidden` changes from A4 count; announced rows older than 30 days go with `prune_outbox`.
- [x] T026 [P] [US1] In `backend/tests/notifications/test_frequency_changes.py`, test [frequency changes](contracts/push-pipeline.md#frequency-changes): a `frequency_diff` table (complete to complete only; empty, filled, note-only `UHF 32` and a satellite move with the same tuning aren't changes; a move with new tuning is); A8's save shows the new value at once, with one pending row, keyed on the save's audit row, with `audit_log_id` set; creating a channel with a frequency produces nothing, and neither does a save that changes nothing; a typo fixed inside the hold sends the fixed value; set back cancels with `no_net_change`, with no history or badge, and A17 keeps both saves; a later change pushes again; a retry writes one history row, which keeps the outbox row's `audit_log_id`; the hold ending doesn't change the channel's version, so an open A8 isn't stale; the snapshot loader never produces one; `PUSH_TYPES_OFF` still writes history.
- [x] T027 [US1] Extend `backend/tests/notifications/test_dispatcher.py`, with existing reminder tests staying as they are apart from the master switch:
  - order: live types before an older `announcement`;
  - a row yields after its page budget, a goal goes in between, the cursor resumes with no device sent twice, and counts add up;
  - the run stops at its time limit and queues itself when work remains;
  - [audiences](contracts/push-pipeline.md#audiences) per `kind`: match and both teams give one message; a competition follow gets `channels_updated` and no goal; master off gives nothing of any type, including reminders; type off; no prefs gives the defaults; a correction reads `goal`; `device` ignores prefs; `all` needs no follow (SC-004);
  - `PUSH_TYPES_OFF` cancels with `type_off` and sends nothing; lateness cancels with its reason; a failed row keeps its reason, such as `FCM 503`, and never a token; dead tokens stay out of `failed`;
  - in `backend/tests/notifications/test_sender.py`, `last_error` and `PushRetryable.reason` per failure shape: with an HTTP status, with only a code, and a whole-call failure.
- [x] T028 [P] [US1] In `backend/tests/notifications/test_push_alerts.py`, test FR-029 and SC-014 with a fake sender refusing every send: one alert, sent after commit; no repeat; one on recovery; over 20 % with at least 10 devices opens it; 1 failure in 3 doesn't; dead tokens, test sends and cancelled rows never do.

### Push: implementation (B1)

- [x] T029 [US1] Write `backend/app/notifications/goal_bar.py`, pure. T020 and T021 pass.
- [x] T030 [P] [US1] Write `backend/app/notifications/policy.py`, pure, and add `PUSH_TYPES_OFF` to `backend/app/settings.py`. T022 passes.
- [x] T031 [P] [US1] Extend `backend/app/notifications/messages.py` with a builder per type, reusing `isolate`, `choose_channel` and `PushMessage`. T023 passes.
- [x] T032 [US1] Extend `backend/app/notifications/dispatcher.py` and `tasks.py`: the claim order, one row at a time with a budget of 20 pages, the 50 s loop and re-queue per [R8](research.md#r8-a-big-send-must-not-hold-a-goal); the three audience queries as fixed text; a builder per type; `PUSH_TYPES_OFF` then `policy.decide` before the first page; `error` written on cancel and on failure, with [the failure reason](contracts/push-pipeline.md#dispatch) added in `backend/app/notifications/sender.py`; and the T015 guard removed. T027 passes.
- [x] T033 [US1] Write `backend/app/notifications/producers.py`. Call it in `_apply_match` in `backend/app/live/cycle.py` after `apply_decision`, inside `session.begin_nested()`, and add `Deps.kick_dispatch`. In `update()` in `backend/app/services/admin/matches.py`, when `body.status` was sent, call it through `save_update`'s `then`, as [an editor's save](contracts/push-pipeline.md#corrections) says: a manual `finished` with a score gives `final_score`, and a score lowered below pushed gives the correction. `apply_status` stays as it is, and `backend/app/live/watchdog.py` doesn't change. Read and write `push_memory` on `match_live_state`. T024 passes.
- [x] T034 [US1] Write `backend/app/notifications/channel_changes.py`, sync and async, and call the async one from `reconcile_links` in `backend/app/services/admin/match_links.py`. Add the first-dispatch netting to `dispatcher.py`, and pruning to `prune_outbox`. T025 passes. **Tell B2 when merged, for T050.**
- [x] T035 [US1] Add `frequency_diff` and the hold to `producers.py`, and call it from `update()` in `backend/app/services/admin/channels.py` through `save_update`'s `then`, comparing with `before`. `_set_frequency` and `create()` stay as they are. Add the hold's end to `dispatcher.py`: compare, write history with the outbox row's `audit_log_id`, set `frequency_changed_at`, bump `writer.CHANNEL_CHANGED`, send. Add `frequency_changed_at` to `NOT_HASHED` in `backend/app/services/admin/versions.py`, following `MATCH_CLOCK_COLUMNS`. T026 passes.
- [x] T036 [US1] Add the `push` problem to `backend/app/live/problems.py` (`_OPENED`, `_CLOSED`), and call `sync_problems` when a row finishes in `dispatcher.py`. T028 passes.
- [x] T037 [US1] Open the push PR. **Merging it starts every automatic type for every follower, PWA users included** ([the deploy order](quickstart.md#deploy-order), FR-021), so nothing is set in `.env` first. **The owner reviews the three audience queries before merge,** and merges at a time they can watch the first pushes, with [the off switch](quickstart.md#deploy-order) to hand.

### Repair (B1)

- [x] T038 [P] [US1] In `backend/tests/services/test_match_repair.py`, test `repair-matches sport`, per [R23](research.md#r23-the-broadcast-lock-and-old-rows): with no input it lists rows with a `sporteventz` external ID labelled `football` and changes nothing; with a map on stdin it does the work and rolls back unless `--apply`; `--apply` sets only the mapped sports, writes an audit row per change, and leaves and reports rows not in the map; an ID in the map that isn't such a row refuses the whole run; a re-run changes nothing; no match is deleted (FR-033).
- [x] T039 [US1] Add `sport` to `backend/app/services/match_repair.py`, and its parser beside `merge` and `fill` in `backend/app/cli.py`, with an optional `map` argument that reads a file or `-` as `_read_pairs` does. Add [its commands](quickstart.md#on-the-host) to the repair section of `docs/runbooks/imports-and-sources.md`, using `worker-imports` as `merge` does. T038 passes.

### Ops and validation (B1)

- [x] T040 [US1] Update the runbooks, with every command matching the code:
  - `docs/runbooks/push-notifications.md`: all types, composer, holds, lateness, reading the log, and **the off switch within a minute** (FR-021);
  - `docs/runbooks/staff-accounts.md`: A16, temporary passwords, the CLI for the first admin only;
  - `docs/runbooks/source-alerts.md` and `on-call.md`: the push failure alert;
  - `docs/runbooks/load-testing.md`: the all-devices send;
  - `docs/runbooks/deploy-and-rollback.md`: D6's deploy order, and prefs during a rollback;
  - `docs/runbooks/database-migrations.md`: what `0009`'s downgrade rewrites;
  - `docs/runbooks/secrets.md`: `PUSH_TYPES_OFF` as a non-secret setting;
  - `docs/runbooks/README.md`: the setup order and "After setup" table.
- [ ] T041 [US1] Prove SC-002 and SC-008, **with the owner's approval of a window with no live match**, because it touches the production database and `FCM_DRY_RUN` stops every real push while it's on. Seed 50,000 devices with a `loadtest-` token prefix, send to `all` with a goal row arriving mid-send, then delete only that prefix and turn `FCM_DRY_RUN` off. Record the finish time (≤ 10 minutes), the goal's wait (≤ 60 s) and VPS-2's load in `docs/load-tests/`.
- [ ] T042 [US1] On the deployed hosts, walk [quickstart B1](quickstart.md#lane-b1)'s live points: `PUSH_TYPES_OFF` taking effect within a minute, a row showing as cancelled, and a frequency saved and set back within the hold on [the test channel](quickstart.md#the-test-channel), never a real one, writing nothing public.
- [x] T043 [US1] Add Lane B1's items to `docs/owner-actions.md` (D6 section and "Open now"), each with its task ID and runbook link, split into before and after merge: migration and contract review, the audience review, keeping the off switch to hand on the first match night, and the sporteventz row count and repair.

---

## Lane B2

**Goal:** other-sport events and their broadcasters are collected ready for D7, and API-Football fills gaps in fixtures without ever passing its daily allowance. Football fans notice nothing.

**Independent test:** from saved pages and responses, sporteventz produces other-sport matches and broadcaster entries, a re-run changes nothing, and football lists are untouched. API-Football stops at its budget in a simulated day, and does nothing without a key ([quickstart B2](quickstart.md#lane-b2)).

### Shared parts: tests first (B2)

- [x] T044 [P] [US4] In `backend/tests/adapters/test_upsert.py`, test per [importers](contracts/importers.md#changes-both-need): a record's `sport` is written and compared, and defaults to `football`; a football and a basketball row with the same names and date never merge, and `_may_be_a_near_row` doesn't match across sports; the no-resolve flag leaves IDs NULL and adds no `unresolved_names`; for `api_football`, the strict probe applies, an unresolved team raises `WaitForEditor`, and `_fields_are_frozen` protects another source's row. Every existing test passes unchanged.
- [x] T045 [P] [US4] Test [a run that stops on purpose](contracts/importers.md#a-run-that-stops-on-purpose): in `backend/tests/adapters/test_tasks.py`, a stop reason ends the run `stopped` with `error` set, and doesn't become `failed`; in `backend/tests/adapters/test_health.py`, it touches neither the breaker nor the zero-items alarm; in `backend/tests/adapters/test_report.py`, it fills its slot.
- [x] T046 [P] [US4] In `backend/tests/adapters/test_messages.py`, update the pin at :160 for a per-source `MAX_PAGES`, 8 for `sporteventz`. In `backend/tests/adapters/test_livesoccertv_plan.py`, test that `plan_targets` skips other sports (FR-039).

### Shared parts: implementation (B2)

- [x] T047 [US4] After B1's T019, rebase. Add `sport` to `ParsedFixture` and `normalize_fixture` in `backend/app/adapters/base.py`. In `backend/app/adapters/upsert.py`, write `sport` in `_apply` (:480-490), compare it in both merge paths (:386-413, :432-444), add the no-resolve flag (:181-199, :209, :213), and turn the checks on `self.source == "yallakora"` (:345, :510) into a set holding `yallakora` and `api_football`. T044 passes.
- [x] T048 [US4] Add the stop reason in `backend/app/adapters/tasks.py` (:386, :405), `backend/app/adapters/health.py` and `backend/app/adapters/report.py`. T045 passes.
- [x] T049 [US4] Make `MAX_PAGES` per source in `backend/app/adapters/messages.py`, and filter `plan_targets` in `backend/app/adapters/livesoccertv.py`. T046 passes.
- [x] T050 [US4] After B1's T034, write the tests first in `backend/tests/adapters/test_upsert.py` and `test_livesoccertv_links.py`: an added and a removed link each call `report_link_change` in the ingest's transaction, and a rolled-back ingest leaves no row. Then call [`report_link_change`](contracts/push-pipeline.md#the-call-importers-make) from `_apply` in `upsert.py` after `_reconcile_links`, and from `apply_broadcasts` in `backend/app/adapters/livesoccertv_links.py` (FR-038).
- [x] T051 [P] [US4] Add `PUSH_TYPES_OFF=`, `API_FOOTBALL_KEY=`, `API_FOOTBALL_DAILY_BUDGET=90` and `API_FOOTBALL_LEAGUES=233,39,2` to `infra/compose/example.env`, with placeholders only, and confirm `worker-notify` and `worker-scrape`, which fetches both sources, receive them through `env_file` in `infra/compose/vps2.yml`.

### sporteventz (B2)

- [x] T052 [US4] Save pages for basketball, handball, volleyball and tennis, plus the site's `robots.txt`, under `backend/tests/fixtures/sporteventz/<date>/`: each sport's page and its data response, with no personal data. Confirm which method the data URL takes (the old tool tries POST, then GET, at `../old_app/public/SPORTS.html:542`) and that a fixed `client_tz_offset` is honoured. **If the site blocks this or the shape differs from [R21](research.md#r21-sporteventz), stop and tell the owner.**
- [x] T053 [P] [US4] In `backend/tests/adapters/test_sporteventz.py`, on the saved pages, test `parse` as pure: every field per [importers](contracts/importers.md#sporteventz); other sports skipped and counted; a same-name pair skipped; `kickoff_at` in UTC from the sent offset, and `time_tbd` with no time; no logo; the channel ranking and both slots, with slot 2 cut at a whole name within 80 characters; a missing access key or `Records` key raising a format error; both paths allowed by the saved `robots.txt` through `urllib.robotparser`.
- [x] T054 [P] [US4] In `backend/tests/adapters/test_sporteventz_ingest.py`, following `test_yallakora_ingest.py`, test: two runs give one match per event with its sport and entries; `broadcasts` in `locked_fields` leaves entries untouched; a card-sharing name is refused and counted; `unresolved_names` doesn't grow; an expired key re-reads the page once; football lists are untouched; a valid empty response raises no alarm until 7 days after the last run with records.
- [x] T055 [US4] Write `backend/app/adapters/sporteventz.py` implementing `SourceAdapter`, recording the robots reading in its docstring as `yallakora.py:9` does. T053 passes.
- [x] T056 [US4] Write the broadcaster entries through the adapter's path into `match_custom_broadcasts`, skipping a match with `broadcasts` locked, and applying `find_card_sharing_label` from `backend/app/domain/content.py` and the 80-character limit. T054 passes, apart from the grace period.
- [x] T057 [US4] Register `sporteventz` in every place in [the table](contracts/importers.md#registering-a-source), with `www.sporteventz.com` at 1 request per 700 ms and a beat entry every 6 h for today to +3.
- [x] T058 [US4] Add the per-source zero-items grace to `backend/app/adapters/health.py`. T054 passes.

### API-Football (B2)

- [ ] T059 [US4] Owner: create the account, set `API_FOOTBALL_KEY` in VPS-2's `.env`, and make [the five checks](quickstart.md#before-lane-b2-builds-on-api-football). Its request saves the response, and once the key is confirmed absent, the file goes to `backend/tests/fixtures/api_football/` for T061. **If check 1 fails, close T060–T064 with the decision recorded and leave the key unset, or build the adapter off if the owner prefers.**
- [ ] T060 [P] [US4] In `backend/tests/adapters/test_budget.py`, test: each attempt counts before it's sent, including retries and «تشغيل الآن»; over the budget raises `BudgetReached` and sends nothing; a Redis error sends nothing; the key expires after 48 h and is dated by the provider's reset; a simulated day never passes the budget (SC-009).
- [ ] T061 [P] [US4] From a response saved in T059 under `backend/tests/fixtures/api_football/`, with no key in it, test in `backend/tests/adapters/test_api_football.py` and `test_api_football_ingest.py`: `parse` as pure; only allowlisted leagues reach the resolver; FT, AET and PEN skipped; logos ignored; a non-empty `errors` in a 200 fails the run with the provider's message; a match is created only when both teams and the competition resolve; an unmatched name queues and creates no team or competition; another source's fields stay untouched; with no key, `stopped`, `not_configured`, 0 requests and no alarm; over budget, `stopped`, `budget_reached`; Redis failing, `failed`, `budget_unreadable`; **the key appears in no log, raw page or `import_runs.log`**.
- [ ] T062 [US4] Write `backend/app/adapters/budget.py`, with its hook in `_request`'s loop in `backend/app/adapters/fetcher.py` (:149-151). T060 passes.
- [ ] T063 [US4] Write `backend/app/adapters/api_football.py`, with `SecretStr | None` and `require_*` settings in `backend/app/adapters/config.py`, and the header added at send time as `satair_bridge.py:80` does. T061 passes.
- [ ] T064 [US4] Register `api_football` in every place in [the table](contracts/importers.md#registering-a-source), with a beat entry twice a day for today to +3.

### Ops and validation (B2)

- [x] T065 [US4] Update `docs/runbooks/imports-and-sources.md` (both sources, the budget, `stopped` runs, re-checking robots), `docs/runbooks/source-alerts.md` (sporteventz's quiet days), `docs/runbooks/secrets.md` (`API_FOOTBALL_KEY`) and `docs/runbooks/on-call.md`, and keep `docs/runbooks/README.md` pointing to them.
- [ ] T066 [US4] Deploy and run `sporteventz` on the live host ([quickstart](quickstart.md#on-the-host)). Put the evidence in the PR: the `import_runs` row, other-sport matches with entries, 0 new teams, competitions or channels, `/v1/matches` still football only, and the A13 card. If T059 passed, do the same for `api_football`, and record that day's request count.
- [x] T067 [US4] Add Lane B2's items to `docs/owner-actions.md`: the account and five checks, the key, and sporteventz's terms, with the owner's option to drop the source.

**Lane B2 state (2026-11-07):** rebased onto B1's `#46` (T019 and T034). The whole lane is green: the `stopped` status, the `broadcasts` lock, and the link changes now written from `upsert._apply` and `apply_broadcasts`. T059–T064 and T066 wait on your API-Football checks (T059): its response fixture is what T061 and T063 are written from, so the adapter ships off and nothing a fan sees changes before D7.

---

## Lane A

**Goal:** the admin sees what was sent, sends an announcement, adds an editor without a server, and answers "who changed this frequency?" with a side-by-side diff.

**Independent test:** against the mock, then the real API on `wg0`, the log, composer, users and audit screens work end to end and match their boards. An editor is refused the admin-only parts by the server and doesn't see them in the UI ([quickstart A](quickstart.md#lane-a)).

### Setup (A)

- [x] T068 [US3] After B1's T019, rebase and run `pnpm orval`, committing any output. Add every new endpoint to `responseSchemas` in `admin/src/api/http.ts` (a request without one fails). Add the copy to `admin/src/i18n/ar.ts`, and [each new code](contracts/admin-api.md#new-error-codes) to `ErrorCode` and `errorCopy`.
- [x] T069 [US3] Read `madar-design/admin-react/SCREENS.md` and the boards under `madar-design/admin-react/screens/03-operations/` (`Notifications`, `Users`, `Audit`, `Sources`) and `02-content/Channels.html`, as PNG and HTML. None has empty, error or loading copy, and no board draws the change-password form, so those follow the shared patterns and A1.

### Tests first (A)

- [x] T070 [P] [US3] In `admin/src/app/App.test.tsx` and a new `admin/src/features/shell/navigation.test.tsx`, test [routes and roles](contracts/admin-screens.md#routes-and-roles): `/notifications`, `/users` and `/audit` render their screens rather than `ComingSoon`; an editor sees no A16 or A17 in the nav, and a direct address shows not-permitted (FR-047). Repoint `App.test.tsx:91-98` to a route still unbuilt.
- [x] T071 [P] [US3] In `admin/src/features/auth/ChangePasswordPage.test.tsx` and `admin/src/api/http.test.ts`, test [the forced step](contracts/admin-screens.md#change-password): `must_change_password` on login, or `403 password_change_required` on any request, leads to `/change-password` with nothing else rendered; a success returns to the app; `auth/refresh` and `auth/me` still work meanwhile; validation and each error code show Arabic copy.
- [x] T072 [P] [US3] In `admin/src/features/notifications/NotificationsPage.test.tsx`, test [the log](contracts/admin-screens.md#a15-the-log): every column; correction and test marks; each known reason in Arabic and an unknown one raw; filters kept in the URL; cursor paging; new rows through `refetchInterval`; empty, loading and error states; editor sees no composer.
- [x] T073 [P] [US3] In `admin/src/features/notifications/Composer.test.tsx`, test [the composer](contracts/admin-screens.md#composer): live counters at 65 and 180; match and channel pickers; each audience kind (FR-016), with a team's free text not enabling send; reach on audience change; a past time refused; previews updating as you type; all devices needing a confirmation showing the reach; the test send naming the saved device, asking for an ID when none is saved, sending `If-Match` when saving one, and reporting the true result; cancel with `If-Match`, and `ConflictDialog` on a conflict.
- [x] T074 [P] [US3] In `admin/src/features/users/UsersPage.test.tsx`, test [A16](contracts/admin-screens.md#a16-users): the three statuses including minutes left; create and reset showing the temporary password once with copy, **and leaving no trace in the query cache or DOM after close**; `cannot_change_self` and `last_admin` shown in the drawer; changing a role; reset and deactivate through `ConfirmDialog`; reactivating a deactivated account; `ConflictDialog` on `If-Match`.
- [x] T075 [P] [US3] In `admin/src/features/audit/AuditPage.test.tsx` and `admin/src/components/ConfirmDialog/DiffView.test.tsx`, test [A17](contracts/admin-screens.md#a17-audit): filters in the URL; `[old, new]` pairs side by side in `columns`, and `stacked` as `ConflictDialog` shows them, with `ConfirmDialog.test.tsx`'s and `MatchEditor.test.tsx`'s `conflict-diff` tests passing unchanged; `{"password": "changed"}` and any unknown shape shown raw without throwing; links to the entity and the push with its counts; no restore action.
- [x] T076 [P] [US3] In `admin/src/features/channels/ChannelsPage.test.tsx`, test [«سجل التردد»](contracts/admin-screens.md#a8-frequency-history) in edit mode only, with LTR readouts. In `admin/src/features/sources/SourcesPage.test.tsx`, test [`stopped` runs](contracts/admin-screens.md#a13-stopped-runs): both reasons in Arabic and a neutral tone.

### Implementation (A)

- [x] T077 [US3] Build the shared parts: the select and segmented control under `admin/src/components/FormControls/`, `DiffView` extracted from `ConflictDialog.tsx:81` into `admin/src/components/ConfirmDialog/DiffView.tsx` with `ConflictDialog` using it, a not-permitted state, and `HealthChip`'s disabled tone in `admin/src/components/StatusChip/StatusChip.tsx`. T075's `DiffView` tests pass.
- [x] T078 [US3] Register the routes in `admin/src/app/App.tsx` and hide items by role in `admin/src/features/shell/navigation.ts`. T070 passes.
- [x] T079 [US3] Add the `bindSession` handler in the `requestWithRetry` catch in `admin/src/api/http.ts` (:219, :231, :379-394), the flag in `admin/src/features/auth/session.ts`, the redirect in `SignedInShell` in `admin/src/app/App.tsx` (:24-41), and `admin/src/features/auth/ChangePasswordPage.tsx`. T071 passes.
- [x] T080 [US3] Build `admin/src/features/notifications/NotificationsPage.tsx` and `queries.ts`. T072 passes.
- [x] T081 [US3] Build `admin/src/features/notifications/Composer.tsx`, its previews and `MatchPicker.tsx`, and give `admin/src/features/matches/ChannelPicker.tsx` a single-select mode. Build the audience control per [the composer](contracts/admin-screens.md#composer), reusing `TeamPicker.tsx` and `useCompetitions()`. T073 passes.
- [x] T082 [P] [US3] Build `admin/src/features/users/` from `Users.html`, with the temporary password held in component state only. T074 passes.
- [x] T083 [P] [US3] Build `admin/src/features/audit/` from `Audit.html`. T075 passes.
- [x] T084 [US3] Add «سجل التردد» to `admin/src/features/channels/ChannelEditor.tsx` (between :488 and :490), and the stopped states to `admin/src/features/sources/SourcesPage.tsx`. T076 passes.

### Validation (A)

- [x] T085 [US3] From `admin/`, run `pnpm typecheck && pnpm lint && pnpm test && pnpm build && ./scripts/check-literals.sh && ./scripts/check-token-copy.sh && pnpm e2e`. Extend `admin/e2e/smoke.spec.ts` only if a new route breaks it.
- [ ] T086 [US3] Compare with the boards at 1440 and 1024 in both themes and attach the screenshots to the PR. Walk [quickstart A](quickstart.md#lane-a) over WireGuard after deploy.
- [x] T087 [US3] Add Lane A's items to `docs/owner-actions.md`, including the test send and saving a test device, and A16's and A17's use to `docs/runbooks/staff-accounts.md`. Record that A13 stays open to editors and that A2's «من N مباراة اليوم» is an existing bug, both for the owner to decide ([noted, not changed](contracts/admin-screens.md#noted-not-changed)).

**Status (opencode, 2026-11-07):** T068 and T070–T085 are done, and T087's docs are in. The lane was cut on `d06-a` and rebased on the spec branch once B1's T019 merged (#46), so the client, `must_change_password` and `stopped` are the generated ones. A15's cancel and its `ConflictDialog` are tested in `NotificationsPage.test.tsx`, beside the row they act on. `admin/` is green: `pnpm typecheck`, `pnpm lint`, `pnpm build`, both copy checks, 367 Vitest tests in 37 files and the 4 Playwright smoke tests. **T086 is open** — the screenshots attached to the PR and the WireGuard walk after B2's deploy, both in [owner-actions](../../docs/owner-actions.md#lane-a-notifications-users-audit). Its local half was run here: the five screens were rendered through Vite and Prism at 1440 and 1024 in both themes (20 captures) with no failing request, which caught a real bug — the composer's match picker asked for date-only bounds and the spec's `date-time` rule answers `422`; it now sends A3's Cairo-midnight instants eight days apart. One local note: `pnpm test` at this box's 12 workers loses a fork to memory pressure; `npx vitest run --maxWorkers=4` runs the same 367 tests green, and CI's 4-core runner is the smaller default.

---

## Lane M

**Goal:** a fan on S3 sees goals and cards as they happen, the score draws the eye when it changes, and lineups appear when the source has them. With no feed the screen says so honestly. In Settings, the fan chooses which alerts they get.

**Independent test:** with `live_center` on and a stubbed match, S3 shows the timeline and lineups as on the boards. With the flag off, or with no feed data, S3 looks as it does today. Changing a switch in S15 sends the new prefs to the server, and they survive a restart ([quickstart M](quickstart.md#lane-m)).

Run tests only with `RTEST_HOST=flutter-tests rtest`, never `flutter test` on the laptop. If the box is unreachable, tell the owner.

### Setup (M)

- [X] T088 [P] [US2] **Before any S3 code changes,** add `app/test/goldens/match_detail_flag_off_test.dart` through `goldenVariants`, using `app/test/fixtures/sample_match_detail.dart`, and generate its PNGs on the test box from today's page. S3 has no golden today, so SC-013 has nothing to compare with otherwise. These PNGs don't change in this lane.
- [X] T089 [US2] After B1's T019, rebase and run `dart run swagger_parser` and `dart run build_runner build -d`, committing the output. Read `madar-design/app-flutter/SCREENS.md`, `design-system/components/EventTimeline/README.md`, and the boards `screens/03-match-detail/Match-Live.html`, `Match-Lineups.html`, `screens/06-more-settings-rights/Settings.html` and `screens/05-follow-and-search/FollowSheet.html`.
- [X] T090 [US2] Add the strings to `app/lib/core/l10n/app_ar.arb` and run `flutter gen-l10n`, using the boards' copy, the PB §14 glossary and the approved note in FR-060: «هدف», «عكسي», «ركلة جزاء», «ركلة جزاء ضائعة», «بطاقة حمراء», «بداية المباراة», «الشوط الثاني», «الأحداث», «التشكيل», «بدون نتيجة», «عرض», and S15's rows. The extra-time marker reuses the existing `extraTime` string, «إضافي».

### Tests first (M)

- [X] T091 [P] [US2] In `app/test/core/config/remote_config_test.dart`, test [`features`](contracts/app-screens.md#flags): bundled `live_center: false` and `lineups: false`; JSON parsed per flag; bad JSON or a wrong type keeps the bundle.
- [X] T092 [P] [US2] In `app/test/features/notifications/push_routes_test.dart`, test `parsePushRoute`: accepts exactly `/`, `/match/5`, `/match/5?section=channels`, `/channel/5`; refuses `/match/5/x`, `/match/abc`, `/match/5?section=x`, `/channel/`, `/evil`, `//host`, `https://x` and an empty string. Test that `/channel/5` opens S6 with S1 under it, and an unknown route opens the app and goes nowhere.
- [X] T093 [P] [US2] In `app/test/core/platform/push_service_test.dart`, change the test at :177 so a foreground message emits no route. In `app/test/features/notifications/foreground_banner_test.dart`, test that the banner shows title and body, only «عرض» navigates, and dismissing doesn't. In `app/test/web/messaging_sw_routes_test.dart`, read `web/firebase-messaging-sw.js`, extract its route pattern between marker comments, and check it agrees with `parsePushRoute` on T092's table.
- [X] T094 [P] [US2] In `app/test/features/match_detail/timeline_test.dart`, test `buildTimeline`: newest first while live and chronological once finished; each event label; markers from the minute, with `45+2` staying in its half; a running score only when goal-type events equal the score, so 2–0 with one known goal shows none and invents no row; no player shows type and minute only; own goal on the credited side.
- [X] T095 [P] [US2] In `app/test/features/match_detail/lineup_layout_test.dart`, test the pitch rule: 11 starters, exactly 1 goalkeeper and all four FilGoal groups give a pitch per side; anything else, including every Goal.com lineup with a null `position`, gives two lists; an empty formation shows no label; marks only on an exact name match.
- [X] T096 [US2] In `app/test/features/match_detail/live_center_test.dart`, test each row of [the states table](contracts/app-screens.md#s3-the-live-center): flag off and no data show nothing and no empty frame; tabs only with `lineups` on and data; estimated shows only the note, though `detailWithLiveState` keeps events; offline shows cached events with their age and nothing live; red card uses `error` with an icon; each row has an Arabic screen-reader label.
- [X] T097 [US2] In `app/test/features/match_detail/match_hero_test.dart` and `match_detail_page_test.dart`, test the flash once on a rise, and none on first paint, on a fall or under reduced motion. Test one re-read when `score`, `status` or `event_count` changes, none on a null live state, with the 60 s timer kept (SC-006). Test `?section=channels` scrolling once to the channels, including when the sliver isn't built yet, and «أين تشاهد» staying reachable with the flag on (SC-013).
- [X] T098 [P] [US2] In `app/test/features/match_detail/follow_action_test.dart`, test FR-060's two notes: in-play and not `estimated` gives the alerts note; otherwise today's note.
- [X] T099 [P] [US2] In `app/test/features/settings/settings_screen_test.dart` and a new `app/test/features/devices/device_sync_test.dart`, test [S15's group](contracts/app-screens.md#s15-the-notification-group): every row with its default, `match_started` off; master off dims the types and keeps their values; each [platform state](contracts/app-screens.md#platform-state); «التذكير الافتراضي» absent; a change made offline reaches the server on reconnect and survives a restart; nothing syncs before onboarding ends.
- [X] T100 [P] [US2] In `app/test/features/devices/device_repository_test.dart` and `settings_screen_test.dart`, test [the device ID](contracts/app-screens.md#s15-device-id): captured from `PUT`'s response, cleared by `forget()`, one sync forced when it's missing on an existing install, the row hidden until known, with a copy action.
- [X] T101 [P] [US2] In `app/test/features/frequencies/frequencies_test.dart`, test `ChangedBadge` on S5.2 within 30 days and not after, and that S3's `CarriageRow` never shows it (FR-061).
- [X] T102 [US2] Add `app/test/goldens/event_timeline_test.dart`, `live_center_test.dart`, `lineups_test.dart` and `settings_notifications_test.dart` through `goldenVariants` (RTL, both themes, 1.0× and 1.3×), with the flags on (FR-064). Generate their PNGs on the test box once T109 and T115 are in.

### Implementation (M)

- [X] T103 [US2] Add `features` to `app/lib/core/config/remote_config.dart` (constructor, bundled values, `fromRaw`) and `remote_config_repository.dart` (`setDefaults`, key list), with `liveCenterEnabledProvider` and `lineupsEnabledProvider`. T091 passes.
- [X] T104 [US2] Write `app/lib/core/platform/push_routes.dart`, and use it in `push_service.dart` (:199) and `app/lib/features/notifications/presentation/push_route_listener.dart` (:28-36). T092 passes.
- [X] T105 [US2] Stop `onMessage` navigating in `app/lib/core/platform/push_service.dart`, and write `app/lib/features/notifications/presentation/foreground_banner.dart` from the `Banner` component. T093's banner tests pass.
- [X] T106 [US2] In `app/web/firebase-messaging-sw.js` (:35-49), validate `data.route` with the marked pattern and fall back to `openWindow` if `client.navigate` rejects. T093 passes. The fallback can't be tested here, so it joins T118's PWA walk.
- [X] T107 [P] [US2] Write `app/lib/features/match_detail/domain/timeline.dart` and `lineup_layout.dart`, pure. T094 and T095 pass.
- [X] T108 [P] [US2] Build `EventTimelineItem(event:)` in `app/lib/design/components/event_timeline_item.dart`, following `EventTimeline`'s README: the minute on the spine in mono and LTR, `accent-container` tiles, `error` for red cards, `text-tertiary` for misses.
- [X] T109 [US2] Build `app/lib/features/match_detail/presentation/live_center/` per [the contract](contracts/app-screens.md#s3-the-live-center): the sliver builder of rows, the tabs, the pitch, the two lists and the estimated note, in focused sub-widgets. T096 passes.
- [X] T110 [US2] Wire it in `match_detail_page.dart` after `MatchHero` (:260-288), with `ref.listen` on the live state (:143) and a one-shot `ensureVisible` on a key at the toolbar in `where_to_watch_slivers.dart` (:84). Add `ScoreFlash` around `StatusBlock` in `match_hero.dart` (:93), using `.big-sc.flash`'s 1.2 s and `MediaQuery.maybeDisableAnimationsOf`. T097 and T088 pass.
- [X] T111 [US2] Pass the status and live state into `app/lib/features/match_detail/presentation/match_follow_button.dart` (:35), and pick the note. T098 passes.
- [X] T112 [US2] Add the badge parameter to `app/lib/design/components/carriage_row.dart`, passed only from `app/lib/features/frequencies/presentation/channel_list.dart` (:63). T101 passes.
- [X] T113 [US2] Add `permission()` and a `PushPermission` enum to `PushMessaging` in `app/lib/core/platform/push_service.dart`, updating every fake under `app/test/`. The enum leaves room for the amendment's no-Google-Play state, which isn't built here.
- [X] T114 [US2] Add the prefs key to `SettingsKeys` and `AppSettingsValue` in `app/lib/core/db/app_database.dart` (:85). Send prefs in `_sendDevice` in `app/lib/features/devices/data/device_sync.dart` (:181), and compare them in its listener (:52-66).
- [X] T115 [US2] Build `app/lib/features/settings/presentation/notification_settings.dart`, placed before satellites in `settings_page.dart`, with `installGuideProvider.needsInstallSteps` and `/install` for an iPhone browser. T099 passes.
- [X] T116 [US2] Keep `device_id` from `PUT` in `app/lib/features/devices/data/device_repository.dart` (:37, :49), clear it in `forget()`, and add the row after the version in `settings_page.dart` (:234), with copy as `channel_sheet.dart` (:73) does. T100 passes.

### Validation (M)

- [X] T117 [US2] From `app/`, run `flutter analyze`, `./tool/check_literals.sh`, `./tool/check_token_copy.sh` and `RTEST_HOST=flutter-tests rtest`, with T102's goldens generated on the box.
  - Last run on the merged contract: `flutter analyze` clean (on the test box), both check scripts pass, 974 tests pass with 1 skipped. Regenerating the client from B1's spec gives no diff.
- [ ] T118 [US2] Compare S3 live, lineups and S15 with their PNGs in both themes, and hand the owner [quickstart M](quickstart.md#lane-m)'s steps: S3 and every push on an Android phone and an installed iPhone PWA, including a push tapped with the PWA open in a background tab (T106's fallback).
  - The comparison with the PNGs is done for S3 live, lineups and S15. The device walk is the owner's, in `docs/owner-actions.md`.
- [X] T119 [US2] Update `docs/runbooks/remote-config.md` (both flags, the Android tester condition from [R15](research.md#r15-feature-flags-and-on-for-testers), and turning them on for everyone) and `docs/runbooks/pwa-release.md` if needed. Add Lane M's items to `docs/owner-actions.md`: the next `app-v*` and `web-v*` tags, the Remote Config values, and the device walk.

---

## Done check

Copied word for word from delivery-plan Appendix A, row 006:

> A goal push arrives with the correct score; the live center shows events; a frequency change pushes to followers; the admin composer sends a test push; audit diff visible

Replay alone doesn't pass it.

**Preconditions (owner):**

- the FCM key on VPS-2, with `FCM_DRY_RUN` off;
- the new PWA and Android test build out ([deploy order](quickstart.md#deploy-order));
- `live_center` on for testers in Remote Config;
- 031's open owner items closed, with the poller deployed and a real match on the day's fixtures. Keep the off switch to hand for the first match night.

**Checks:**

- [ ] DC1 A goal push arrives with the correct score, on Android and an installed iPhone PWA during a real followed match, compared with the broadcast (SC-001, SC-012).
- [ ] DC2 The live center shows events on that match, within 60 s with no navigation (SC-006). Note whether a long timeline leaves «أين تشاهد» too far down (plan Risks).
- [ ] DC3 A frequency change pushes to followers: on [the test channel](quickstart.md#the-test-channel), whose reach must equal only your own devices, through A8, after the hold (SC-005). Setting it back afterwards is a second change and pushes again, to your devices only. Delete the channel afterwards.
- [ ] DC4 The admin composer sends a test push to the saved device, and no other device gets it (SC-007): Lane A T086 with Lane M T116.
- [ ] DC5 Audit diff visible: the frequency save in A17, with its push's counts.
- [ ] DC6 All types read correctly on both platforms, with names, readouts and scores in the right order (SC-012).
- [ ] DC7 Each lane's owner items are in `docs/owner-actions.md`, and every changed operated part has its runbook (FR-070, FR-071).
