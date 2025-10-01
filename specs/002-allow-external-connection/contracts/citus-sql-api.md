# Citus SQL API Contract

This document defines the SQL API contract for Citus distributed PostgreSQL functionality in the container.

## Overview

The Citus extension provides distributed database capabilities through standard PostgreSQL SQL commands. This contract ensures consistent behavior across standalone and Patroni-integrated deployments.

## Extension Management

### Creating Citus Extension

```sql
-- Create Citus extension (required for all Citus functionality)
CREATE EXTENSION citus;
```

**Contract:**
- Extension must be created before using any Citus functions
- Only superuser can create the extension
- Extension creation is idempotent (can be run multiple times safely)

### Verifying Citus Installation

```sql
-- Check Citus version
SELECT citus_version();

-- List available Citus functions
SELECT * FROM pg_proc WHERE proname LIKE 'citus_%' LIMIT 10;
```

## Node Management

### Adding Worker Nodes

```sql
-- Add a worker node to the cluster
SELECT * FROM citus_add_node('worker-host', 5432);

-- Add node with custom options
SELECT * FROM citus_add_node(
    node_name => 'worker-host',
    node_port => 5432,
    node_type => 'worker',
    group_id => 1
);
```

**Contract:**
- Coordinator only: Workers cannot add other workers
- Hostname resolution: Container must be able to resolve worker hostnames
- Port accessibility: Coordinator must be able to connect to worker port
- Idempotent: Adding existing node is safe

### Removing Worker Nodes

```sql
-- Remove a worker node
SELECT * FROM citus_remove_node('worker-host', 5432);

-- Remove node with draining
SELECT * FROM citus_remove_node(
    node_name => 'worker-host',
    node_port => 5432,
    force => false
);
```

**Contract:**
- Coordinator only
- Safe removal: Drains shards before removing
- Force option: Allows immediate removal (may lose data)

### Listing Nodes

```sql
-- Get active worker nodes
SELECT * FROM citus_get_active_worker_nodes();

-- Get all nodes (including coordinator)
SELECT * FROM pg_dist_node;
```

**Contract:**
- Returns current cluster topology
- Real-time: Reflects current state
- Coordinator included: When applicable

## Table Distribution

### Creating Distributed Tables

```sql
-- Create a hash-distributed table
CREATE TABLE distributed_table (
    id serial PRIMARY KEY,
    data text
);

-- Distribute the table
SELECT create_distributed_table('distributed_table', 'id');

-- Create with specific shard count
SELECT create_distributed_table(
    table_name => 'distributed_table',
    distribution_column => 'id',
    shard_count => 32
);
```

**Contract:**
- Distribution column: Must be part of primary key or have unique constraint
- Shard count: Default 32, configurable
- Automatic: Creates shards and places them on workers

### Creating Reference Tables

```sql
-- Create a reference table (replicated on all nodes)
CREATE TABLE reference_table (
    id serial PRIMARY KEY,
    name text
);

-- Make it a reference table
SELECT create_reference_table('reference_table');
```

**Contract:**
- Replicated: Copy exists on all nodes
- Consistent: Changes propagate to all nodes
- Small tables: Intended for lookup/dimension tables

### Checking Table Distribution

```sql
-- List distributed tables
SELECT * FROM citus_tables;

-- Get shard information
SELECT * FROM citus_shards;

-- Get shard placement
SELECT * FROM citus_shard_placements;
```

## Query Execution

### Distributed Queries

```sql
-- Insert into distributed table (routes to appropriate shard)
INSERT INTO distributed_table (data) VALUES ('example');

-- Query distributed table (parallel execution)
SELECT COUNT(*) FROM distributed_table;

-- Join distributed tables (co-located on same nodes)
SELECT d.data, r.name
FROM distributed_table d
JOIN reference_table r ON d.ref_id = r.id;
```

**Contract:**
- Transparent: SQL syntax unchanged
- Parallel: Queries executed across multiple nodes
- Optimized: Co-location for joins when possible

### Coordinator-Only Queries

```sql
-- Metadata queries (coordinator only)
SELECT * FROM citus_stat_statements;

-- Cluster management (coordinator only)
SELECT citus_rebalance_table_shards('distributed_table');
```

**Contract:**
- Metadata access: Only on coordinator
- Management operations: Coordinator-only
- Worker isolation: Workers don't have full metadata

## Maintenance Operations

### Rebalancing Shards

```sql
-- Rebalance shards across workers
SELECT rebalance_table_shards('distributed_table');

-- Rebalance with options
SELECT rebalance_table_shards(
    table_name => 'distributed_table',
    threshold => 0.1,
    max_shard_moves => 10
);
```

**Contract:**
- Online: No downtime required
- Threshold-based: Only moves when imbalance exceeds threshold
- Safe: Preserves data consistency

### Vacuum and Analyze

```sql
-- Vacuum distributed table
VACUUM distributed_table;

-- Analyze distributed table
ANALYZE distributed_table;
```

**Contract:**
- Distributed: Operation runs on all relevant shards
- Standard SQL: Same syntax as regular PostgreSQL
- Performance: Maintains query optimization

## Monitoring and Statistics

### Citus Statistics

```sql
-- Query execution statistics
SELECT * FROM citus_stat_statements;

-- Worker node activity
SELECT * FROM citus_worker_stat_activity;

-- Distributed query statistics
SELECT * FROM citus_query_stats;
```

**Contract:**
- Real-time: Current statistics
- Comprehensive: Covers distributed operations
- Compatible: Similar to PostgreSQL statistics

### Health Checks

```sql
-- Check node connectivity
SELECT count(*) FROM citus_get_active_worker_nodes();

-- Verify shard health
SELECT * FROM citus_shard_sizes() WHERE size < 0;
```

**Contract:**
- Connectivity: Verifies network connectivity
- Data integrity: Checks for corrupted shards
- Performance: Monitors shard sizes

## Error Handling

### Common Error Codes

- `XX000`: Citus internal errors
- `42704`: Object not found in Citus metadata
- `23505`: Unique constraint violations across shards
- `08006`: Connection failures to worker nodes

### Error Recovery

```sql
-- Retry failed operations
-- Most Citus operations are idempotent and can be retried

-- Check failed placements
SELECT * FROM citus_shard_placements WHERE placement_state != 1;
```

**Contract:**
- Idempotent: Safe to retry operations
- State tracking: Failed operations are tracked
- Recovery: Automatic recovery for transient failures

## Performance Considerations

### Query Optimization

```sql
-- Use distribution column in WHERE clauses
SELECT * FROM distributed_table WHERE id = 123; -- Fast (single shard)

-- Avoid cross-shard joins when possible
SELECT * FROM distributed_table d1
JOIN distributed_table d2 ON d1.id = d2.ref_id; -- May be slow
```

**Contract:**
- Distribution awareness: Queries using distribution column are optimized
- Co-location: Tables distributed on same column can join efficiently
- Statistics: ANALYZE maintains accurate statistics for query planning

### Connection Pooling

```sql
-- Citus recommends connection pooling for high concurrency
-- Use pgbouncer or similar for connection management
```

**Contract:**
- Connection limits: Each worker connection consumes resources
- Pooling recommended: For high-throughput applications
- Monitoring: Track connection usage per node

## Migration and Upgrades

### Data Migration

```sql
-- Migrate existing table to distributed
-- Note: Requires careful planning for large tables

-- Create distributed table from existing data
CREATE TABLE new_distributed AS SELECT * FROM existing_table;
SELECT create_distributed_table('new_distributed', 'id');
```

**Contract:**
- Offline migration: May require downtime for large tables
- Schema compatibility: Existing constraints must be compatible
- Rollback: Plan for rollback if migration fails

### Version Compatibility

```sql
-- Check Citus version compatibility
SELECT citus_version();

-- Verify extension compatibility
SELECT * FROM pg_extension WHERE extname = 'citus';
```

**Contract:**
- Version checking: Always verify version compatibility
- Upgrade path: Follow Citus upgrade documentation
- Testing: Test applications after upgrades

## Security Considerations

### Access Control

```sql
-- Citus respects PostgreSQL permissions
-- Grant permissions on distributed tables as usual

GRANT SELECT ON distributed_table TO readonly_user;
```

**Contract:**
- Permission inheritance: Same as regular PostgreSQL tables
- Distributed enforcement: Permissions enforced across all nodes
- Superuser requirements: Some operations require superuser

### Network Security

```sql
-- Secure worker-coordinator communication
-- Use SSL/TLS for encrypted connections

-- Configure in postgresql.conf
ssl = on
ssl_cert_file = '/path/to/server.crt'
ssl_key_file = '/path/to/server.key'
```

**Contract:**
- Encryption: Enable SSL for production deployments
- Authentication: Use strong authentication methods
- Network isolation: Isolate cluster network when possible