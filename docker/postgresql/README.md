# PostgreSQL

This container provides PostgreSQL database server with additional tools for high availability, backup, distributed computing, and connection pooling.

## WARNING

We only support PostgreSQL versions that are actively maintained by the official PostgreSQL team. Please refer to the [major version support policy](https://www.postgresql.org/support/versioning/) for details. It is recommended to use a specific major version tag to avoid unexpected issues during minor version upgrades.

If you need deprecated major versions, please check our older tags or build from the corresponding Dockerfile in the GitHub repository. Or you can contact us for assistance, we also provide commercial support.

## Features

- PostgreSQL
- Patroni
- pgBackRest
- Citus
- PgBouncer
- pg_stat_monitor
- Decoderbufs
- HypoPG
- Dexter
- pgmetrics
- pgaudit

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
- `POSTGRES_DB` - Default database name (default: postgres)
- `POSTGRES_INITDB_ARGS` - Additional arguments for initdb
- `POSTGRES_INITDB_WALDIR` - WAL directory for initdb
- `POSTGRES_HOST_AUTH_METHOD` - Authentication method (default: trust)
- `POSTGRES_CONF_XXX` - Additional PostgreSQL configuration parameters (replace `XXX` with actual parameter name, use underscores instead of dots)

### Citus Configuration

- `CITUS_ENABLE` - Enable Citus extension (default: false)
- `CITUS_ROLE` - Citus node role (coordinator/worker, default: coordinator)
- `CITUS_NODE_NAME` - Node name for Citus
- `CITUS_GROUP` - Citus group ID
- `CITUS_DATABASE` - Citus database name (default: citus)
- `CITUS_BACKUP_SCOPE` - Backup scope for Citus

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