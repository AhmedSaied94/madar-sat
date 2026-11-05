# Implementation review: 031-d05-live-sources, lane B2, round 1

- Date: 2026-11-05 · Reviewer: Claude Code, Opus 5.5, with two Sonnet review agents whose findings were re-checked here
- Branch: d05-b2 · Base: 7c1d1b7 (merge base 7c1d1b7) · Head: 7c1d1b7, plus 9 uncommitted files
- Change: 0 commits, 9 files (0 in another lane's folders), +172 −36
- Verdict: APPROVE WITH NOTES · CRITICAL 0 · HIGH 0 · MEDIUM 3 · LOW 4

The review script labels `backend/tests/adapters/` as B1's. T030, T031 and `backend/CLAUDE.md` give those tests to B2, so that isn't a finding.

## Checks

Run from `backend/` unless noted, with `TEST_DATABASE_URL` and `TEST_REDIS_URL` pointed at the dev stack.

| Check | Command | Result |
| --- | --- | --- |
| Lint | `uv run ruff check .` | Exit 0 |
| Types | `uv run mypy --strict app` | Exit 0 |
| Tests and coverage | `uv run pytest -p no:cacheprovider --tb=line -q --no-header --cov --cov-branch --cov-report=term` | Exit 1: 1900 passed in the progress lines, 4 failed. Total 94%, against a bar of 70. All 4 are in `tests/adapters/test_homebox_acl.py` (see [Outside this change](#outside-this-change)) |
| The same tests at the base | `uv run pytest tests/adapters/test_homebox_acl.py` in clean `madar_sat/backend` at 7c1d1b7 | Exit 1: the same 4 fail, with `AuthenticationError` |
| Format (not in CI) | `uv run ruff format --check .` | Exit 1, only on `tests/live/test_crosscheck.py:611`, which this lane didn't change |
| Compose (from the repo root) | `docker compose -f infra/compose/{vps1,vps2}.yml --env-file infra/compose/example.env config -q`, with `IMAGE_TAG=test` | Exit 0 for both |
| Settings reach the workers | The same, with `--profile '*' config --format json` | `worker-live` and `worker-maintenance` each hold the 7 `LIVE_*` values in `example.env`. Both take `env_file: ${MADAR_ENV_FILE:-/srv/madar/.env}` (`vps2.yml:15`), so any other `LIVE_*` in `.env` reaches them too |
| Runbook literals (from the repo root) | `infra/scripts/check-doc-commands.sh` | Exit 0 |
| The rest of `infra.yml` | Its other steps, `shellcheck`, `actionlint` | NOT RUN: no script, unit, Caddyfile or workflow changed |
| Secrets | `gitleaks` | NOT RUN: not installed here. CI runs it |

**Ways around the checks.** None: no skip, no new suppression, no config change, and no test removed.

## Findings

### CRITICAL

None.

### HIGH

None.

### MEDIUM

#### B2-R1-1: A dropped connection now trips the poller's host backoff

- Layer: pipelines · Source: spec 005 `contracts/live-pipeline.md:20` ("A 429, 403 or 5xx sets `live:backoff:<host>`"), `docs/runbooks/live-poller.md`'s `down:` row · Location: `backend/app/adapters/fetcher.py:185-186`; B1's `backend/app/live/cycle.py:228-232`, `:288-292` · CONFIRMED by reading
- Problem: T031 asks for `FetchError` or `Retryable`, so `Retryable` is allowed. But the poller treats every `Retryable` as the host refusing us: it trips the backoff and, on a page, gives up the remaining pages. Before this change `httpx.ReadError` and `RemoteProtocolError` counted one failure and went on to the next page.
- Failure scenario: the first capture saw one `IncompleteRead` in 125 fetches. Reading up to 9 pages a minute from FilGoal, about one cycle in fourteen would lose its remaining pages and may skip its next list read, for a blip that isn't a refusal.
- Fix direction: raise a `DroppedConnection(Retryable)` subclass here, and have B1's `_read_list` and `_read_pages` catch it first and count a failure with no backoff. Importers keep their retries. This needs one line from each lane. Otherwise, decide to keep this behaviour and correct the contract and the runbook.

#### B2-R1-2: An importer's last attempt on a dropped connection changed, and the runbook wasn't updated

- Layer: pipelines, ops · Source: root `CLAUDE.md`, Runbooks · Location: `backend/app/adapters/tasks.py:226-247`, `docs/runbooks/imports-and-sources.md:108` · CONFIRMED by reading
- Problem: these two errors used to reach the `httpx.TransportError` branch: `error = transport_error`, then a re-raise, so Celery recorded a failure. They now reach `Retryable`: `error = retries_exhausted`, then a normal return. The retries are the same and a `failed` run row is still written. But the runbook still says `retries_exhausted` means "403/429/5xx after six attempts", and no test covers `fetch` on this path.
- Fix direction: fixing B2-R1-1 with a subclass doesn't change this by itself, so either handle the subclass in the `transport_error` branch or update the runbook, and add one test for the last attempt.

#### B2-R1-3: T033 is ticked with its host check still open, and "Open now" doesn't show it

- Layer: spec, ops · Source: root `CLAUDE.md`, Owner actions ("Keep the 'Open now' table current") · Location: `specs/031-d05-live-sources/tasks.md` T033; `docs/owner-actions.md:20`, `:660-674` · CONFIRMED by reading
- Problem: T033 asks to check that `/srv/raw` is writable, Redis is reachable and the Telegram and user-agent settings are present. The SSH user can't read `.env` or reach Docker, so those are an owner item with exact commands, and the task's own line says so. Nothing is hidden, which keeps this at MEDIUM. But this lane didn't touch row 031 of "Open now", so an owner reading the table won't see a check that must pass before T026.
- Fix direction: add **Lane B2:** T033's host check to row 031's "After merge" cell. B1 edits the same cell, so whichever lane merges second keeps both.

### LOW

#### B2-R1-4: The fetcher's docstring promises more than it does

- Layer: pipelines · Source: T031 · Location: `backend/app/adapters/fetcher.py:10`, `:36-38` · CONFIRMED by reading
- Problem: it says "never a raw error", and `httpx.ConnectError`, `WriteError` and timeouts stay raw, the timeouts on purpose (`test_a_timeout_stays_an_httpx_error_for_the_callers_that_read_it`). The `http.client` entries can't come from httpx's real transport, only from the tests' mock. T031 names `IncompleteRead`, so keeping them is fine.
- Failure scenario: a reader trusts the docstring and drops an `httpx.HTTPError` handler.
- Fix direction: name the two errors it does convert.

#### B2-R1-5: `infra/README.md` says all values are in `example.env`, and five aren't

- Layer: ops · Source: T032 · Location: `infra/README.md:90`, `:100`, `infra/compose/example.env:81-96`, `.github/workflows/infra.yml:149-152` · CONFIRMED by a grep
- Problem: the new README row lists 12 settings under "the values are in `compose/example.env`". `LIVE_PAGE_CAP_FILGOAL`, `LIVE_PAGE_CAP_YALLAKORA`, `LIVE_DOWN_AFTER_FAILURES`, `LIVE_STALE_AFTER_S` and `LIVE_HARD_LIMIT_MIN` aren't there. T032 only asked for seven, so this is the README's wording. No CI step checks that the live settings stay passed through, only `RAW_ROOT`.
- Failure scenario: someone looks up a default in `example.env` and doesn't find it.
- Fix direction: add the five, since each is optional and shows its default.

#### B2-R1-6: The bucket test restates the page cap as a literal

- Layer: tests · Source: T030 · Location: `backend/tests/adapters/test_ratelimit.py` (`test_goal_com_has_its_own_bucket_sized_for_a_poll_with_room_for_retries`) · CONFIRMED by reading
- Problem: `assert 60 / bucket.refill_seconds >= 2 * (1 + 4)` hard-codes `LIVE_PAGE_CAP_GOAL`.
- Failure scenario: T028 raises the cap, and the test still passes.
- Fix direction: read the default from `app.live.config`, or accept it with a comment.

#### B2-R1-7: The disk estimate doesn't match that night's saved files

- Layer: ops · Source: T033 · Location: `docs/runbooks/live-poller.md:125` · CONFIRMED by listing `~/madar-capture/2026-11-04/`
- Problem: it credits "the page sizes on 2026-11-04". The saved files' medians are about 18 KB for YallaKora (claimed 20), 5 KB for Goal.com (claimed 30) and 3 KB for FilGoal (claimed 60). I didn't check whether those files hold whole pages, so the estimate may be right for whole pages. Either way it errs high, which is the safe direction. "37 GB free" isn't recorded anywhere else, and T033's owner commands don't re-read it.
- Failure scenario: none harmful: the capture's disk need is overstated.
- Fix direction: T028 replaces it with measured sizes. Add `df -h /srv/raw` to T033's commands.

## Requirements

| Requirement | Built in | Proven by | Status |
| --- | --- | --- | --- |
| FR-015, FR-021: Goal.com's rate limit, the other hosts' rate, its own bucket | `backend/app/adapters/ratelimit.py:37-46` | `test_goal_com_has_its_own_bucket_sized_for_a_poll_with_room_for_retries`, `test_goal_com_shares_no_bucket_with_the_other_hosts` | Met for the poller. See [Outside this change](#outside-this-change) for the capture |
| FR-015: the host only by its allowlist | `backend/app/adapters/fetcher.py:218-224` (unchanged) | `test_goal_com_is_fetched_by_its_allowlist_and_nothing_else_opens_it` | Met |
| T031, T021's dependency: a dropped connection isn't raw | `backend/app/adapters/fetcher.py:36-38`, `:185-186` | `test_a_dropped_connection_comes_out_as_retryable_not_raw`, `test_a_connection_dropped_before_any_answer_comes_out_as_retryable` | Met, see B2-R1-1 |
| FR-021: new settings reach the live worker and the watchdog | `infra/compose/example.env`, `infra/README.md`, `vps2.yml:15` | The Compose render above. No CI guard (B2-R1-5) | Met |
| FR-021: a way to run the capture on VPS-2 | The command in `docs/runbooks/live-poller.md`, `vps2.yml` | Rendered. The host half is open (T033) | Partly met: B2-R1-3 |
| FR-028: this lane's folders only | | 0 files in another lane's folders | Met |
| US4.1, US4.2, SC-007: the capture from a datacenter | B1's capture, this lane's plumbing | Needs a deploy: T026 | Not yet |

## Task audit

Ticked 5, verified 4, not done 0, partly done 1.

| Task | State | Why |
| --- | --- | --- |
| T033 | Partly done | Only what can be seen from outside the host is checked. The rest is the owner's, as the task says (B2-R1-3) |

T032's "any `check_env` step must pass with them unset" has nothing to act on, because no such step exists.

## Owner must review

None: no API contract, Alembic migration, auth or permissions code, push audience query or UI screen.

## Outside this change

- `tests/adapters/test_homebox_acl.py`: 4 tests fail on the local Redis with `AuthenticationError`, the same at 7c1d1b7 in clean `madar_sat`. It's this lane's file, and CI must settle it.
- `tests/live/test_crosscheck.py:611` fails `ruff format --check`. CI doesn't run that, and B1 rewrites the file.
- **Merge this lane first, or with B1.** Until `GOAL_BUCKET` is in, `RateLimiter.take` lets Goal.com through unlimited. That's B1-R1-15 in `reviews/b1-round-1.md`, which is on B1's branch until it merges.
- `GOAL_BUCKET` is sized for the poller, as T030 asks. The capture adds up to 13 requests a minute on the same bucket, and `--page-cap`'s default and the runbook are B1's, so that's B1-R1-6.
- FilGoal's bucket (capacity 2, one token per 4 s), with the poller's 2 s wait, gives it the list and about 2 pages a cycle, not the 9 its cap allows. It's worth measuring in T028, and B1's file has it too.
- `fetcher.py` includes the query string in neighbouring messages such as `answered 403`, unlike the new line and `ResponseTooLarge`.

## Not reviewed

- Anything on VPS-2, including T033's host commands and T026, which need a deploy.
- `gitleaks`, `shellcheck`, `actionlint` and the other `infra.yml` steps, as in Checks. A reviewer read the diff for secrets and found none.
- B1 and B2 merged together: only `docs/` was trial-merged, with 0 conflicts. Each lane's tests ran on its own tree.
