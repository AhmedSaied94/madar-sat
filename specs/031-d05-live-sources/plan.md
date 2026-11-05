# Implementation Plan: D5 follow-up · Live sources

**Planning docs**: PR #39 (lanes: `d05-b1`, `d05-b2`) | **Date**: 2026-11-05 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `specs/031-d05-live-sources/spec.md`

## Summary

Spec 005's poller is sound in structure, but it was built before anyone saw a live page. Replaying the 2026-11-04 capture through it shows YallaKora stopping itself at the first live row, FilGoal's minute being empty, and the "both must agree" rule delaying goals by up to 7 minutes. This plan keeps the cycle, watchdog, linking and storage, and:

- fixes the parsers;
- rewrites `decide` for any number of sources, with the owner's rule: a rise or a later status goes out at once, and a drop waits 5 minutes;
- holds a lone source's full time for 10 minutes, or until a second source agrees, so a cup match isn't closed before extra time;
- counts a higher score on a row with an unknown status, so goals keep coming when a source uses wording nobody has seen;
- finishes a stuck match at kickoff + 150 min, keeping its score, unless a source's highest minute is below 90;
- adds Goal.com as an equal third source and the only stats source, behind a setting that's on by default;
- proves it from VPS-2 and on a real match.

The evidence and choices are in [research.md](research.md), and the rules in [contracts/live-rules.md](contracts/live-rules.md).

## Technical Context

**Language/Version**: Python 3.13, as spec 005. Bash and Docker Compose v2 for B2.

**Primary Dependencies**: None added. `lxml` and the JSON standard library parse pages.

**Storage**: PostgreSQL 16, one expand-only revision `0008` ([data-model.md](data-model.md)). `/srv/raw/capture/` on VPS-2.

**Testing**: pytest on PostgreSQL 16. Table tests for `decide`, a replay test on the committed timelines, parser tests on captured live pages, then a capture and a watched match.

**Target Platform**: VPS-2 (`worker-live`, `maintenance`), VPS-1 (API, Postgres, Redis).

**Project Type**: The D1 monorepo. Backend and infrastructure only.

**Performance Goals**:

- a new score accepted in the first poll that shows it;
- an accepted score reaches a client ≤ 45 s later, as in spec 005;
- a finished status follows the first full time by about 2 minutes where a second source has it, and 10–15 minutes where one source holds it alone ([R13](research.md#r13-the-final-rules-replayed));
- a poll cycle finishes inside 60 s with Goal.com's 5 s responses, which come last and stop at the existing 50 s deadline.

**Constraints**: $0/month, no disguise and no proxies, facts only, `robots.txt` respected, no push from the poller, `live_center` off, `/v1` unchanged.

**Scale/Scope**: Up to about 30 matches at once. Pages a minute: 3 lists, plus 8 FilGoal, 2 YallaKora and 4 Goal.com at most, until the capture checks them.

## Constitution Check

*Checked before research and again after design.*

| Principle | Check | Result |
|---|---|---|
| I. The Answer First | No screen changes | Pass |
| II. Honest Data | Scores now reach fans before a second source. A false goal can show for minutes, and the owner accepted that. It's real source data, not a guess, and it's never `estimated`. A score on an unknown-status row is real source data too, and its status is never guessed. A frozen minute never looks current: the match shows no minute when no reading gives one. A dead worker goes to the clock up to kickoff + 150. Four cases still present an inference or an old value as current | **Four exceptions, in [Complexity Tracking](#complexity-tracking)**, each decided by the owner |
| III–IV. Arabic, tokens | Arabic alert copy only. No UI | Pass |
| V. Trust on the Server | No new endpoint. Goal.com's facts stay server-side and go through the same validation. Stats aren't served | Pass |
| VI. Contract-First | `/v1` and the admin contract don't change, and oasdiff must stay clean | Pass |
| VII. Pipelines | The reader is pure and tested on saved pages. It uses per-host buckets (B2), backoff, a zero-items alarm and `import_runs`. The window rule is kept: a match finished by the limit leaves it sooner, inside the + 210 min bound, and a match held for full time is still polled | Pass |
| VIII. Lean Clients | The 45 s budget still counts from acceptance, now about the first source | Pass |
| IX. Zero Cost | No paid service. Up to 5 more requests a minute, and raw pages stay within the 5-day prune | Pass |
| Quality gates | Tests first in every task, and runbook and owner-actions updated in the same change | Pass |

**Legal note (SD §13 R1):** Goal.com's terms forbid scraping and commercial use without consent. The owner reports approval dated 2026-11-05, covering everything planned here with no conditions. Its text isn't in the repo, so the plan records it as reported and keeps an off switch.

**Principle II has four recorded exceptions**, in [Complexity Tracking](#complexity-tracking). There are no other violations.

## Project Structure

### Documentation (this feature)

```text
specs/031-d05-live-sources/
├── spec.md
├── plan.md
├── research.md
├── data-model.md
├── quickstart.md
├── replay-timelines-2026-11-04.json
├── contracts/live-rules.md
├── capture-report.md            # written by T028
└── tasks.md
```

### Source Code

```text
backend/
├── alembic/versions/0008_live_sources.py      # new
├── app/db/models.py                           # new columns, MatchStats
├── app/services/match_detail.py               # one events source; no candidate filter
├── app/cli.py                                 # capture-live options
├── app/live/
│   ├── config.py, types.py, problems.py       # settings, sources, stats, new alerts
│   ├── crosscheck.py                          # the new rules
│   ├── apply.py, cycle.py, watchdog.py        # any number of sources, stuck matches
│   ├── capture.py, robots.py, robots/goal.txt # three sources, alert on failure
│   └── sources/filgoal.py, yallakora.py, goal.py
├── app/adapters/ratelimit.py                  # Lane B2: Goal.com's bucket
└── tests/live/                                # new tests, fixtures, test_replay.py

infra/compose/example.env                      # Lane B2: the new settings
docs/runbooks/live-poller.md, on-call.md       # Lanes B1 and B2
```

**Structure decision:** extend `backend/app/live/`, with a small source table in `cycle.py` in place of a new abstraction. Only `app/adapters/ratelimit.py` and `infra/` need B2.

## Order of work

1. **Docs and spec** reach the lanes.
2. **B2 adds the bucket and settings.** B1's Goal.com reader needs the bucket to fetch, but its parsers don't.
3. **B1, parsers and rules first.** They're pure and can be tested on today's data at once.
4. **B1, revision and apply.** `decide` depends on the new state.
5. **B1, capture tool**, then deploy, then the capture on the next match night.
6. **Fixtures and report** complete the parsers. The rules change here if the capture says so.
7. **A watched match** closes it, later than the capture's.

## Risks

| Risk | Answer |
|---|---|
| A live list row parses wrongly: no list page was saved | Parsers get real live rows from the capture before the watched match. An unknown status only drops its row |
| VPS-2 is blocked | The capture reports it. It stops work on that source, and the owner decides (SD O7 fallback) |
| Goal.com's page format or terms change | One setting switches it off. A format failure stops only this source |
| The rise rule shows a false goal | Accepted by the owner. The drop rule corrects it, and D6's bar protects pushes |
| One evening's evidence misleads | Spec FR-025 changes the rule with the report |
| A cup match behaves differently: the capture has no extra time or penalties | Full time waits under FR-008, and an unknown status still carries goals under FR-001. A person can correct a wrong finish. The first capture that includes a cup match checks both |
| The finish results rest on an inference about list rows ([R13](research.md#r13-the-final-rules-replayed)) | The next capture saves list pages. `test_replay.py` states the assumption, and FR-025 applies if it's wrong |

## Complexity Tracking

Each row is an exception to constitution Principle II, which forbids presenting a guess or a stale copy as fact. The owner accepted all four on 2026-11-05.

| Violation | Why Needed | Simpler Alternative Rejected Because |
|---|---|---|
| **A clock-based finish stored as real.** A match finished by the limit (FR-009) stays `feed`, with its score and no `estimated`, though no source said full time | Sources leave finished matches open: Bristol City v Wolves stayed live for about 45 minutes after the end, and YallaKora never closed one match. The owner gets an alert each time and can correct it | The clock fallback is compliant, but it wipes the final score and shows no score for a match that had one. Leaving the match live until a person acts needs an operator during matches, which SD §6.7 rules out |
| **Live after a lone full time.** A match can stay `live` for about 15 minutes after one source says full time, even when it's the only source covering the match (FR-008) | Polling ends at finished and only a person can undo it, so closing a cup match before extra time would lose its goals and shoot-out for good. It shows no minute while it waits | Finishing on the first full time is compliant, but the capture has no extra time at all, so nothing shows that it's safe |
| **An old stage during unknown statuses.** When every source shows a status nobody has seen, the match keeps its last stage, and a score on those rows stops it going stale (FR-001) | The first cup night will probably meet this, because no source's extra-time wording has been seen. It shows no minute meanwhile, and + 210 bounds it | Dropping those rows is compliant, but fans would lose the score through extra time and the shoot-out until a parser is fixed |
| **An old score past + 150.** With a dead worker, a paused poller or every source down, a second-half match keeps its last score and stays `feed` until the stuck step or the + 210 limit finishes it (FR-010) | The match is almost certainly over, so its last score is very likely the final one | The clock fallback is compliant, but it wipes that score for good if the sources don't come back |
