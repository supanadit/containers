# Container Configuration: Citus PostgreSQL Support

**Date**: October 1, 2025  
**Scope**: Configuration options for Citus extension in PostgreSQL container

## Environment Variables

### Citus Enablement
- `CITUS_ENABLE`: Enable Citus extension (default: `false`)
  - Values: `true`/`false`
  - When `true`, loads Citus extension and configures distributed database

### Citus Role Configuration
- `CITUS_ROLE`: Node role in Citus cluster (default: `coordinator`)
  - Values: `coordinator`/`worker`
  - `coordinator`: Manages metadata and coordinates queries
  - `worker`: Stores distributed data and executes local queries

### Citus Network Configuration
- `CITUS_COORDINATOR_HOST`: Hostname/IP of Citus coordinator (default: `localhost`)
  - Used by worker nodes to connect to coordinator
  - For standalone mode, should be `localhost` or container hostname

- `CITUS_COORDINATOR_PORT`: Port of Citus coordinator (default: `5432`)
  - PostgreSQL port on coordinator node
  - Must match exposed port configuration

## PostgreSQL Configuration Changes

When `CITUS_ENABLE=true`, the following are automatically added to `postgresql.conf`:

```
shared_preload_libraries = 'citus'
citus.max_worker_processes = 8
citus.distributed_executor = 'adaptive'
```

## Usage Examples

### Standalone Citus
```bash
docker run -e CITUS_ENABLE=true -e POSTGRES_PASSWORD=mypass postgres:13
```

### Citus Coordinator
```bash
docker run -e CITUS_ENABLE=true \
           -e CITUS_ROLE=coordinator \
           -e POSTGRES_PASSWORD=mypass \
           postgres:13
```

### Citus Worker
```bash
docker run -e CITUS_ENABLE=true \
           -e CITUS_ROLE=worker \
           -e CITUS_COORDINATOR_HOST=coordinator.example.com \
           -e POSTGRES_PASSWORD=mypass \
           postgres:13
```

## Patroni Integration

When using with Patroni for high availability:

### Coordinator Configuration
```yaml
# patroni.yml
citus:
  enable: true
  role: coordinator
```

### Worker Configuration
```yaml
# patroni.yml
citus:
  enable: true
  role: worker
  coordinator_host: patroni-cluster.example.com
```

## Security Configuration

- Citus uses PostgreSQL's authentication system
- Inter-node communication requires proper user permissions
- Coordinator should have `citus` superuser or appropriate grants
- Workers need connection permissions to coordinator

## Monitoring Configuration

Citus exposes additional metrics through PostgreSQL statistics:
- `pg_dist_*` tables for cluster metadata
- Citus-specific system views
- Distributed query performance metrics

## Default Values Summary

| Variable | Default | Description |
|----------|---------|-------------|
| CITUS_ENABLE | false | Enable Citus extension |
| CITUS_ROLE | coordinator | Node role |
| CITUS_COORDINATOR_HOST | localhost | Coordinator hostname |
| CITUS_COORDINATOR_PORT | 5432 | Coordinator port |