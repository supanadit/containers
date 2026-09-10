## 1. Simple Containers — Single Data Directory

- [x] 1.1 Prometheus: Update `PROMETHEUS_DATA_DIR` default to `/opt/containers/data`, `PROMETHEUS_CONFIG_FILE` to `/opt/containers/config/prometheus.yml`, update `VOLUME` in Dockerfile, update compose files
- [x] 1.2 Thanos: Update `THANOS_DATA_DIR` default to `/opt/containers/data`, update `VOLUME` in Dockerfile, update compose files
- [x] 1.3 etcd: Update `ETCD_DATA_DIR` default to `/opt/containers/data`, update compose files
- [x] 1.4 MinIO: Update `MINIO_DATA_DIR` default to `/opt/containers/data`, update compose files
- [x] 1.5 Grafana: Update `GF_PATHS_DATA` default to `/opt/containers/data`, update compose files
- [x] 1.6 Grafana Alloy: Update `GRAFANA_ALLOY_DATA` default to `/opt/containers/data`, `GRAFANA_ALLOY_CONFIG` to `/opt/containers/config/config.alloy`, update compose files
- [x] 1.7 Grafana Pyroscope: Update `PYROSCOPE_DATA_PATH` default to `/opt/containers/data`, update compose files

## 2. Mid-Complexity Containers — Data + Config + Logs

- [x] 2.1 Apache Kafka: Update `KAFKA_DATA_DIR`, `KAFKA_CONFIG_DIR`, `KAFKA_LOG_DIR`, `KAFKA_RUN_DIR` defaults, update server.properties template, update entrypoint.d/ scripts, update compose files
- [x] 2.2 Apache ZooKeeper: Update `dataDir` in zoo.cfg to `/opt/containers/data`, update entrypoint.sh, update compose files
- [x] 2.3 Apache Cassandra: Update data_file_directories in cassandra.yaml, update entrypoint.sh, update compose files
- [x] 2.4 Apache Spark: Update work directory default to `/opt/containers/data`, update entrypoint.sh, update compose files
- [x] 2.5 Apache Flink: Update `CONFIG_STATE_CHECKPOINTS_DIR` and `CONFIG_STATE_SAVEPOINTS_DIR` defaults, update entrypoint.sh, update compose files
- [x] 2.6 Apache Airflow: Update airflow.cfg paths (dags_folder, base_log_folder) defaults, update entrypoint.sh, update compose files
- [x] 2.7 Grafana Loki: Update `GRAFANA_LOKI_DATA_DIR` default, update configuration.sh template (chunks_directory, rules_directory, path_prefix), update compose files
- [x] 2.8 Grafana Mimir: Update `MIMIR_TSDB_DIR` default, update configuration.sh template, update compose files
- [x] 2.9 Grafana Tempo: Update `GRAFANA_TEMPO_DATA_DIR` default, update configuration.sh template (blocks, wal, generators paths), update compose files

## 3. Complex Containers — Data + Config + Backup + SSH + HA

- [x] 3.1 PostgreSQL entrypoint.sh: Update `DEFAULT_PGDATA`, `DEFAULT_PGCONFIG`, `DEFAULT_PGLOG`, `DEFAULT_PGRUN`, `DEFAULT_PGBACKUP` to normalized paths
- [x] 3.2 PostgreSQL init scripts: Update 01-directories.sh defaults, 02-database.sh (PGDATA references), 03-config.sh (config paths, custom config dir), 04-backup.sh (backup dir, pgbackrest config paths)
- [x] 3.3 PostgreSQL runtime scripts: Update startup.sh (PGDATA, PGBACKUP, RESTORE_STATE_DIR), backup-scheduler.sh (state dir), healthcheck.sh, pg-reload-sync-config.sh
- [x] 3.4 PostgreSQL config templates: Update postgresql.conf generation (include custom config), pg_hba.conf generation, patroni.yml references
- [x] 3.5 PostgreSQL Dockerfile: Update RUN mkdir paths, config COPY destinations
- [x] 3.6 PostgreSQL compose files: Update all 11 compose*.yaml files (patroni, citus, native-ha, backup variants)
- [x] 3.7 MariaDB entrypoint.sh: Update `MARIADB_DATA_DIR`, `MARIADB_CONFIG_DIR`, `MARIADB_LOG_DIR`, `MARIADB_RUN_DIR`, `MARIADB_BACKUP_DIR` defaults
- [x] 3.8 MariaDB init scripts: Update 01-directories.sh, 02-database.sh, 03-config.sh (custom.cnf datadir, SSL paths), 04-backup.sh (backup dir), 05-sshd.sh (.ssh path)
- [x] 3.9 MariaDB runtime scripts: Update startup.sh, healthcheck.sh, backup.sh
- [x] 3.10 MariaDB compose files: Update all compose*.yaml files

## 4. Proxy/Edge Containers — Config + Logs + Run Only

- [x] 4.1 pgpool-ii: Update `PGPOOL_CONFIG_DIR`, `PGPOOL_LOG_DIR`, `PGPOOL_RUN_DIR` defaults, update entrypoint.sh, update all 6 compose*.yaml files
- [x] 4.2 MaxScale: Update `MAXSCALE_CONFIG_DIR`, `MAXSCALE_DATA_DIR`, `MAXSCALE_LOG_DIR` defaults, update entrypoint.sh, update compose files

## 5. Special — WordPress

- [x] 5.1 WordPress: Update wp-content mount path default to `/opt/containers/data`, add `/content` symlink for backward compatibility, update startup.sh, update compose files

## 6. Cross-Cutting

- [x] 6.1 Verify all Dockerfiles have correct `RUN mkdir -p` for normalized paths
- [x] 6.2 Verify no stale path references remain across all entrypoint scripts
- [x] 6.3 Create migration guide documenting old→new paths for every container
- [x] 6.4 Update documentation site (container-docs) with new volume paths
