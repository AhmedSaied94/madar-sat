# Contract: snapshot load report

Output of `python -m app.cli load-snapshot` (spec FR-003, SC-002) and `python -m app.cli rehost-media` (FR-006, SC-004). The owner reads it, and the SC-002 check consumes it. Each run writes one JSON file, `load-report-<UTC timestamp>.json`, in `--report-dir` (default: the current directory, never inside the repo), and prints a short human-readable summary to stdout.

## Shape

```jsonc
{
  "command": "load-snapshot",                  // or "rehost-media"
  "snapshot_dir": "/srv/snapshot/2026-11-02",
  "started_at": "2026-11-02T08:10:00Z",
  "finished_at": "2026-11-02T08:10:41Z",
  "reconciled": true,                          // false → the command exits non-zero
  "collections": {
    "satellites":   { "source_rows": 32,   "loaded": 32,   "merged": 0, "skipped": 0, "skip_reasons": {} },
    "competitions": { "source_rows": 134,  "loaded": 134,  "merged": 0, "skipped": 0, "skip_reasons": {} },
    "teams":        { "source_rows": 1513, "loaded": 1513, "merged": 0, "skipped": 0, "skip_reasons": {} },
    "channels":     { "source_rows": 2418, "loaded": 2409, "merged": 9, "skipped": 0, "skip_reasons": {} },
    "matches":      { "source_rows": 481,  "loaded": 470,  "merged": 11, "skipped": 0, "skip_reasons": {} },
    "match_channels": { "source_rows": 0, "loaded": 0, "merged": 0, "skipped": 47,
                        "skip_reasons": { "channel_not_published": 47 } }
    // … one entry per loaded collection and link table
  },
  "kinds": { "channels": { "satellite": 941, "terrestrial": 8, "platform": 1469 } },
  "warnings": [                                // admin follow-ups that don't block the load
    { "code": "satellite_frequency_missing_polarization", "ref": "Astra 19.2E worstFreq", "value": "12166 29700" }
  ],
  "details_file": "load-report-20261102T081000Z.details.jsonl",
  "checks": {
    "card_sharing_labels_found": 0,            // must be 0
    "frequencies_out_of_domain": 0             // rejected values appear in skip_reasons or frequency_note, never stored
  },
  "media": null                                // set by rehost-media (below)
}
```

The counts above are illustrative. Real values depend on the snapshot being loaded.

## Rules

- **Reconciliation:** for every collection, `source_rows = loaded + merged + skipped`, and the sum of `skip_reasons` equals `skipped`. `reconciled` is `true` only when every collection holds and every `checks` value is `0`.
- **Details file:** each merged or skipped item gets one line, `{collection, legacy_id, action, reason, into}`, so the owner can trace any count back to rows.
- **Skip reasons** are stable snake_case codes:
  - `channel_not_published`, `rights_order_unknown_id`;
  - `team_name_unresolved`, `team_name_ambiguous` (the row is loaded with `*_team_id` NULL and counted as a warning, not a skip);
  - `frequency_unparseable` (kept as `frequency_note`, also a warning);
  - `duplicate_listing`, `duplicate_carriage`;
  - `card_sharing_label_stripped` (a channel `name` or `displayName` that carried a card-sharing label is stored without it, for example «CCTV Sports VIP» → «CCTV Sports»; a warning, not a skip), and `name_is_card_sharing_label` (a skip: nothing is left once the label is removed).
- **Idempotency:** a second run on the same snapshot reports the same counts, and the database row counts don't change (spec FR-004).

## `media` (rehost-media)

```jsonc
"media": {
  "urls_total": 5979, "already_hosted": 0, "rehosted": 5890, "deduplicated": 41,
  "failed": 48, "fail_reasons": { "http_404": 40, "too_large": 2, "redirect_off_host": 1, "decode_error": 5 },
  "hosts": { "pub-01ffc6064b9b435aa726a53a561a6f53.r2.dev": 5973, "imgs.ysscores.com": 6 }
}
```

- `urls_total = already_hosted + rehosted + deduplicated + failed`.
- A failed URL leaves its column NULL and appears in the details file.
- Hosts outside the allowlist are counted under `fail_reasons.host_not_allowed` and never fetched.
