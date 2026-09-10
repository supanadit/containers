# Volume Normalization

## Purpose

Define the standardized volume mount path convention for all containers in this project. Every container SHALL use `/opt/containers/<category>` (data, config, backup, logs, run) for persistent and customizable paths, replacing the previous three inconsistent base-path conventions (`/opt/<app>/`, `/var/lib/<app>/`, `/usr/local/<app>/`).

## Requirements

### Requirement: Standardized data directory
Every container SHALL default its persistent data directory to `/opt/containers/data`. If the container does not persist data (e.g., proxy-only services), this requirement does not apply.

#### Scenario: PostgreSQL uses normalized data directory
- **WHEN** the PostgreSQL container starts without `PGDATA` explicitly set
- **THEN** `PGDATA` SHALL default to `/opt/containers/data`

#### Scenario: MariaDB uses normalized data directory
- **WHEN** the MariaDB container starts without `MARIADB_DATA_DIR` explicitly set
- **THEN** `MARIADB_DATA_DIR` SHALL default to `/opt/containers/data`

#### Scenario: Kafka uses normalized data directory
- **WHEN** the Kafka container starts without `KAFKA_DATA_DIR` explicitly set
- **THEN** `KAFKA_DATA_DIR` SHALL default to `/opt/containers/data`

#### Scenario: Prometheus uses normalized data directory
- **WHEN** the Prometheus container starts without `PROMETHEUS_DATA_DIR` explicitly set
- **THEN** `PROMETHEUS_DATA_DIR` SHALL default to `/opt/containers/data`

#### Scenario: Thanos uses normalized data directory
- **WHEN** the Thanos container starts without `THANOS_DATA_DIR` explicitly set
- **THEN** `THANOS_DATA_DIR` SHALL default to `/opt/containers/data`

#### Scenario: etcd uses normalized data directory
- **WHEN** the etcd container starts without `ETCD_DATA_DIR` explicitly set
- **THEN** `ETCD_DATA_DIR` SHALL default to `/opt/containers/data`

#### Scenario: MinIO uses normalized data directory
- **WHEN** the MinIO container starts without `MINIO_DATA_DIR` explicitly set
- **THEN** `MINIO_DATA_DIR` SHALL default to `/opt/containers/data`

#### Scenario: Grafana uses normalized data directory
- **WHEN** the Grafana container starts without `GF_PATHS_DATA` explicitly set
- **THEN** `GF_PATHS_DATA` SHALL default to `/opt/containers/data`

#### Scenario: Grafana Loki uses normalized data directory
- **WHEN** the Grafana Loki container starts without `GRAFANA_LOKI_DATA_DIR` explicitly set
- **THEN** `GRAFANA_LOKI_DATA_DIR` SHALL default to `/opt/containers/data`

#### Scenario: Grafana Mimir uses normalized data directory
- **WHEN** the Grafana Mimir container starts without `MIMIR_TSDB_DIR` explicitly set
- **THEN** `MIMIR_TSDB_DIR` SHALL default to `/opt/containers/data`

#### Scenario: Grafana Pyroscope uses normalized data directory
- **WHEN** the Grafana Pyroscope container starts without `PYROSCOPE_DATA_PATH` explicitly set
- **THEN** `PYROSCOPE_DATA_PATH` SHALL default to `/opt/containers/data`

#### Scenario: Grafana Tempo uses normalized data directory
- **WHEN** the Grafana Tempo container starts without `GRAFANA_TEMPO_DATA_DIR` explicitly set
- **THEN** `GRAFANA_TEMPO_DATA_DIR` SHALL default to `/opt/containers/data`

#### Scenario: Grafana Alloy uses normalized data directory
- **WHEN** the Grafana Alloy container starts without `GRAFANA_ALLOY_DATA` explicitly set
- **THEN** `GRAFANA_ALLOY_DATA` SHALL default to `/opt/containers/data`

#### Scenario: ZooKeeper uses normalized data directory
- **WHEN** the ZooKeeper container starts
- **THEN** the `dataDir` in its `zoo.cfg` SHALL default to `/opt/containers/data`

#### Scenario: Cassandra uses normalized data directory
- **WHEN** the Cassandra container starts
- **THEN** the `data_file_directories` in `cassandra.yaml` SHALL default to `/opt/containers/data`

#### Scenario: Flink uses normalized checkpoint directory
- **WHEN** the Flink container starts without `CONFIG_STATE_CHECKPOINTS_DIR` explicitly set
- **THEN** `CONFIG_STATE_CHECKPOINTS_DIR` SHALL default to `file:///opt/containers/data`

#### Scenario: Spark uses normalized work directory
- **WHEN** the Spark container starts
- **THEN** the Spark work directory SHALL default to `/opt/containers/data`

#### Scenario: WordPress uses normalized data directory
- **WHEN** the WordPress container starts in stateful mode
- **THEN** the wp-content mount path SHALL default to `/opt/containers/data`

#### Scenario: User override of data directory is respected
- **WHEN** any container starts with its data directory env var explicitly set to a custom path
- **THEN** the custom path SHALL be used instead of the default normalized path

---

### Requirement: Standardized configuration directory
Every container that supports external configuration files SHALL default its configuration directory to `/opt/containers/config`. Configuration files MAY be placed directly in this directory or in subdirectories.

#### Scenario: PostgreSQL uses normalized config directory
- **WHEN** the PostgreSQL container starts without `PGCONFIG` explicitly set
- **THEN** `PGCONFIG` SHALL default to `/opt/containers/config`

#### Scenario: Kafka uses normalized config directory
- **WHEN** the Kafka container starts without `KAFKA_CONFIG_DIR` explicitly set
- **THEN** `KAFKA_CONFIG_DIR` SHALL default to `/opt/containers/config`

#### Scenario: MariaDB uses normalized config directory
- **WHEN** the MariaDB container starts without `MARIADB_CONFIG_DIR` explicitly set
- **THEN** `MARIADB_CONFIG_DIR` SHALL default to `/opt/containers/config`

#### Scenario: pgpool-ii uses normalized config directory
- **WHEN** the pgpool-ii container starts without `PGPOOL_CONFIG_DIR` explicitly set
- **THEN** `PGPOOL_CONFIG_DIR` SHALL default to `/opt/containers/config`

#### Scenario: Prometheus uses normalized config file
- **WHEN** the Prometheus container starts without `PROMETHEUS_CONFIG_FILE` explicitly set
- **THEN** `PROMETHEUS_CONFIG_FILE` SHALL default to `/opt/containers/config/prometheus.yml`

#### Scenario: MaxScale uses normalized config directory
- **WHEN** the MaxScale container starts without `MAXSCALE_CONFIG_DIR` explicitly set
- **THEN** `MAXSCALE_CONFIG_DIR` SHALL default to `/opt/containers/config`

---

### Requirement: Standardized backup directory
Every container that supports backup operations SHALL default its backup repository path to `/opt/containers/backup`.

#### Scenario: PostgreSQL uses normalized backup directory
- **WHEN** the PostgreSQL container starts with pgBackRest enabled and without `PGBACKUP` explicitly set
- **THEN** `PGBACKUP` SHALL default to `/opt/containers/backup`

#### Scenario: MariaDB uses normalized backup directory
- **WHEN** the MariaDB container starts with backup enabled and without `MARIADB_BACKUP_DIR` explicitly set
- **THEN** `MARIADB_BACKUP_DIR` SHALL default to `/opt/containers/backup`

---

### Requirement: Standardized logs directory
Every container that writes persistent logs SHALL default its log directory to `/opt/containers/logs`.

#### Scenario: PostgreSQL uses normalized log directory
- **WHEN** the PostgreSQL container starts without `PGLOG` explicitly set
- **THEN** `PGLOG` SHALL default to `/opt/containers/logs`

#### Scenario: Kafka uses normalized log directory
- **WHEN** the Kafka container starts without `KAFKA_LOG_DIR` explicitly set
- **THEN** `KAFKA_LOG_DIR` SHALL default to `/opt/containers/logs`

#### Scenario: MariaDB uses normalized log directory
- **WHEN** the MariaDB container starts without `MARIADB_LOG_DIR` explicitly set
- **THEN** `MARIADB_LOG_DIR` SHALL default to `/opt/containers/logs`

---

### Requirement: Standardized run directory
Every container that creates PID files or Unix sockets SHALL default its runtime directory to `/opt/containers/run`.

#### Scenario: PostgreSQL uses normalized run directory
- **WHEN** the PostgreSQL container starts without `PGRUN` explicitly set
- **THEN** `PGRUN` SHALL default to `/opt/containers/run`

#### Scenario: MariaDB uses normalized run directory
- **WHEN** the MariaDB container starts without `MARIADB_RUN_DIR` explicitly set
- **THEN** `MARIADB_RUN_DIR` SHALL default to `/opt/containers/run`

#### Scenario: pgpool-ii uses normalized run directory
- **WHEN** the pgpool-ii container starts without `PGPOOL_RUN_DIR` explicitly set
- **THEN** `PGPOOL_RUN_DIR` SHALL default to `/opt/containers/run`

---

### Requirement: Config subdirectory support
Containers that require multiple logical groups of configuration files SHALL support subdirectories under `/opt/containers/config/`. Files placed directly in the config root and files in immediate subdirectories SHALL both be discovered.

#### Scenario: PostgreSQL discovers HA config in subdirectory
- **WHEN** the PostgreSQL container starts and a `patroni.yml` file exists at `/opt/containers/config/ha/patroni.yml`
- **THEN** the container SHALL discover and apply that configuration

#### Scenario: Flat config file still works
- **WHEN** a container starts and its primary config file exists at `/opt/containers/config/<config-file>`
- **THEN** the container SHALL discover and apply that configuration without requiring a subdirectory

---

### Requirement: Dockerfile VOLUME declarations match normalized paths
Every Dockerfile that declares a `VOLUME` instruction SHALL use the normalized `/opt/containers/<category>` paths.

#### Scenario: Prometheus VOLUME uses normalized data path
- **WHEN** the Prometheus Dockerfile is inspected
- **THEN** the `VOLUME` instruction SHALL reference `/opt/containers/data`, not `/prometheus`

#### Scenario: Thanos VOLUME uses normalized data path
- **WHEN** the Thanos Dockerfile is inspected
- **THEN** the `VOLUME` instruction SHALL reference `/opt/containers/data`, not `/thanos`

---

### Requirement: Example compose files use normalized mount targets
All example `compose*.yaml` files in the `container-examples` repository SHALL mount volumes to normalized `/opt/containers/<category>` paths.

#### Scenario: PostgreSQL compose uses normalized paths
- **WHEN** reviewing any PostgreSQL compose file
- **THEN** volume mount targets SHALL be `/opt/containers/data`, `/opt/containers/config`, or `/opt/containers/backup`

#### Scenario: Prometheus compose uses normalized paths
- **WHEN** reviewing the Prometheus compose file
- **THEN** volume mount targets SHALL be `/opt/containers/data` and `/opt/containers/config`
