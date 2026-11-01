# Saved LiveSoccerTV pages

Raw HTML fetched on 2026-11-01 from `www.livesoccertv.com` directly (never through `LVS.html`'s
Cloudflare proxy), saved as UTF-8. Each file had its `<script>` blocks, `<iframe>`s and inline
`onclick="ga(…)"` analytics hooks replaced or stripped; no cookie, consent or tracking payload is
committed. CSS, structure, `data-ko`, the `dv` epoch spans, titles and links are untouched, because
that is what `app.adapters.livesoccertv.parse` reads.

| File | Source URL | What it covers |
| --- | --- | --- |
| `team-al-ahly-egypt.html` | `/teams/egypt/al-ahly/` | An Egyptian club: a `table.schedules` with past and upcoming rows, some home and some away |
| `team-real-madrid-spain.html` | `/teams/spain/real-madrid/` | A European club: rows whose URL slug order differs from the page's home/away order |
| `team-egypt-a-empty.html` | `/teams/egypt/egypt-a/` | A team page with no fixtures at all: no `table.schedules` (a national select side; LiveSoccerTV publishes no page for senior national teams) |
| `match-al-ahly-vs-al-sekka-none.html` | `/match/al-ahly-vs-al-sekka/27z7272vt` | A match page with no broadcasters yet: `#dynamic-international-tv` is empty, no `table.ichannels` |
| `match-real-madrid-vs-valencia.html` | `/match/real-madrid-vs-valencia/1bpms` | MENA (Algeria, Bahrain, Egypt, Saudi Arabia…) and non-MENA broadcasters, including names Madar has no channel for |
| `match-egypt-vs-cote-divoire.html` | `/match/cote-divoire-vs-egypt/dd` | A national-team match with MENA broadcasters |

Re-fetching is a deliberate act: a changed layout is what `LayoutChanged` exists for, so the tests
fail when a fixture is edited instead of re-saved.
