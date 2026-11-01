# Database migrations

The schema is managed by Alembic, inside the backend image. Revision `0001` is the old app's `schema.sql` unchanged, `0002` adds the MVP tables, `0003` adds `audit_log.source` and `match_channels.imported_by` ([below](#revision-0003)), `0004` adds the `broadcast_presets` and `sources` dataset names ([below](#revision-0004)), `0005` adds devices' satellites, the outbox cursor, source health, the run log and placeholder markers ([below](#revision-0005)),, and every later change follows expand/contract, so the old and new releases both run against the same schema (constitution, "Migrations"). Every deploy runs `alembic upgrade head` before it starts the new release. This runbook covers what happens then, how to read the state, and what to do when a migration fails. It touches production's database. Background: `backend/alembic/`, research R13.

## How a migration runs in a deploy

- `deploy.sh` step 4 runs the `migrate` service of `infra/compose/vps1.yml` (profile `tools`): the **new** image, running `alembic upgrade head`. It connects with `DATABASE_URL_SYNC` from `/srv/madar/.env`.
- `backend/alembic/env.py` runs every pending revision inside **one** transaction. On PostgreSQL, a failure therefore rolls back all the revisions of that run. A statement that can't run in a transaction, such as `CREATE INDEX CONCURRENTLY`, would break that; none exists today.
- The previous release keeps serving while the migration runs, and keeps running on the new schema if a later step fails. That is why every migration must be backward compatible.
- If the migration fails, the deploy stops with `error: migration failed; the running containers were not touched (still <tag>)`.
- **Migrations are never reversed in production.** `0001` has no downgrade, and a rollback is an older release on the newer schema ([deploy-and-rollback.md "Roll back"](deploy-and-rollback.md#roll-back)).

## Read the state

In the "Working on VPS-1" shell ([deploy-and-rollback.md](deploy-and-rollback.md#working-on-vps-1)):

```bash
dc run --rm migrate alembic current      # the revision the database is at
dc run --rm migrate alembic heads        # the newest revision this image knows
dc run --rm migrate alembic history      # every revision this image knows
```

They use the image of `IMAGE_TAG`, so they show what that release knows. An older image doesn't know newer revisions: `alembic current` then fails with `Can't locate revision …`, which is expected.

A `psql` shell on the database. The container trusts local connections, so it needs no password:

```bash
dc exec postgres psql -U madar -d madar
```

```sql
SELECT version_num FROM alembic_version;
```

## Run it by hand

Normally the deploy does this. To run it outside a deploy, with a tag's image:

```bash
IMAGE_TAG=<tag> dc run --rm -T migrate
```

## When a migration fails

1. Read the error in the deploy job's log, just above the `migration failed` line, or run it by hand as above.
2. Nothing needs undoing in the database: the transaction rolled back, and `alembic current` still shows the old revision. The previous release is still serving.
3. Reproduce it locally against the `dev.yml` PostgreSQL ([local-dev.md](local-dev.md)): `cd backend && uv run alembic upgrade head`.
4. Fix it in a new commit and merge. The next deploy runs it again.

If a migration did leave partial changes (a non-transactional statement), check what it did in `psql` (`\d <table>`) before you fix it forward. Don't edit `alembic_version` by hand unless the fix needs it, and note what you did in the PR.

## Revision 0003

Added on D2 (`backend/alembic/versions/0003_audit_source_link_origin.py`). Two additive changes, so the release before it keeps running on the new schema:

- `audit_log.source` (nullable, references `sources(name)`) names the importer behind a change. `ck_audit_log_actor` requires a row to have an admin **or** a source, never both (neither is a CLI action).
- `match_channels.imported_by` (nullable, references `sources(name)`) records which importer first brought a channel link. `NULL` means an editor added it. The migration backfills it with `UPDATE match_channels SET imported_by = source WHERE source <> 'manual'`, in the same transaction as the two `ALTER TABLE`s.

Check it after a deploy, in `psql` ([above](#read-the-state)):

```sql
SELECT version_num FROM alembic_version;                       -- 0003
SELECT count(*) FILTER (WHERE source <> 'manual' AND imported_by IS NULL) AS missed   -- must be 0
FROM match_channels;
```

`/v1` doesn't read either column. The migration has a downgrade (it drops both columns and the CHECK), meant for a local database: `cd backend && uv run alembic downgrade 0002 && uv run alembic upgrade head`. In production a rollback is the older release on the newer schema, as for every revision ([deploy-and-rollback.md "Roll back"](deploy-and-rollback.md#roll-back)).

## Revision 0004

Added on D2 (`backend/alembic/versions/0004_list_datasets.py`). It widens `ck_dataset_versions_name`
by two names, `broadcast_presets` and `sources`, and inserts both rows at version 0, so the two
read-only admin lists can answer `304` (constitution VI). No table or column changes, so the release
before it keeps running on the new schema. The downgrade deletes the two rows and restores the
eight-name CHECK.

```sql
SELECT name, version FROM dataset_versions ORDER BY name;       -- ten rows, both new ones at 0
```

## Writing a migration

The rules (constitution, "Migrations"):

- **Expand:** add tables, and nullable or defaulted columns. Backfill in the same or a later revision.
- **Switch:** release code that uses the new shape, while still accepting the old one.
- **Contract:** drop the old columns in a **later** release, once no running or rollback-target release reads them.
- Never rename or drop something the previous release reads, in the same release that stops reading it.
- `0001` is `schema.sql` unchanged, and a test checks its SQL file hash. Never edit it.

Rolling back by redeploying an older release through `deploy.sh` runs that release's `alembic upgrade head`. That fails once the database is at a revision the older image doesn't know. Use the manual rollback instead ([deploy-and-rollback.md "Roll back"](deploy-and-rollback.md#roll-back)).

## Revision 0005

Added on D3 (`backend/alembic/versions/0005_devices_outbox_sources.py`). Expand-only: every change is a nullable column or one with a default, so the D2 release keeps running on the new schema.

- `devices.satellite_ids bigint[] NOT NULL DEFAULT '{}'`, `ck_devices_satellite_ids` (`cardinality <= 32`): the device's dish, which words its reminders. Not a foreign key (arrays can't be); the API checks ids on write and the dispatcher ignores ids that no longer exist.
- `notification_outbox.claimed_at timestamptz`, `cursor_device_id bigint NOT NULL DEFAULT 0`, index `notification_outbox_sending_idx` on `claimed_at WHERE status = 'sending'`: reclaim a row a dead worker left in `sending`, resume a partly sent one without sending twice.
- `sources.consecutive_failures integer NOT NULL DEFAULT 0` (`>= 0`), `breaker_opened_at`, `last_success_at`, `last_zero_alert_on date`: the circuit breaker and the zero-items alarm. Lane B2 writes them only through `app/adapters/health.py`.
- `import_runs.log jsonb`: the compact run log (≤ 64 KB, truncated lists), read by `api-admin` on VPS-1, which cannot see VPS-2's `run.json`.
- `channels.placeholder_source text REFERENCES sources(name)`, index `channels_placeholder_idx` on `placeholder_source WHERE placeholder_source IS NOT NULL`: an importer-created placeholder, hidden from every public read until an editor saves it with `show_in_match: true`.

Check it after a deploy:

```sql
SELECT column_name FROM information_schema.columns
 WHERE table_name IN ('devices', 'notification_outbox', 'sources', 'import_runs', 'channels')
   AND column_name IN ('satellite_ids', 'claimed_at', 'cursor_device_id', 'consecutive_failures',
                       'breaker_opened_at', 'last_success_at', 'last_zero_alert_on', 'log', 'placeholder_source');
```

Nine rows. The downgrade drops them all and leaves every other row unchanged; no data migration is needed.
