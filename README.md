# Containers

This is a collection of Docker containers that I have created for various purposes.

## Documentations

### PostgreSQL Backup (pgBackRest) Environment Variables

Enable pgBackRest by setting:

```
PGBACKREST_ENABLE=true
```

Core variables:

```
PGBACKREST_STANZA=default                # Optional stanza name (default: default)
PGBACKREST_PASSWORD=<db_password>        # Optional database user password
PGBACKUP=/path/to/local/backup           # Base path for local repository/log/lock/spool (default: /usr/local/pgsql/backup)
PGBACKREST_ARCHIVE_ENABLE=true           # Inject archive_command when managing postgresql.conf directly
PGBACKREST_ARCHIVE_COMMAND_EXTRA=        # Optional flags appended to archive_command (e.g. --job-default=y)
PGBACKREST_STANZA_CREATE_ON_PRIMARY_ONLY=true  # Skip stanza-create on replicas by default
PGBACKREST_STANZA_PRIMARY_WAIT=60        # Seconds to wait for Patroni leadership before skipping stanza-create
```

Repository selection (repo1):

```
PGBACKREST_REPO1_TYPE=posix|filesystem|s3   # Default: posix
PGBACKREST_REPO1_PATH=/override/path        # Optional override for local posix repo path
PGBACKREST_REPO1_RETENTION_FULL=2           # Full backup retention
PGBACKREST_REPO1_RETENTION_DIFF=6           # Diff backup retention
```

When using S3 (MinIO or any S3-compatible system) set:

```
PGBACKREST_REPO1_TYPE=s3
PGBACKREST_REPO1_S3_BUCKET=my-bucket
PGBACKREST_REPO1_S3_ENDPOINT=minio:9000        # hostname[:port]
PGBACKREST_REPO1_S3_REGION=us-east-1           # Optional (required by some clients)
PGBACKREST_REPO1_S3_KEY=MINIO_ACCESS_KEY       # Optional if using instance/IAM role
PGBACKREST_REPO1_S3_KEY_SECRET=MINIO_SECRET    # Optional if using instance/IAM role
PGBACKREST_REPO1_S3_PORT=9000                  # Optional (if not embedded in endpoint or non-standard)
PGBACKREST_REPO1_S3_VERIFY_TLS=false           # Set to false for self-signed MinIO during testing
PGBACKREST_REPO1_S3_URI_STYLE=path|host        # Optional (MinIO often uses path)
PGBACKREST_REPO1_S3_STORAGE_CLASS=STANDARD     # Optional
PGBACKREST_REPO1_S3_TOKEN=<session_token>      # Optional (temporary creds)
PGBACKREST_REPO1_S3_CA_FILE=/path/ca.crt       # Optional custom CA
PGBACKREST_REPO1_S3_CA_PATH=/path/ca/          # Optional CA directory
```

When using GCS:

```
PGBACKREST_REPO1_TYPE=gcs
PGBACKREST_REPO1_GCS_BUCKET=my-gcs-bucket              # Required
PGBACKREST_REPO1_GCS_ENDPOINT=storage.googleapis.com   # Optional override / emulator endpoint
PGBACKREST_REPO1_GCS_KEY=/secrets/gcs-key.json         # Path to service account JSON (if key-type=service)
PGBACKREST_REPO1_GCS_KEY_TYPE=service|auto|token       # Default: service
PGBACKREST_REPO1_GCS_USER_PROJECT=my-gcp-project       # Optional billing project
```

Switching between object stores:

- Set `PGBACKREST_REPO1_TYPE` to either `s3` or `gcs` and provide the matching `PGBACKREST_REPO1_*` variables.
- Local retention settings (`PGBACKREST_REPO1_RETENTION_*`) remain the same.
- Container will regenerate `/etc/pgbackrest.conf` on restart with the new repo type; ensure stanza is (re)created if migrating.

Notes:

- For MinIO, set `PGBACKREST_REPO1_S3_ENDPOINT` to the service host (and port if needed). Region can be any valid string (e.g., `us-east-1`).
- If credentials are omitted, ensure the container runtime/environment allows implicit auth (IAM role, etc.).
- `PGBACKREST_REPO1_S3_VERIFY_TLS=false` is only for development with self-signed certs. Use TLS verification in production.
- Local directories `backup/` and `archive/` are only created when using a posix/filesystem repository. For S3/GCS they are not needed (only log/lock/spool are local).
 
When using SFTP:

```
PGBACKREST_REPO1_TYPE=sftp
PGBACKREST_REPO1_SFTP_HOST=sftp.example.com          # Required host
PGBACKREST_REPO1_SFTP_HOST_PORT=22                   # Optional
PGBACKREST_REPO1_SFTP_HOST_USER=pgbackrest           # Optional (default depends on image user)
PGBACKREST_REPO1_SFTP_PRIVATE_KEY_FILE=/keys/id_ed25519        # Path inside container
PGBACKREST_REPO1_SFTP_PRIVATE_KEY_PASSPHRASE=changeit          # Optional
PGBACKREST_REPO1_SFTP_PUBLIC_KEY_FILE=/keys/id_ed25519.pub     # Optional
PGBACKREST_REPO1_SFTP_HOST_KEY_CHECK_TYPE=strict|accept-new|fingerprint|none
PGBACKREST_REPO1_SFTP_HOST_FINGERPRINT=aa:bb:cc:...  # Required if using fingerprint check type
PGBACKREST_REPO1_SFTP_KNOWN_HOSTS=/known_hosts,/extra_known_hosts  # Comma or space separated
```

Notes SFTP:
- Provide private key via a secret/volume mount; ensure correct permissions (600) before container start.
- Multiple known hosts files can be listed separated by comma or space.
- If using fingerprint verification set both HOST_FINGERPRINT and HOST_KEY_CHECK_TYPE=fingerprint.

Automatic backup scheduling:

Set `PGBACKREST_AUTO_ENABLE=true` to start an internal lightweight scheduler process that runs backups periodically (no cron daemon required).

Environment variables:
```
PGBACKREST_AUTO_ENABLE=true                 # Enable scheduler
PGBACKREST_AUTO_FULL_INTERVAL=86400         # Seconds between full backups (default 86400 = 24h)
PGBACKREST_AUTO_DIFF_INTERVAL=21600         # Seconds between differential backups (default 6h)
PGBACKREST_AUTO_INCR_INTERVAL=900           # Seconds between incremental backups (default 15m)
PGBACKREST_AUTO_FIRST_INCR_DELAY=120        # Delay after container start before first incremental
PGBACKREST_AUTO_PRIMARY_ONLY=true           # Only run on primary (recommended in HA)
PGBACKREST_AUTO_STATE_DIR=/tmp/pgbackrest-auto  # State dir for last-run timestamps
```

Backup selection order per cycle (every 60s loop):
1. Full if full interval elapsed
2. Else differential if diff interval elapsed
3. Else incremental if incr interval elapsed

Logs: `/var/log/pgbackrest-auto.log` inside container.

### PostgreSQL Configuration Environment Variables

The PostgreSQL container supports various configuration options through environment variables:

```
POSTGRESQL_TIMEZONE=UTC|Asia/Jakarta|+07    # Database timezone (default: UTC)
POSTGRESQL_SHARED_BUFFERS=256MB             # Shared memory buffers
POSTGRESQL_MAX_CONNECTIONS=100              # Maximum connections
POSTGRESQL_WORK_MEM=4MB                     # Work memory per connection
POSTGRESQL_MAINTENANCE_WORK_MEM=64MB        # Maintenance work memory
POSTGRESQL_LISTEN_ADDRESSES=*               # Listen addresses
POSTGRESQL_LOG_STATEMENT=ddl                # Log statement types
POSTGRESQL_LOG_DURATION=on                  # Log query duration
```

#### Timezone Configuration

By default, PostgreSQL uses UTC timezone. To set a different timezone, use the `POSTGRESQL_TIMEZONE` environment variable:

```bash
# Using timezone name
POSTGRESQL_TIMEZONE=Asia/Jakarta

# Using UTC offset
POSTGRESQL_TIMEZONE=+07

# Using UTC (default)
POSTGRESQL_TIMEZONE=UTC
```

This setting applies to both regular PostgreSQL and Patroni-managed clusters.

#### Citus backup scope

When `CITUS_ENABLE=true`, the container defaults to running pgBackRest orchestration only on the Citus coordinator node. Control this behavior with:

```
CITUS_ROLE=coordinator|worker            # Role of the container within the Citus cluster
CITUS_BACKUP_SCOPE=coordinator-only      # Set to all-nodes to allow workers to schedule backups
```

Workers automatically skip stanza creation and scheduled backups when `CITUS_BACKUP_SCOPE` remains `coordinator-only`. Each worker can still be backed up manually by overriding the scope or running pgBackRest outside the scheduler.

Example docker compose service snippet (abbreviated):

```
services:
	postgres:
		image: supanadit/postgresql:13
		environment:
			PGBACKREST_ENABLE: "true"
			PGBACKREST_STANZA: "main"
			PGBACKREST_REPO1_TYPE: "s3"
			PGBACKREST_REPO1_S3_BUCKET: "pgbackups"
			PGBACKREST_REPO1_S3_ENDPOINT: "minio:9000"
			PGBACKREST_REPO1_S3_KEY: "minio"
			PGBACKREST_REPO1_S3_KEY_SECRET: "minio123"
			PGBACKREST_REPO1_S3_VERIFY_TLS: "false"
		depends_on:
			- minio
```

## License

MIT License
