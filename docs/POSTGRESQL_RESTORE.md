# PostgreSQL Disaster Recovery with pgBackRest

This image now supports a fully automated disaster-recovery workflow driven by environment variables. When enabled, the container prepares a clean data directory, restores the requested pgBackRest backup set, and starts PostgreSQL immediately after the restore completes.

## Prerequisites

- `PGBACKREST_ENABLE=true` – enables pgBackRest tooling inside the container.
- A reachable repository (filesystem, S3, Azure, etc.) that already stores the desired backup set.
- A correctly configured stanza (matching the backup) and credentials injected via environment variables or mounted files.

## Quick-start

Set the following minimum environment variables when you launch a fresh container:

```bash
PGBACKREST_ENABLE=true
PGBACKREST_RESTORE=true
PGBACKREST_STANZA=my-db
PGBACKREST_REPO_TYPE=posix   # or s3, gcs, azure, sftp
PGBACKREST_REPO_PATH=/backups/my-db
```

On startup the container will:

1. Move any existing `PGDATA` contents to `<PGDATA>.pre-restore.<timestamp>` (or copy them if the path is a mountpoint).
2. Create a sentinel file at `${PGRUN:-/usr/local/pgsql/run}/pgbackrest-restore.pending`.
3. After pgBackRest is configured, run `pgbackrest restore` during the runtime `startup.sh` phase.
4. Write `${PGRUN:-/usr/local/pgsql/run}/pgbackrest-restore.complete` once the restore succeeds, and continue with the normal PostgreSQL startup sequence.

If the restore fails, the container exits with a non-zero status and the sentinel file remains so that the next start attempt (with the same environment) will retry the restore.

## Optional tuning variables

| Variable | Description | Default |
|----------|-------------|---------|
| `PGBACKREST_RESTORE_TYPE` | `full`, `diff`, `incr`, `time`, `name`, etc. | Not set (pgBackRest default) |
| `PGBACKREST_RESTORE_TARGET` | Point-in-time target value (`YYYY-MM-DD HH:MM:SS`, LSN, label, etc.). | Not set |
| `PGBACKREST_RESTORE_TARGET_TIMELINE` | Timeline to recover to (when using PITR). | Not set |
| `PGBACKREST_RESTORE_TARGET_ACTION` | Restore action (`promote`, `shutdown`, `pause`). | Not set |
| `PGBACKREST_RESTORE_DELTA` | Add `--delta` to allow overwriting existing files (`true`/`false`). | `true` |
| `PGBACKREST_RESTORE_FORCE` | Add `--force` when pgBackRest requests it (use sparingly). | `false` |
| `PGBACKREST_RESTORE_EXTRA_OPTS` | Additional pgBackRest CLI options appended verbatim (space-separated). | Not set |

All options are evaluated during the runtime restore stage so you can change them between container launches without rebuilding the image.

## Patroni considerations

If `PATRONI_ENABLE=true`, the container still runs the pgBackRest restore before handing control to Patroni. Generated `patroni.yml` uses the existing environment variables, so be sure to provide values that match the restored cluster.

## Operational notes

- The configuration management script defers editing `postgresql.conf` and `pg_hba.conf` while a restore is pending to avoid overwriting files that will be provided by the backup.
- `04-backup.sh` skips `archive_mode` tuning if the restore has not yet populated the configuration files. After the restore finishes, PostgreSQL will use whatever settings were captured in the backup.
- Previous data copies are kept alongside the original mount as `<PGDATA>.pre-restore.<timestamp>` so you can inspect them manually.
- The restore completion timestamp is recorded in `${PGRUN:-/usr/local/pgsql/run}/pgbackrest-restore.complete` for diagnostics.

## Manual retry

To retry a failed restore:

1. Fix the underlying issue (credentials, network, repository path, etc.).
2. Ensure `PGBACKREST_RESTORE=true` is still part of the container environment.
3. Relaunch the container. The initialization scripts will re-create the sentinel and the runtime phase will re-execute the restore.

If you want to skip the automated restore on the next start, simply remove or set `PGBACKREST_RESTORE=false` in the container environment.
