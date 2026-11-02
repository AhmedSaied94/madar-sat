# Implementation review: 003-d03-follow-push-sources, lane B1, round 2

- Date: 2026-11-01 · Reviewer: Claude Code (Opus 5.5 lead; Sonnet python-reviewer subagent; every CRITICAL/HIGH re-read by the lead)
- Branch: 003-d03-follow-push-sources (all four lanes' round-1 fixes merged; no lane branch checked out, as in round 1) · Base: master (merge base 5323669) · Head: 5cd804f, plus 0 uncommitted files
- Change: 31 commits, 485 files in all (98 lane B1, 354 in other lanes' folders, reviewed in their own round files), +54040 −957. Round-1 fix commit: c216820
- Verdict: **CHANGES REQUESTED** · CRITICAL 0 · HIGH 2 · MEDIUM 3 new (plus 17 open from round 1) · LOW 5 new (plus 15 open from round 1)

## Checks
| Check | Command | Result |
| --- | --- | --- |
| ruff | `cd backend && uv run ruff check .` | exit 0, "All checks passed!" |
| mypy | `MYPYPATH=$PWD uv run mypy --strict --explicit-package-bases app` | exit 0, 143 files, no issues (the plain form fails on this machine, as in round 1: environment) |
| pytest + coverage | `TEST_DATABASE_URL=postgresql://madar:changeme@localhost:5434/postgres TEST_REDIS_URL=redis://:changeme@localhost:6380/0 uv run pytest --cov -q` | exit 1: only the 4 `tests/adapters/test_homebox_acl.py` tests fail (D2's; need CI's ACL Redis, environment, same as round 1). Coverage 95.10 % (gate 70 %): `sender.py` 84 %, `tasks.py` 94 %, `dispatcher.py` 99 %, `devices/follows.py` 76 % |
| Contract in sync, migrations 0005/0006 up/down | inside the pytest run (`test_committed_contract_matches_app`, `tests/db/test_migrations.py`) | passed |
| Ways around the checks (diff of c216820) | `git show c216820 \| grep` for skip/xfail/noqa/type: ignore | one new `# noqa: BLE001` at `sender.py:105` on a per-message encode guard (LOW N9: dead code); no skip, no xfail, no config change; the one removed assertion (`test_messages.py:88`, the clamp) was replaced |
| `export-openapi` diff, client regeneration | — | NOT RUN: rewrites tracked files; `public.json` gained only `minLength: 1`, which swagger_parser and Orval do not turn into a client change |

## Previous round
| Finding | Now |
| --- | --- |
| B1-R1-1 empty push token (CRITICAL) | fixed: `schemas/public.py:457,464-474`, `dispatcher.py:103`, `sender.py:98-102,131-134`, `dispatcher.py:319-321`; each has a test that fails if reverted |
| B1-R1-2 INVALID_ARGUMENT wipes tokens | fixed: `sender.py:142-156`, `settings.py:68-73`, tests in `test_sender.py`, `test_settings.py` |
| B1-R1-3 cancelled row never revived | fixed: `scheduler.py:42-47`; revival tests (postponed→rescheduled, TBD→timed, >24 h and back). Residual stale state is MEDIUM B1-R2-4 |
| B1-R1-4 exhausted retries never `failed` | fixed for whole-call failures: revision 0006 `attempts`, `dispatcher.py:311-317`, tests. Residuals: MEDIUM B1-R2-3, B1-R2-5 |
| B1-R1-5 late reminder "in 1 minute" | fixed: `dispatcher.py:34,202-214`, `scheduler.py:52-63`, `messages.py:104-107`, tests |
| B1-R1-6 real FCM path untested | fixed for coverage, but the tests pin per-message `UnavailableError` as `failed`, not "retried" as the task asked: that gap is B1-R2-1 |
| Round-1 MEDIUMs | 17 still open (see the subagent list in the round-1 numbering): `GET /sources` 304 hides `running`; `resume` queues a manual run; no-op reorder bumps datasets; 500 on odd input (`FollowSet` unbounded lists, NUL in `app_version`/`locale`); cache TTL reset on hit; attacker-controlled cache key space; per-IP limit bypassed by minting devices; audit rows without the source; dashboard duplicate groups; weak satellite-precedence test; no end-to-end SC-002 test; placeholder exclusion unproven; no cross-URL cache test; `register` check-then-insert race; rollback to D2 exposes placeholders; `push-notifications.md:32` still uses `scp -J ubuntu@…` against the host-alias rule. "Transient per-message FCM errors never retried" is regraded to HIGH as B1-R2-1 |
| Round-1 LOWs | T014 tick fixed; the other 15 still open (`follows.py:40` `dict.fromkeys(_KINDS, [])` shared list, dead `_check_tz` and scheduler helpers, no `no-store` on 401/422/429, commentator TTL keys, partial 429 in OpenAPI, …) |

## Findings
### CRITICAL
None.

### HIGH
#### B1-R2-1: A transient per-message FCM failure is never retried, and the row ends `sent`
- Layer pipelines · Source spec edge case "A reminder fails for some tokens … other errors are retried within the bounded count" (spec.md:152), FR-007 "retries other failures with bounded backoff", constitution VII, round-1 task B1-R1-6 ("…assert … retried") · Location `backend/app/notifications/sender.py:118-127`, `backend/app/notifications/dispatcher.py:262-283` · CONFIRMED
- Problem: `send_page` counts every per-message error that is not UNREGISTERED as `failed`; `dispatch_row` records the page and sets the row `sent`. firebase-admin's `send_each` reports transport errors (503 `UnavailableError`, `InternalError`, 429 `QuotaExceeded`, timeouts) per message, not as a raised exception, so the `Retryable` / `attempts` path only ever sees encoding or credential errors.
- Failure scenario: FCM answers 503 for a minute at 19:45 → every device of every row dispatched in that minute is `failed`, each row is `sent`, the scheduler never revives a `sent` row → no follower gets the 20:00 kickoff reminder; the only trace is ERROR lines.
- Fix direction: have `send_page` return the tokens whose error is retryable (unavailable, internal, quota) apart from `failed`; re-send just those within a small bounded backoff, or raise `Retryable` for the page before recording it so the cursor/`attempts` path applies (a resent device is collapsed by the `match_<id>` tag, R7). Never mark a row `sent` while retryable devices remain inside the attempt budget.

#### B1-R2-2: The two contract additions lane A needs have no owner in lane B1
- Layer api · Source spec US4 scenarios 3–5, FR-031, `contracts/admin-api.md` "Ordering" and "Channels", lane A's open tasks A-R1-1 and A-R1-5 (which say "ask Lane B1"), delivery-plan §4 (only B1 changes the contract) · Location `backend/app/schemas/admin.py:494-518` (`AdminCompetition`, `AdminSatellite`: no `etag`), `:619-633` (`ChannelPatch`: no `kind`), `backend/app/services/admin/channels.py:127-131` · CONFIRMED
- Problem: lane A cannot finish A-R1-1 (a stale reorder is overwritten silently, `admin/src/features/competitions/CompetitionsPage.tsx:40-46` reads each row's version at save time) or A-R1-5 (a platform placeholder cannot become a satellite channel) without these fields, and no task in lane B1's section asks for them.
- Failure scenario: editor B reorders competitions; editor A, on a stale list, drags a row → A's save reads B's fresh versions, the PUT passes, B's order is gone with no conflict shown. An editor completing an importer placeholder as a satellite channel cannot.
- Fix direction: add `etag` (the row version, as `AdminMatchRow.etag` already does) to the competition and satellite list rows, and `kind` (platform → satellite, with the existing `kind_errors` rules) to `ChannelPatch`; additive change, re-export `openapi/admin.json`, regenerate both clients, then tell lane A.

### MEDIUM
- **B1-R2-3 The five attempts are spent in about 15 s.** `tasks.py:72-74` autoretries `dispatch_due` with 1–8 s backoff and every retry bumps the same row's `attempts` (`dispatcher.py:311`); `failed` is final. A whole-call outage longer than ~15 s permanently fails a row that still had ~14 min to send; `attempts` also never resets when the cursor advances. Count attempts per beat (or delay `due_at` by a backoff on release) and reset on progress.
- **B1-R2-4 A revived row keeps its old cursor and counters.** `scheduler.py:42-47` resets `status`, `due_at`, `payload`, `claimed_at` only. A >500-follower row cancelled mid-send and revived resumes at `cursor_device_id`, so devices at or below it never get the new-time reminder. Reset `cursor_device_id`, `attempts`, `sent`, `failed`, `sent_at` on revival of a cancelled row; test with a non-zero cursor.
- **B1-R2-5 A non-`Retryable` error strands claimed rows in `sending` and is never counted.** `dispatcher.py:305-323` catches only `Retryable`; a missing or unreadable `fcm.json` (`sender.py:61-65`, the first-deploy state before T047) raises something else, so rows sit in `sending` until reclaim, loop, and end `cancelled` at kickoff, never `failed`. Catch `Exception` per row, count the attempt, release the rest.

### LOW
- N5: the task-level `mark_failed` (`tasks.py:75`) is unreachable in production (the row counter reaches 5 first).
- N6: the 0006 CHECK `ck_notification_outbox_attempts` is not asserted by a test.
- N7: stale docs: `data-model.md:66` (a cancelled row is never changed), the lifecycle diagram and R6/R7 lack revival/`attempts`; `backend/CLAUDE.md:100` lists "0001 to 0005" as never edited, omitting 0006.
- N8: `fcm_message_failed` logs one ERROR line per device (500 lines for a failed page).
- N9: the `try/except` + `# noqa: BLE001` at `sender.py:103-107` is dead: `Message(fid="")` builds and only the encoder raises, which `_is_usable` already prevents.

## Requirements
| Requirement | Built in | Proven by | Status |
| --- | --- | --- | --- |
| AS1 register, rotate, hash only | `devices/service.py`, `tokens.py` | `devices/test_register.py` | Built (race MEDIUM, open) |
| AS2 device auth | `devices/auth.py` | `devices/test_auth.py` | Built |
| AS3 update, token moves | `devices/service.py:update`, `schemas/public.py:457-474` | `devices/test_update.py` | Built; empty token now refused |
| AS4 atomic follow replace | `devices/follows.py` | `devices/test_follows.py` | Built |
| AS5 one row per match, one send | `scheduler.py`, `dispatcher.py` | `test_scheduler.py`, `test_dispatcher.py` | Built; end-to-end SC-002 test still missing (MEDIUM) |
| AS6 claim, DISTINCT audience, ≤ 500, UNREGISTERED cleanup, retry | `dispatcher.py`, `sender.py` | `test_dispatcher.py`, `test_sender.py` | **Partial: per-message transient failures not retried (B1-R2-1)** |
| AS7 kickoff moves / TBD / postponed / cancelled | `scheduler.py` | `test_scheduler.py` | Built; stale cursor on revival (B1-R2-4) |
| AS8 cache, AS9 429 | `api/cache.py`, `api/ratelimit.py` | `test_cache.py`, `test_ratelimit.py` | Built |
| US4 contract for A6/A7 reorder and A8 placeholder (B1 half) | — | — | **Missing (B1-R2-2)** |

## Task audit
Ticked 6 round-1 tasks, verified 6 (B1-R1-6's "retried" assertion was replaced by "failed": tracked as B1-R2-1). Original tasks: no new mismatches.

## Owner must review
- `backend/alembic/versions/0006_outbox_attempts.py`: expand-only `attempts NOT NULL DEFAULT 0` + CHECK; downgrade drops both.
- `backend/app/notifications/dispatcher.py:95-130,286-330`: the audience query (now `btrim(push_token) <> ''`), claim, release and failed paths.
- `backend/app/notifications/scheduler.py:40-63`: the revival of cancelled rows (who gets a second chance at a reminder).
- `backend/openapi/public.json`: `DeviceUpdate.push_token` gains `minLength: 1`.

## Outside this change
- The 4 `test_homebox_acl.py` failures need CI's ACL Redis (D2, environment).

## Not reviewed
- Real FCM behaviour (dry-run against Google), the Orval/swagger_parser regeneration diff, a deployed host.
