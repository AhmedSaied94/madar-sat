# ysscores day pages (saved responses)

Three `POST https://www.ysscores.com/ar/match_date_to` responses, saved on 2026-10-30 for Lane
B2's parser tests (T052, research R16). `parse` is pure and must pass against these files, so the
tests never touch the network (FR-021).

Saved with the request the site needs — a browser user agent and the `X-Requested-With` header.
Without them the endpoint answers `403`: ysscores blocks plain clients and datacenter IPs, which is
why the scrape worker runs on the owner's home box (research R21).

```sh
curl -s -X POST 'https://www.ysscores.com/ar/match_date_to' \
  -H 'X-Requested-With: XMLHttpRequest' -H 'Referer: https://www.ysscores.com/ar/home' \
  -H 'Content-Type: application/x-www-form-urlencoded; charset=UTF-8' \
  -H 'User-Agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/125.0.0.0 Safari/537.36' \
  --data-urlencode 'get_date=October 30,2026'    # English month, no space after the comma
```

| File | `get_date` sent | Saved | Items | What it covers |
| --- | --- | --- | --- | --- |
| `2026-10-30.html` | `October 30,2026` | 2026-10-30 | 53 | A normal day: 25 competition wrappers, fixtures with times, and matches already in play or finished, which the page shows **without** a `.match-date` (a score or a live block sits in its place) |
| `2026-10-31.html` | `October 31,2026` | 2026-10-30 | 129 | A day with postponements: 10 items carry `match-postponed` and `data-status="14"` while still publishing a time |
| `2026-11-11.html` | `November 11,2026` | 2026-10-30 | 0 | An empty day: the page has no `.matches-wrapper` and no items, and is *not* a layout change |

## The kickoff one test pins

`2026-10-30.html`, match `5802974` (ليل — لانس), `.match-date` `10:05 م` on **2026-10-30**. Egypt's
DST ended on 2026-10-29, so Cairo is UTC+2 that day and the kickoff is **2026-10-30T20:05:00Z**. If
the site ever switches the list to another zone (it serves browser-session times; research R16),
that test fails first.

## Not covered by a saved page

`"--:--"` (a fixture whose kickoff the site has not announced) did not occur on any day saved here:
every fixture carried a time, and the items without a `.match-date` were ones in play. That marker
is covered by a small inline page in `tests/adapters/test_ysscores_parse.py` and by
`normalize`'s tests, which is enough for a pure-parser rule (FR-021, research R16).

Re-save these files on the home box if ysscores changes its markup; the tests are meant to fail
when it does.
