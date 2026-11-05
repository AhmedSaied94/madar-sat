# Quickstart: D5 follow-up · Live sources

## Before anything runs

- `d05-b1` and `d05-b2` include the merged spec 005 code.
- `~/madar-capture/2026-11-04/` is on the owner's laptop. B1 trims its fixtures from it.
- No Goal.com list page was saved, so B1 saves one first (T005).

## B1: replay and tests

```bash
cd backend
uv run ruff check . && uv run mypy --strict app && uv run pytest tests/live
uv run pytest tests/live/test_replay.py -v
```

`test_replay.py` feeds [replay-timelines-2026-11-04.json](replay-timelines-2026-11-04.json) through `decide`. It expects:

| Check | Expected |
|---|---|
| A new score after the first source | ≤ 60 s |
| Scores shown backward | 0 |
| Final scores | 11 of 11 right |
| Disagreement alerts | ≤ 1, on Porto v Napoli if any |
| Mouloudia Alger | Ends on 1–0 |
| FilGoal's live readings showing a minute | At least 95% (SC-004), measured at 98.2%, with no wrapped minute shown |
| Goal.com setting off | Same result, 0 requests |
| Matches finished by full time | 14 of 16, 10 by a second source, with the [assumption about list rows](research.md#r13-the-final-rules-replayed) stated in the test |
| Bristol City v Wolves | Finished at kickoff + 150 on 1–2, using its peak minute, with one `stuck:` alert |
| A late kickoff, with a peak minute below 90 at + 150 | Not finished until the peak reaches 90 or kickoff + 210 |
| A lone source's full time, then extra time from another | Stays open |
| A row with an unknown status | A higher score counts, a lower one doesn't, and the status doesn't move |

## B1 and B2: capture from VPS-2

Run on a night with live matches, starting before the first kickoff:

```bash
ssh madar-vps2
cd /srv/madar
docker compose -f infra/compose/vps2.yml run --rm worker-live \
  python -m app.cli capture-live --minutes 240
```

The exact file path and service follow `docs/runbooks/live-poller.md`, which T023 updates from B2's T033.

**Expected:** gzipped list and match pages for all three sources under `/srv/raw/capture/<date>/`. Telegram gets one message when the capture starts, naming its expected end, and one when it ends. A source failing 5 rounds in a row or going quiet sends one alert. If the capture stops early, `live.watchdog` sends one alert within about 7 minutes.

**If a source blocks VPS-2:** that's a result. Don't get around it. Stop using it and tell the owner, with the report.

Then commit a trimmed set of its pages as fixtures (T027), and write `capture-report.md` (T028).

## B1: a real match

On the deployed hosts, with all three sources, on a match later than the capture's:

```bash
curl -s https://<api-host>/v1/live | jq '.data[] | select(.match_id == <id>)'
```

| Moment | Check |
|---|---|
| Kickoff | Status moves to live, not `estimated` |
| Each minute | The minute matches the broadcast within 2 minutes |
| A goal | Time on the broadcast, first source, acceptance and arrival in the app are recorded |
| Half-time and second half | Statuses move, and don't go backward |
| Full time | Finished, with the right score, when a second source agrees or within about 15 minutes. Record how long it took |

## Setting Goal.com off

```bash
# on VPS-2, in /srv/madar/.env
LIVE_GOAL_ENABLED=false
```

Then restart `worker-live` as `docs/runbooks/live-poller.md` says. The next cycle sends Goal.com no request, and the other sources carry on.
