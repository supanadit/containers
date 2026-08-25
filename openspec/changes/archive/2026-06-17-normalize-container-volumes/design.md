## Context

This project maintains 21 Docker containers (PostgreSQL, MariaDB, Kafka, Prometheus, Grafana, etc.) built with a philosophy of "everything configurable by env" and a focus on developer experience. Currently, each container uses its own directory conventions for persistent data, configuration, backups, logs, and runtime files. The three dominant patterns are:

- `/opt/<app>/<category>` — Kafka, Zookeeper, Cassandra, Flink, Spark, Airflow, Prometheus, Thanos
- `/var/lib/<app>/...` — MariaDB, MaxScale, all Grafana-family, etcd, MinIO
- `/usr/local/<app>/<category>` — PostgreSQL, pgpool-ii

Config files are scattered across `/etc/<app>/`, `/usr/local/<app>/config/`, `/var/lib/<app>/`, and inline in entrypoint scripts. Only PostgreSQL and MariaDB have backup directory conventions. Dockerfile `VOLUME` declarations in Prometheus and Thanos reference stale paths (`/prometheus`, `/thanos`) that don't match their actual data directories.

The target convention is `/opt/containers/<category>` where category ∈ {data, config, backup, logs, run}. Application binary home directories remain unchanged (e.g., `/opt/kafka`, `/usr/local/pgsql`).

## Goals / Non-Goals

**Goals:**
- Unify ALL persistent/customizable paths under `/opt/containers/<category>` across all 21 containers
- Ensure environment variables (`PGDATA`, `KAFKA_DATA_DIR`, `MARIADB_DATA_DIR`, etc.) default to normalized paths
- Support both flat config files and config subdirectories under `/opt/containers/config/`
- Update all example compose files to reflect new paths
- Fix stale `VOLUME` declarations in Dockerfiles
- Keep application binary homes unchanged (no `/usr/local/pgsql` → `/opt/postgresql` migration)

**Non-Goals:**
- Moving application binaries or changing app HOME directories
- Changing how volumes are named in compose files (only the mount target changes)
- Changing the runtime logic for setting up directories (only default paths change)
- Implementing runtime migration/aliasing from old paths to new paths

## Decisions

### 1. Standardized Categories

| Category | Path | Purpose | Currently Scattered At |
|----------|------|---------|----------------------|
| `data` | `/opt/containers/data` | Persistent application data (PGDATA, Kafka logs, Prometheus TSDB, etc.) | `…/data`, `…/mysql`, `…/kafka/data`, `…/pgsql/data` |
| `config` | `/opt/containers/config` | Configuration files (postgresql.conf, kafka server.properties, prometheus.yml, etc.) | `…/config/`, `…/conf/`, `/etc/<app>/` |
| `backup` | `/opt/containers/backup` | Backup repositories (pgBackRest, mariabackup) | `…/pgsql/backup`, `…/mariadb/backup` |
| `logs` | `/opt/containers/logs` | Application log output | `…/logs`, `/var/log/<app>/` |
| `run` | `/opt/containers/run` | PID files, Unix sockets | `…/run`, `/run/<app>/`, `/tmp` |

**Rationale**: Five clean, self-describing categories cover all use cases. `logs` and `run` could theoretically live under `data`, but separating them makes volume mounts more granular (users can mount `data` on fast SSD and `logs` on cheaper storage).

### 2. Env Var Default Strategy

Each container has existing environment variables that control paths. The change is **only to their default values** — users can still override via env:

| Container | Variable | Old Default | New Default |
|-----------|----------|------------|-------------|
| PostgreSQL | `PGDATA` | `/usr/local/pgsql/data` | `/opt/containers/data` |
| PostgreSQL | `PGCONFIG` | `/usr/local/pgsql/config` | `/opt/containers/config` |
| PostgreSQL | `PGLOG` | `/usr/local/pgsql/log` | `/opt/containers/logs` |
| PostgreSQL | `PGBACKUP` | `/usr/local/pgsql/backup` | `/opt/containers/backup` |
| PostgreSQL | `PGRUN` | `/tmp` | `/opt/containers/run` |
| MariaDB | `MARIADB_DATA_DIR` | `/var/lib/mysql` | `/opt/containers/data` |
| MariaDB | `MARIADB_CONFIG_DIR` | `/etc/mysql/mariadb.conf.d` | `/opt/containers/config` |
| MariaDB | `MARIADB_BACKUP_DIR` | `/var/lib/mariadb/backup` | `/opt/containers/backup` |
| MariaDB | `MARIADB_LOG_DIR` | `/var/log/mariadb` | `/opt/containers/logs` |
| MariaDB | `MARIADB_RUN_DIR` | `/run/mariadb` | `/opt/containers/run` |
| Kafka | `KAFKA_DATA_DIR` | `/opt/kafka/data` | `/opt/containers/data` |
| Kafka | `KAFKA_LOG_DIR` | `/opt/kafka/logs` | `/opt/containers/logs` |
| Kafka | `KAFKA_CONFIG_DIR` | `/opt/kafka/config` | `/opt/containers/config` |
| Kafka | `KAFKA_RUN_DIR` | `/tmp/kafka-run` | `/opt/containers/run` |
| Prometheus | `PROMETHEUS_DATA_DIR` | `/opt/prometheus/data` | `/opt/containers/data` |
| Thanos | `THANOS_DATA_DIR` | `/opt/thanos/data` | `/opt/containers/data` |
| etcd | `ETCD_DATA_DIR` | `/var/lib/etcd` | `/opt/containers/data` |
| MinIO | `MINIO_DATA_DIR` | `/var/lib/minio/data` | `/opt/containers/data` |
| Grafana | `GF_PATHS_DATA` | `/var/lib/grafana` | `/opt/containers/data` |
| Grafana Alloy | `GRAFANA_ALLOY_DATA` | `/var/lib/alloy/data` | `/opt/containers/data` |
| Grafana Loki | `GRAFANA_LOKI_DATA_DIR` | `/var/lib/loki` | `/opt/containers/data` |
| Grafana Mimir | `MIMIR_TSDB_DIR` | `/var/lib/mimir/ingester` | `/opt/containers/data` |
| Grafana Pyroscope | `PYROSCOPE_DATA_PATH` | `/var/lib/pyroscope/data` | `/opt/containers/data` |
| Grafana Tempo | `GRAFANA_TEMPO_DATA_DIR` | `/var/lib/tempo` | `/opt/containers/data` |
| Zookeeper | *(in zoo.cfg)* | `/opt/zookeeper/data` | `/opt/containers/data` |
| Cassandra | *(in cassandra.yaml)* | `/opt/cassandra/data` | `/opt/containers/data` |
| Flink | `CONFIG_STATE_CHECKPOINTS_DIR` | `file:///opt/flink/checkpoints` | `file:///opt/containers/data` |
| Airflow | *(in airflow.cfg)* | `/opt/airflow/dags` | `/opt/containers/data` |
| MaxScale | `MAXSCALE_DATA_DIR` | `/var/lib/maxscale/data` | `/opt/containers/data` |
| pgpool-ii | `PGPOOL_CONFIG_DIR` | `/usr/local/pgpool/etc` | `/opt/containers/config` |
| pgpool-ii | `PGPOOL_LOG_DIR` | `/var/log/pgpool` | `/opt/containers/logs` |
| pgpool-ii | `PGPOOL_RUN_DIR` | `/var/run/pgpool` | `/opt/containers/run` |
| WordPress | *(path prefix)* | `/var/www/html` | `/opt/containers/data` |

### 3. Config File Structure

Config files support both flat and hierarchical layouts:

```
Flat:       /opt/containers/config/postgresql.conf
            /opt/containers/config/prometheus.yml

Directory:  /opt/containers/config/ha/patroni.yml
            /opt/containers/config/ha/pg_hba.conf
```

**Rationale**: Some containers (especially PostgreSQL with Patroni) need multiple config files. Allowing subdirectories under `/opt/containers/config/` gives flexibility while keeping the convention. The entrypoint scripts discover config files by scanning both the flat directory and subdirectories.

### 4. Dockerfile VOLUME Declarations

Existing stale declarations are replaced:
- Prometheus: `VOLUME ["/prometheus"]` → `VOLUME ["/opt/containers/data"]`
- Thanos: `VOLUME ["/thanos"]` → `VOLUME ["/opt/containers/data"]`

Containers without `VOLUME` declarations do not gain them unnecessarily — volumes are managed by the user at runtime.

### 5. Implementation Order: Fan-out by Container

Each container is updated independently, organized by complexity:
1. **Simple containers** (single data dir, no backup): Prometheus, Thanos, etcd, MinIO, Grafana, Grafana-Alloy, Grafana-Pyroscope
2. **Mid complexity** (data + config): Kafka, Zookeeper, Cassandra, Spark, Flink, Airflow, Grafana-Loki, Grafana-Mimir, Grafana-Tempo
3. **Complex** (data + config + backup + SSH): PostgreSQL, MariaDB
4. **Proxy/Edge** (no data, config only): pgpool-ii, MaxScale
5. **Special** (existing mount convention): WordPress

## Risks / Trade-offs

- **[Breaking Change]** All existing users must update their compose files and volume mounts to use new paths. → Mitigation: Provide a migration guide with before/after examples. Old env vars can still override defaults if users set them explicitly.
- **[Large Touch Surface]** ~200+ files across 21 containers, 40+ compose files, and documentation. → Mitigation: Container-by-container approach allows incremental testing. Each container can be tested independently.
- **[Config Subdirectories]** Supporting subdirectories under `/opt/containers/config/` adds complexity to config discovery logic. → Mitigation: Only PostgreSQL/Patroni actually needs this; other containers use a flat config file. Implement subdirectory scanning only where needed.
- **[Logs as Separate Volume]** Splitting logs from data means users must mount two volumes instead of one, increasing operational complexity. → Mitigation: Most users don't persist logs at all (go to stdout); this is only for those who want persistent logs. Default behavior unchanged.

## Open Questions

- Should we provide a symlink compatibility layer (old paths → new paths) during a transitional period? (Decision: No. Clean break with migration guide is simpler and avoids hidden complexity.)
- Should WordPress stay with its `/content` mount convention or adopt `/opt/containers/data`? (Leaning: adopt `/opt/containers/data` but `/content` as a known symlink for compatibility.)
