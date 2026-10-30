# Sat Air bridge fixtures (synthetic)

Two `GET https://firestore.googleapis.com/v1/projects/<id>/databases/(default)/documents/matchDays/<day>`
responses in Firestore's real **typed-value** REST shape (`stringValue`, `arrayValue`, `mapValue`,
`booleanValue`, `timestampValue`). They are hand-written for Lane B2's bridge tests (T052, R19):

- no real export, no project id and no key — `example-project` is a placeholder, and the docs are
  what the REST API returns for a `matchDays` document, not the export format;
- the channel ids are the snapshot's own (`ch-cyr`, `ch-hidden`, `ch-nilesat-free`, `ch-badr-enc`)
  plus `orphan-channel-1`, which exists nowhere, so the "orphan skipped and logged" rule is tested;
- no card-sharing label is imported: `bridge-new-1` carries one in `cardSharing` on purpose, and a
  test asserts it never reaches a row.

| File | What it covers |
| --- | --- |
| `2026-10-31.json` | A new match (`bridge-new-1`) with three channel ids, one orphan, one hidden channel and per-channel commentators (one with a second name); a match that already has a ysscores id (`bridge-ys-1`, `ysMatchId=5802974`) whose own fields must not win; a match of placeholders (`bridge-placeholders-1`: `""`, `"⚽"`, `«غير مدرج»`, `"--:--"`, doubled stage text) |
| `2026-11-02.json` | A day only the bridge has: one fixture and one commentator name that nothing else defines, so a new commentator row is created by `name_norm` |

A day Firestore has no document for answers **404**; the bridge treats that as an empty day, which
is asserted in the bridge test rather than in a fixture.
