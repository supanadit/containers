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
