# Container Quickstart: Citus PostgreSQL Support

**Date**: October 1, 2025  
**Scope**: Getting started with Citus-enabled PostgreSQL container

## Prerequisites

- Docker installed and running
- Basic understanding of PostgreSQL and distributed databases
- For cluster mode: Docker Compose or orchestration platform

## Standalone Citus (Single Node)

### Basic Setup
```bash
# Run PostgreSQL with Citus enabled
docker run -d \
  --name postgres-citus \
  -e POSTGRES_PASSWORD=mypass \
  -e CITUS_ENABLE=true \
  -p 5432:5432 \
  postgres:13

# Connect to database
psql -h localhost -U postgres -d postgres
```

### Create Distributed Table
```sql
-- Citus is already enabled
SELECT citus_version();

-- Create a distributed table
CREATE TABLE events (
  id bigserial,
  user_id int,
  event_time timestamp,
  data jsonb
);

-- Distribute by user_id
SELECT create_distributed_table('events', 'user_id');

-- Insert some data
INSERT INTO events (user_id, event_time, data)
VALUES (1, now(), '{"action": "login"}'),
       (2, now(), '{"action": "signup"}'),
       (1, now(), '{"action": "view"}');

-- Query distributed data
SELECT user_id, count(*) FROM events GROUP BY user_id;
```

## Citus Cluster (Multi-Node)

### Using Docker Compose

Create `docker-compose.yml`:
```yaml
version: '3.8'
services:
  coordinator:
    image: postgres:13
    environment:
      POSTGRES_PASSWORD: mypass
      CITUS_ENABLE: true
      CITUS_ROLE: coordinator
    ports:
      - "5432:5432"
    volumes:
      - coordinator_data:/var/lib/postgresql/data

  worker1:
    image: postgres:13
    environment:
      POSTGRES_PASSWORD: mypass
      CITUS_ENABLE: true
      CITUS_ROLE: worker
      CITUS_COORDINATOR_HOST: coordinator
    depends_on:
      - coordinator
    volumes:
      - worker1_data:/var/lib/postgresql/data

  worker2:
    image: postgres:13
    environment:
      POSTGRES_PASSWORD: mypass
      CITUS_ENABLE: true
      CITUS_ROLE: worker
      CITUS_COORDINATOR_HOST: coordinator
    depends_on:
      - coordinator
    volumes:
      - worker2_data:/var/lib/postgresql/data

volumes:
  coordinator_data:
  worker1_data:
  worker2_data:
```

### Start the Cluster
```bash
docker-compose up -d
```

### Configure Workers
Connect to coordinator and add workers:
```bash
# Connect to coordinator
psql -h localhost -U postgres -d postgres

# Add worker nodes
SELECT citus_add_node('worker1', 5432);
SELECT citus_add_node('worker2', 5432);

-- Verify cluster
SELECT * FROM citus_get_active_worker_nodes();
```

### Create Distributed Table
```sql
-- Create distributed table (will be sharded across workers)
CREATE TABLE user_sessions (
  session_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id int,
  start_time timestamp,
  end_time timestamp
);

-- Distribute across workers
SELECT create_distributed_table('user_sessions', 'user_id');

-- Create reference table (replicated on all nodes)
CREATE TABLE users (
  id int PRIMARY KEY,
  name text,
  email text
);

SELECT create_reference_table('users');
```

## Citus with Patroni (High Availability)

### Patroni Configuration for Coordinator
```yaml
# patroni.yml for coordinator
scope: citus-cluster
name: coordinator1

bootstrap:
  dcs:
    postgresql:
      parameters:
        shared_preload_libraries: citus
      pg_hba:
        - host all all 0.0.0.0/0 md5

citus:
  enable: true
  role: coordinator
```

### Patroni Configuration for Worker
```yaml
# patroni.yml for worker
scope: citus-cluster
name: worker1

citus:
  enable: true
  role: worker
  coordinator_host: coordinator1.example.com
```

## Monitoring and Troubleshooting

### Check Citus Status
```sql
-- Citus version
SELECT citus_version();

-- Active workers
SELECT * FROM citus_get_active_worker_nodes();

-- Distributed tables
SELECT * FROM citus_tables;

-- Query statistics
SELECT * FROM citus_stat_statements;
```

### Common Issues

**Worker cannot connect to coordinator:**
- Check network connectivity
- Verify CITUS_COORDINATOR_HOST and port
- Ensure PostgreSQL authentication allows connection

**Extension not loaded:**
- Confirm CITUS_ENABLE=true
- Check PostgreSQL logs for extension loading errors
- Verify Citus installation

**Distributed queries slow:**
- Check coordinator resource usage
- Verify network latency between nodes
- Consider reference table usage for joins

## Next Steps

- Read Citus documentation for advanced features
- Explore distributed table partitioning strategies
- Set up monitoring for cluster performance
- Plan backup/restore procedures for distributed data