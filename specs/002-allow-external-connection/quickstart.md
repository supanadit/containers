# Quickstart: PostgreSQL with External Access

## Basic Usage
```bash
docker run -d \
  -e POSTGRESQL_PASSWORD=mypassword \
  -p 5432:5432 \
  postgresql:latest
```
Default: External access enabled with md5 auth.

## Disable External Access
```bash
docker run -d \
  -e EXTERNAL_ACCESS_ENABLE=false \
  -e POSTGRESQL_PASSWORD=mypassword \
  postgresql:latest
```

## Custom Authentication Method
```bash
docker run -d \
  -e EXTERNAL_ACCESS_METHOD=password \
  -e POSTGRESQL_PASSWORD=mypassword \
  -p 5432:5432 \
  postgresql:latest
```

## With Data Persistence
```bash
docker run -d \
  -v postgres_data:/var/lib/postgresql/data \
  -e POSTGRESQL_PASSWORD=mypassword \
  -p 5432:5432 \
  postgresql:latest
```

## Health Check
```bash
docker exec container_id /opt/container/entrypoint.d/scripts/runtime/healthcheck.sh
```

## Troubleshooting
- If connections fail: Check EXTERNAL_ACCESS_ENABLE=true
- Invalid method: Falls back to md5, check logs
- Port not accessible: Ensure -p 5432:5432

## Citus Distributed Database

### Standalone Citus
```bash
docker run -d \
  -e CITUS_ENABLE=true \
  -e POSTGRESQL_PASSWORD=mypassword \
  -p 5432:5432 \
  postgresql:latest
```

### Citus Coordinator
```bash
docker run -d \
  -e CITUS_ENABLE=true \
  -e CITUS_ROLE=coordinator \
  -e POSTGRESQL_PASSWORD=mypassword \
  -p 5432:5432 \
  --name citus-coordinator \
  postgresql:latest
```

### Citus Worker
```bash
docker run -d \
  -e CITUS_ENABLE=true \
  -e CITUS_ROLE=worker \
  -e CITUS_COORDINATOR_HOST=citus-coordinator \
  -e POSTGRESQL_PASSWORD=mypassword \
  -p 5433:5432 \
  --link citus-coordinator \
  postgresql:latest
```

### Citus with Patroni
```bash
# Coordinator
docker run -d \
  -e CITUS_ENABLE=true \
  -e CITUS_ROLE=coordinator \
  -e USE_PATRONI=true \
  -e PATRONI_NAME=citus-coord \
  -e POSTGRESQL_PASSWORD=mypassword \
  -p 5432:5432 \
  postgresql:latest

# Worker
docker run -d \
  -e CITUS_ENABLE=true \
  -e CITUS_ROLE=worker \
  -e USE_PATRONI=true \
  -e CITUS_COORDINATOR_HOST=host.docker.internal \
  -e PATRONI_NAME=citus-worker \
  -e POSTGRESQL_PASSWORD=mypassword \
  -p 5433:5432 \
  postgresql:latest
```

### Using Citus
```bash
# Connect to coordinator
psql -h localhost -p 5432 -U postgres

# Create extension
CREATE EXTENSION citus;

# Create distributed table
CREATE TABLE events (
    id serial PRIMARY KEY,
    user_id int,
    event_time timestamp,
    data jsonb
);

# Distribute table
SELECT create_distributed_table('events', 'user_id');

# Insert data
INSERT INTO events (user_id, event_time, data)
VALUES (1, now(), '{"action": "login"}');

# Query distributed data
SELECT user_id, count(*) FROM events GROUP BY user_id;
```

### Citus Health Check
```bash
# Check Citus status
docker exec citus-coordinator /opt/container/entrypoint.d/scripts/runtime/healthcheck.sh citus

# List worker nodes
docker exec citus-coordinator psql -U postgres -c "SELECT * FROM citus_get_active_worker_nodes();"
```

### Citus Troubleshooting
- Extension not loading: Check CITUS_ENABLE=true
- Worker connection fails: Verify network connectivity and CITUS_COORDINATOR_HOST
- Distributed queries slow: Check shard distribution and co-location
- Patroni failover issues: Ensure metadata persistence and advisory locks