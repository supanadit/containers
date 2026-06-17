# Volume Path Migration Guide

## Overview

All containers have been updated to use normalized volume mount paths under `/opt/containers/`. This is a **breaking change** — existing deployments must update their volume mounts.

## New Path Convention

| Category | New Path | Purpose |
|----------|----------|---------|
| Data | `/opt/containers/data` | Persistent application data |
| Config | `/opt/containers/config` | Configuration files (flat or subdirectories) |
| Backup | `/opt/containers/backup` | Backup repositories |
| Logs | `/opt/containers/logs` | Log output |
| Run | `/opt/containers/run` | PID files, Unix sockets |

## Per-Container Migration

### Prometheus
| Old Volume Mount | New Volume Mount |
|-----------------|------------------|
| `/opt/prometheus/data` | `/opt/containers/data` |
| `/etc/prometheus/prometheus.yml` | `/opt/containers/config/prometheus.yml` |

```yaml
# Old:
volumes:
  - ./data/prometheus:/opt/prometheus/data
  - ./config/prometheus.yml:/etc/prometheus/prometheus.yml

# New:
volumes:
  - ./data/prometheus:/opt/containers/data
  - ./config/prometheus.yml:/opt/containers/config/prometheus.yml
```

### Thanos
| Old Volume Mount | New Volume Mount |
|-----------------|------------------|
| `/opt/thanos/data` | `/opt/containers/data` |

```yaml
# Old:
volumes:
  - ./data/receive:/opt/thanos/data

# New:
volumes:
  - ./data/receive:/opt/containers/data
```

### etcd
| Old Volume Mount | New Volume Mount |
|-----------------|------------------|
| `/var/lib/etcd` | `/opt/containers/data` |

```yaml
# Old:
volumes:
  - etcd_data:/var/lib/etcd

# New:
volumes:
  - etcd_data:/opt/containers/data
```

### MinIO
| Old Volume Mount | New Volume Mount |
|-----------------|------------------|
| `/var/lib/minio/data` | `/opt/containers/data` |

```yaml
# Old:
volumes:
  - ./data/minio:/var/lib/minio/data

# New:
volumes:
  - ./data/minio:/opt/containers/data
```

### Grafana
| Old Volume Mount | New Volume Mount |
|-----------------|------------------|
| `/var/lib/grafana` | `/opt/containers/data` |
| `/var/log/grafana` | `/opt/containers/logs` |
| `/etc/grafana/grafana.ini` | `/opt/containers/config/grafana.ini` |

```yaml
# Old:
volumes:
  - ./data/grafana:/var/lib/grafana
  - ./config:/etc/grafana

# New:
volumes:
  - ./data/grafana:/opt/containers/data
  - ./config:/opt/containers/config
```

### Grafana Alloy
| Old Volume Mount | New Volume Mount |
|-----------------|------------------|
| `/var/lib/alloy/data` | `/opt/containers/data` |
| `/etc/alloy/config.alloy` | `/opt/containers/config/config.alloy` |

### Grafana Loki
| Old Volume Mount | New Volume Mount |
|-----------------|------------------|
| `/var/lib/loki` | `/opt/containers/data` |
| `/etc/loki/loki.yaml` | `/opt/containers/config/loki.yaml` |

### Grafana Mimir
| Old Volume Mount | New Volume Mount |
|-----------------|------------------|
| `/var/lib/mimir/ingester` | `/opt/containers/data` |
| `/etc/mimir.yaml` | `/opt/containers/config/mimir.yaml` |

### Grafana Tempo
| Old Volume Mount | New Volume Mount |
|-----------------|------------------|
| `/var/lib/tempo` | `/opt/containers/data` |
| `/etc/tempo.yaml` | `/opt/containers/config/tempo.yaml` |

### Grafana Pyroscope
| Old Volume Mount | New Volume Mount |
|-----------------|------------------|
| `/var/lib/pyroscope/data` | `/opt/containers/data` |
| `/var/lib/pyroscope/compactor` | `/opt/containers/data/compactor` |
| `/var/lib/pyroscope/shared` | `/opt/containers/data/shared` |

### PostgreSQL
| Env Var | Old Default | New Default |
|---------|------------|-------------|
| `PGDATA` | `/usr/local/pgsql/data` | `/opt/containers/data` |
| `PGCONFIG` | `/usr/local/pgsql/config` | `/opt/containers/config` |
| `PGLOG` | `/usr/local/pgsql/log` | `/opt/containers/logs` |
| `PGBACKUP` | `/usr/local/pgsql/backup` | `/opt/containers/backup` |
| `PGRUN` | `/tmp` | `/opt/containers/run` |

```yaml
# Old:
volumes:
  - postgresql_data:/usr/local/pgsql/data
  - postgresql_backup:/usr/local/pgsql/backup

# New:
volumes:
  - postgresql_data:/opt/containers/data
  - postgresql_backup:/opt/containers/backup
```

### MariaDB
| Env Var | Old Default | New Default |
|---------|------------|-------------|
| `MARIADB_DATA_DIR` | `/var/lib/mysql` | `/opt/containers/data` |
| `MARIADB_CONFIG_DIR` | `/etc/mysql/mariadb.conf.d` | `/opt/containers/config` |
| `MARIADB_LOG_DIR` | `/var/log/mariadb` | `/opt/containers/logs` |
| `MARIADB_PUN_DIR` | `/run/mariadb` | `/opt/containers/run` |
| `MARIADB_BACKUP_DIR` | `/var/lib/mariadb/backup` | `/opt/containers/backup` |

```yaml
# Old:
volumes:
  - mariadb_data:/var/lib/mysql

# New:
volumes:
  - mariadb_data:/opt/containers/data
```

### Kafka
| Env Var | Old Default | New Default |
|---------|------------|-------------|
| `KAFKA_DATA_DIR` | `/opt/kafka/data` | `/opt/containers/data` |
| `KAFKA_CONFIG_DIR` | `/opt/kafka/config` | `/opt/containers/config` |
| `KAFKA_LOG_DIR` | `/opt/kafka/logs` | `/opt/containers/logs` |
| `KAFKA_RUN_DIR` | `/tmp/kafka-run` | `/opt/containers/run` |

```yaml
# Old:
volumes:
  - kafka_data:/opt/kafka/data

# New:
volumes:
  - kafka_data:/opt/containers/data
```

### ZooKeeper
| Component | Old Path | New Path |
|-----------|----------|----------|
| Data dir | `/opt/zookeeper/data` | `/opt/containers/data` |
| Config dir | `/opt/zookeeper/conf` | `/opt/containers/config` |

### Cassandra
| Component | Old Path | New Path |
|-----------|----------|----------|
| Data dirs | `/opt/cassandra/data/...` | `/opt/containers/data/...` |

### Flink
| Component | Old Path | New Path |
|-----------|----------|----------|
| Checkpoints | `/opt/flink/checkpoints` | `/opt/containers/data` |
| Savepoints | `/opt/flink/savepoints` | `/opt/containers/data` |
| Logs | `/opt/flink/logs` | `/opt/containers/logs` |
| Config dir | `/opt/flink/conf` | `/opt/containers/config` |

### Spark
| Component | Old Path | New Path |
|-----------|----------|----------|
| Work dir | `/opt/spark/work` | `/opt/containers/data` |

### Airflow
| Component | Old Path | New Path |
|-----------|----------|----------|
| DAGs folder | `/opt/airflow/dags` | `/opt/containers/data/dags` |
| Logs | `/opt/airflow/logs` | `/opt/containers/logs` |
| Database | `/opt/airflow/airflow.db` | `/opt/containers/data/airflow.db` |

### pgpool-ii
| Env Var | Old Default | New Default |
|---------|------------|-------------|
| `PGPOOL_CONFIG_DIR` | `/usr/local/pgpool/etc` | `/opt/containers/config` |
| `PGPOOL_LOG_DIR` | `/var/log/pgpool` | `/opt/containers/logs` |
| `PGPOOL_RUN_DIR` | `/var/run/pgpool` | `/opt/containers/run` |

### MaxScale
| Env Var | Old Default | New Default |
|---------|------------|-------------|
| `MAXSCALE_CONFIG_DIR` | `/var/lib/maxscale` | `/opt/containers/config` |
| `MAXSCALE_DATA_DIR` | `/var/lib/maxscale/data` | `/opt/containers/data` |
| `MAXSCALE_LOG_DIR` | `/var/log/maxscale` | `/opt/containers/logs` |

### WordPress
| Component | Old Path | New Path |
|-----------|----------|----------|
| Content mount | `/content` | `/opt/containers/data` (with `/content` symlink for backward compatibility) |

```yaml
# Old:
volumes:
  - ./data/wordpress:/content

# New:
volumes:
  - ./data/wordpress:/opt/containers/data
```

## Rollback

If you need to revert, set the relevant environment variables to the old default values explicitly:

```yaml
environment:
  PGDATA: /usr/local/pgsql/data
  PROMETHEUS_DATA_DIR: /opt/prometheus/data
  MARIADB_DATA_DIR: /var/lib/mysql
  # ... etc.
```

This allows you to keep existing volume mounts while running the updated container image.
