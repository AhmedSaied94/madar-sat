# Implementation Plan: D5 · Live and discovery

**Branch**: `005-d05-live-and-discovery` (lanes: `d05-b1`, `d05-b2`, `d05-a`, `d05-m`) | **Date**: 2026-11-04 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `specs/005-d05-live-and-discovery/spec.md`

## Summary

Real live scores replace the clock estimate, and a fan can open a channel, a team and a competition.

- **B1** captures real live matches from FilGoal and YallaKora, then builds `backend/app/live/`: a 60 s scheduler, a poller with a pure cross-check, a watchdog, and one alert per problem. It also ships revision `0007`, the contract, and the load-test re-run.
- **B2** adds the `yallakora` importer, the alias step in the resolver and the unresolved-names queue writer, and starts `worker-live`. It builds the Caddy `/v1/live` cache only if the resize doesn't fix the load test.
- **A** adds the A13 queue, completes run detail with the raw page, adds the Live poller card, and builds A9.
- **M** replaces the three stub routes with S6, S7 and S8.

The approach is in [research.md](research.md) (R1–R19). The key choices:

- list pages for every linked match, with a capped set of match pages;
- cross-check state in PostgreSQL, so that it survives restarts and a clock fallback;
- a watchdog on another queue, so a dead poller can't leave a stale score showing as live;
- links only on both teams and the kickoff, and aliases scoped by competition, because several teams share a name;
- raw pages reach the admin over Redis, with no new port.

## Technical Context

**Language/Version**: As D1–D4. Python 3.13, TypeScript 5 (strict) on Node 22 LTS, Dart 3.13 / Flutter 3.47.7, Bash, Docker Compose v2.

**Primary Dependencies**: D4's, with none added. Parsing uses the existing `lxml` and the JSON standard library. `pg_trgm` is already installed. Caddy `cache-handler` only if FR-062 applies.

**Storage**: PostgreSQL 16, revision `0007` ([data-model.md](data-model.md)); `0008` only if the capture justifies stats. Redis for locks, rate buckets and short-lived raw views. `/srv/raw` on VPS-2 for pages, including `capture/`. App: the existing drift `CachedDocuments`, with no drift schema change.

**Testing**:

- **Backend:** pytest on PostgreSQL 16. Parsers run on captured pages. Table-driven `crosscheck.decide` tests cover every SD §6.7 row. Integration tests cover the cycle, fallback, recovery, the watchdog, manual status and `locked_fields`. Schemathesis covers the new routes.
- **Admin:** Vitest with MSW, Playwright against Prism.
- **App:** `flutter_test` through `rtest`, with goldens.
- **Manual:** one real match, the load re-run, device checks.

**Target Platform**: VPS-2 (`worker-live`, `maintenance`, `imports`), VPS-1 (API, Postgres, Redis, Caddy), the admin over `wg0`, Android and the PWA.

**Project Type**: The D1 monorepo: web service, admin SPA, Flutter mobile and web app, infrastructure as code.

**Performance Goals**:

- a confirmed score reaches a client ≤ 45 s after confirmation;
- a poll cycle finishes inside 60 s;
- `/v1/live` at 170 requests/s and `/v1/matches` at 50 requests/s, p95 < 150 ms cached and < 400 ms uncached, < 1 % errors (FR-061);
- S6, S7 and S8 show cached content first.

**Constraints**:

- $0/month: no paid feed, and any VPS-1 resize must be inside the confirmed Always Free limit;
- never request a `robots.txt` path, no disguise and no proxies, facts only;
- no push from the poller on D5;
- `live_center` off;
- `/v1` compatible with `app-v0.3.0` and `web-v0.1.0`.

**Scale/Scope**: Up to about 30 matches at once. 8 + 2 match pages per minute to start with. One day across four lanes, plus the load-test carry-over.

## Constitution Check

Checked against constitution **1.3.0**, which this plan amended first: "live score → client ≤ 45 s" now counts from confirmation (spec Clarifications), `SourceAdapter` applies to fixture importers, and a match already on `feed` is polled up to kickoff + 210 min. The Sync Impact Report goes in the PR.

| Gate | Before research | After design |
|---|---|---|
| I. Answer ≤ 2 taps, My satellites and free first, no ads before the answer | Pass: S6's frequency shows with no tap, carriages keep the order | Pass ([app-screens](contracts/app-screens.md)) |
| II. No guesses, honest status | Pass: a cross-check, fallback and no guessed links | Pass: the watchdog also covers a dead poller ([R6](research.md#r6-falling-back-staying-honest-and-the-watchdog)); suggestions never apply themselves ([R9](research.md#r9-suggestions-use-trigrams-and-never-cross-scripts)) |
| III. RTL, LTR islands, Western digits | Pass | Pass |
| IV. Tokens and components | Pass | Pass, with a recorded difference from the A13 board's sample suggestion for Latin names (R9) |
| V. Server-side trust | Pass: the admin stays on `wg0`, no new secrets beyond an optional Kuma URL | Pass: raw pages are inert text, and the path is never taken from the request ([R13](research.md#r13-run-detail-reads-raw-pages-over-redis)) |
| VI. Contract-first | Pass | Pass: additive; `If-Match`, audit and version bumps on all admin writes |
| VII. Idempotent, observable | Pass under the 1.3.0 wording | Pass: readers keep pure parsers, limits, backoff, a zero-items alarm and run records |
| VIII. Lean clients, budgets | Pass: SWR on existing drift | Pass |
| IX. $0, arm64, Compose + Caddy | Pass: the resize is conditional on the free limit | Pass |

## Project Structure

### Documentation (this feature)

```text
specs/005-d05-live-and-discovery/
├── plan.md
├── research.md
├── data-model.md
├── quickstart.md
├── capture-report.md          # B1 writes it (FR-001)
├── contracts/
│   ├── live-pipeline.md
│   ├── public-api.md
│   ├── admin-api.md
│   └── app-screens.md
└── tasks.md                   # /speckit-tasks
```

### Source Code (repository root)

```text
backend/
├── alembic/versions/0007_live_and_aliases.py       # B1
├── app/live/                                       # B1, new
│   ├── sources/{filgoal,yallakora}.py              #   pure parsers
│   ├── crosscheck.py  links.py  pick.py  apply.py  #   rules and writes
│   ├── problems.py  robots.py  capture.py
│   └── tasks.py  schedule.py
├── app/api/admin/{unresolved_names,rights_holders}.py   # B1, new
├── app/api/admin/sources.py                        # B1, raw page, live card
├── app/services/admin/{unresolved_names,rights_holders,versions}.py  # B1
├── app/services/{channels,catalog,match_detail}.py # B1
├── app/schemas/{public,admin}.py  openapi/*.json   # B1
├── app/adapters/{yallakora,unresolved}.py          # B2, new
├── app/adapters/{resolve,ratelimit,tasks,schedule,config,upsert,livesoccertv_links}.py  # B2
└── tests/{live,adapters,admin,contract}/  tests/live/fixtures/  tests/fixtures/yallakora/
infra/compose/vps2.yml  infra/scripts/deploy.sh     # B2
admin/src/features/{unresolved,rights,sources}/     # A
app/lib/features/{channel,team,competition}/  app/lib/core/router/  # M
docs/runbooks/live-poller.md (new), on-call.md, imports-and-sources.md,
  source-alerts.md, workers.md, load-testing.md, provision-host.md, README.md   # the lane that changes each
docs/owner-actions.md                               # each lane on finishing
```

**Structure Decision**: The D1 monorepo stays. The only new top-level package is `app/live/`, because B2 owns `app/adapters/` and the brief gives the poller to B1 (FR-051).

### Order of work and hand-offs

1. **Before lanes start (planning, owner):** commit the O7 edits, constitution 1.3.0 and this spec to `master`. Owner: check the OCI limits and resize VPS-1.
2. **B1, morning:** `0007` and the contract PR (by 13:00). A and M generate from it, and B2 rebases.
3. **B2, morning:** merge the shared signatures in [live-pipeline](contracts/live-pipeline.md#shared-code-b2-owns) to `master` as stubs, then buckets and `worker-live` with its raw mount. B1 rebases on them.
4. **B1, before the first suitable match:** `capture-live`, its deny list and B2's buckets are merged and deployed. Then capture and report. Parsers follow it, and tests run on replay until the next match.
5. **B1:** the load re-run after the resize. **B2:** the Caddy cache only if needed.
6. **A later match:** the real-match done check, on the deployed parsers. If no later kickoff fits today, it moves to the next match day and no other lane is held.

### Risks to watch

- **One match can't be both capture and done check.** Evening European fixtures are the likely window, so the parsers finish late. The capture takes an early kickoff and the done check a later one; with no later kickoff, the done check moves to the next match day. Pure rules, the contract and other lanes don't wait.
- **Few names link on the first day.** FilGoal's and our spellings may differ, so affected matches stay honest on the clock. The capture's names go through the queue early, and the owner clears them before the done-check match.
- **Delivery-plan's revision numbers are stale** for D5 (`0003`) and D6 (`0004`). The owner may want them corrected with the O7 edits.

## Complexity Tracking

| Violation | Why Needed | Simpler Alternative Rejected Because |
|-----------|------------|-------------------------------------|
| `0008` may follow `0007` (spec FR-015: one revision) | Stats storage can't be designed before the capture, and the contract must merge first ([R16](research.md#r16-match-stats-wait-for-the-capture)) | Adding an unused table contradicts FR-018 |
| LiveSoccerTV keeps hidden placeholder channels (spec FR-022: no entity created) | They hold links that would otherwise be lost, and are already hidden from `/v1` ([R11](research.md#r11-livesoccertvs-placeholders-stay)) | Removing them on D5 would change D3's matching in a day with no time to re-verify it |
