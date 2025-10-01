# Container Contracts: Citus SQL API

**Date**: October 1, 2025  
**Scope**: SQL interface contracts for Citus distributed database operations

## Overview

The Citus extension extends PostgreSQL with distributed database capabilities while maintaining full SQL compatibility. All standard PostgreSQL operations work unchanged, with additional functions for distributed operations.

## Core API Contracts

### Extension Management
```sql
-- Enable Citus extension (handled automatically)
CREATE EXTENSION citus;

-- Check Citus version
SELECT citus_version();
-- Returns: "Citus 11.3.1 on PostgreSQL 13.5"
```

### Node Management
```sql
-- Add worker node
SELECT citus_add_node('worker-host', 5432);
-- Returns: void

-- Remove worker node
SELECT citus_remove_node('worker-host', 5432);
-- Returns: void

-- List active workers
SELECT * FROM citus_get_active_worker_nodes();
-- Returns: nodename, nodeport, noderack, hasmetadata, metadatasynced, isactive
```

### Distributed Tables
```sql
-- Create distributed table
SELECT create_distributed_table('table_name', 'distribution_column');
-- Returns: void

-- Create distributed table with specific method
SELECT create_distributed_table('table_name', 'distribution_column', 'hash');
-- Returns: void

-- Create reference table (replicated on all nodes)
SELECT create_reference_table('table_name');
-- Returns: void

-- Check if table is distributed
SELECT citus_table_type('table_name');
-- Returns: 'distributed' | 'reference' | 'local'
```

### Query Operations
```sql
-- Explain distributed query
EXPLAIN SELECT * FROM distributed_table WHERE id = 123;

-- Get shard information
SELECT * FROM citus_shards;
-- Returns: table_name, shardid, shard_name, citus_table_type, colocation_id, nodename, nodeport

-- Get table statistics
SELECT * FROM citus_tables;
-- Returns: table_name, citus_table_type, distribution_column, colocation_id, shard_count
```

## Data Types and Constraints

### Supported Distribution Methods
- **hash**: Even distribution using hash of distribution column
- **range**: Distribution by value ranges (less common)

### Distribution Column Requirements
- Must be present in PRIMARY KEY or UNIQUE constraints
- Cannot be updated after distribution
- Should have high cardinality for even distribution

### Limitations
- Foreign keys between distributed tables not supported
- Some DDL operations require coordinator access
- Cross-shard transactions have performance implications

## Error Handling

### Common Error Codes
- `XX000`: Citus internal errors
- `42704`: Extension not loaded
- `08006`: Cannot connect to worker
- `23505`: Distribution column violation

### Error Examples
```sql
-- Attempting to distribute without extension
CREATE TABLE test (id int);
SELECT create_distributed_table('test', 'id');
-- ERROR: extension "citus" does not exist

-- Worker connection failure
SELECT citus_add_node('unreachable-host', 5432);
-- ERROR: could not connect to worker
```

## Performance Contracts

### Query Routing
- Single-shard queries routed directly to worker
- Multi-shard queries coordinated by coordinator
- Reference table joins optimized locally

### Expected Latencies
- Local queries: Same as PostgreSQL
- Single-shard distributed: +10-50ms network overhead
- Multi-shard distributed: +100ms+ depending on shard count

### Resource Usage
- Coordinator: CPU intensive for query planning
- Workers: Storage and compute for data processing
- Network: Inter-node communication for distributed operations

## Monitoring Contracts

### System Views
```sql
-- Query statistics
SELECT * FROM citus_stat_statements;

-- Distributed query activity
SELECT * FROM citus_dist_stat_activity;

-- Lock information
SELECT * FROM citus_lock_waits;
```

### Metrics
- `citus.executor_task_count`: Number of tasks executed
- `citus.executor_total_task_time`: Total task execution time
- `citus.shard_rebalancer`: Shard rebalancing operations

## Migration Contracts

### From Standalone to Cluster
1. Add worker nodes using `citus_add_node()`
2. Rebalance existing data: `SELECT rebalance_table_shards('table_name');`
3. Update application connections to coordinator

### Schema Changes
- DDL operations must run on coordinator
- Schema changes propagate to workers automatically
- Long-running DDL may lock distributed tables

## Security Contracts

### Authentication
- Uses PostgreSQL authentication system
- Coordinator credentials required for worker connections
- SSL/TLS supported for inter-node communication

### Authorization
- `citus` superuser required for cluster management
- Standard PostgreSQL privileges apply to data access
- Row-level security supported on distributed tables