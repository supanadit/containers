# PostgreSQL

This container provides PostgreSQL database server with additional tools for high availability, backup, distributed computing, and connection pooling.

## WARNING

We only support PostgreSQL versions that are actively maintained by the official PostgreSQL team. Please refer to the [major version support policy](https://www.postgresql.org/support/versioning/) for details. It is recommended to use a specific major version tag to avoid unexpected issues during minor version upgrades.

If you need deprecated major versions, please check our older tags or build from the corresponding Dockerfile in the GitHub repository. Or you can contact us for assistance, we also provide commercial support.

## Extension Included

- Patroni
- pgBackRest
- PgBouncer
- Decoderbufs
- HypoPG
- Dexter
- pgmetrics
- pgaudit
- pgBadger
- pg_stat_monitor
- pg_repack
- Citus

## Usage

### Build

```bash
docker build -t ghcr.io/supanadit/containers/postgresql:13.5-r0.0.5 .
```

### Run

```bash
docker run -p 5432:5432 -p 6432:6432 ghcr.io/supanadit/containers/postgresql:13.5-r0.0.5
```

PostgreSQL listens on port 5432, PgBouncer on port 6432.

### Volumes

- `/usr/local/pgsql/data` - PostgreSQL data directory
- `/usr/local/pgsql/log` - PostgreSQL log directory
- `/usr/local/pgsql/backup` - pgBackRest backup directory
- `/usr/local/pgsql/custom` - Extended `postgresql.conf`, `*.conf` files can be placed here to override default settings
- `/usr/local/pgsql/hba` - Extended `pg_hba.conf` file can be placed here to override default settings

## Environment Variables

### PostgreSQL Configuration

- `POSTGRES_USER` - PostgreSQL superuser username (default: postgres)
- `POSTGRES_PASSWORD` - PostgreSQL superuser password
- `EXTERNAL_ACCESS_ENABLE` - Enable external access (default: true)
- `EXTERNAL_ACCESS_METHOD` - External access method (default: md5)
- `REPLICATION_USER` - Replication user for HA setups (default: replicator)
- `REPLICATION_PASSWORD` - Replication user password (default: replicator_password)
- `REPLICATION_SYNCHRONOUS_MODE` - Enable synchronous replication (default: true)
  - Controls synchronous replication settings in both Patroni and Native HA modes
- `POSTGRES_CONF_XXX` - Additional PostgreSQL configuration parameters (replace `XXX` with actual parameter name, use underscores instead of dots)

### PgBackRest Configuration

- `PGBACKREST_ENABLE` - Enable pgBackRest (default: false)
- `PGBACKREST_REPO_TYPE` - pgBackRest repository type (default: posix)


#### PgBackRest S3 Configuration

First set `PGBACKREST_REPO_TYPE` to `s3` to enable S3 repository type.

- `PGBACKREST_REPO_S3_BUCKET` - S3 bucket name
- `PGBACKREST_REPO_S3_ENDPOINT` - S3 endpoint URL
- `PGBACKREST_REPO_S3_REGION` - S3 region
- `PGBACKREST_REPO_S3_KEY` - S3 access key
- `PGBACKREST_REPO_S3_KEY_SECRET` - S3 secret key
- `PGBACKREST_REPO_PATH` - pgBackRest repository path (default: /var/lib/pgbackrest)

#### PgBackRest SFTP Configuration

First set `PGBACKREST_REPO_TYPE` to `sftp` to enable SFTP repository type.

- `PGBACKREST_REPO_SFTP_HOST` - SFTP host
- `PGBACKREST_REPO_SFTP_HOST_PORT` - SFTP port (default: 22)
- `PGBACKREST_REPO_SFTP_HOST_USER` - SFTP username
- `PGBACKREST_REPO_SFTP_PRIVATE_KEY_FILE` - Path to private key file for SFTP authentication
- `PGBACKREST_REPO_SFTP_PUBLIC_KEY_FILE` - Path to public key file for SFTP authentication
- `PGBACKREST_REPO_PATH` - pgBackRest repository path (default: /var/lib/pgbackrest)
- `PGBACKREST_REPO_SFTP_HOST_KEY_HASH_TYPE` - SFTP host key hash type
- `PGBACKREST_REPO_SFTP_HOST_KEY_CHECK_TYPE` - SFTP host key check type

### Citus Configuration

**NOTES:** This automatic environment management for Citus is only available when using Patroni for high availability.

For non patroni setup, please manage Citus extension manually.

- `CITUS_ENABLE` - Enable Citus extension (default: false)
- `CITUS_GROUP` - Citus group name (default: 0)
- `CITUS_DATABASE` - Citus database name (default: postgres)

### PgBouncer Configuration

- `PGBOUNCER_ENABLE` - Enable PgBouncer (default: false)
- `PGBOUNCER_LISTEN_ADDR` - Listen address (default: 0.0.0.0)
- `PGBOUNCER_LISTEN_PORT` - Listen port (default: 6432)
- `PGBOUNCER_AUTH_TYPE` - Authentication type (default: md5)
- `PGBOUNCER_ADMIN_USERS` - Admin users (default: postgres)
- `PGBOUNCER_STATS_USERS` - Stats users (default: postgres)
- `PGBOUNCER_POOL_MODE` - Pool mode (default: transaction)
- `PGBOUNCER_MAX_CLIENT_CONN` - Max client connections (default: 100)
- `PGBOUNCER_DEFAULT_POOL_SIZE` - Default pool size (default: 20)

### Timezone

- `POSTGRESQL_TIMEZONE` - Timezone for PostgreSQL (default: UTC)
- `PGBACKREST_AUTO_TIMEZONE` - Timezone for pgBackRest (default: UTC)

### Maintenance Mode

- `SLEEP_MODE` - Enable maintenance sleep mode, this will keep container running without PostgreSQL (default: false)

This is useful for performing maintenance tasks on the data volume without starting the database server.

## For Direct Volume Usage

### Patroni

If you want to use Patroni with direct volume usage, please make sure to include the following files in your volume:

- `patroni.yml:/etc/patroni/patroni.yml` - Patroni configuration file

For environment variables you just need to set `PATRONI_ENABLE` to `true` and Patroni will read the configuration from the file above.

### PgBackRest

If you want to use pgBackRest with direct volume usage, please make sure to include the following files in your volume:

- `pgbackrest.conf:/etc/pgbackrest.conf` - pgBackRest configuration file

For environment variables you just need to set `PGBACKREST_ENABLE` to `true` and pgBackRest will read the configuration from the file above.


### pgBouncer

If you want to use pgBouncer with direct volume usage, please make sure to include the following files in your volume:

- `pgbouncer.ini:/etc/pgbouncer/pgbouncer.ini` - pgBouncer configuration file

For environment variables you just need to set `PGBOUNCER_ENABLE` to `true` and pgBouncer will read the configuration from the file above.
