# Container Research: Citus PostgreSQL Support

**Date**: October 1, 2025  
**Researcher**: GitHub Copilot  
**Scope**: Enabling Citus distributed database extension in PostgreSQL container

## Citus Extension Overview

Citus is a PostgreSQL extension that transforms PostgreSQL into a distributed database, enabling horizontal scaling across multiple nodes while maintaining SQL compatibility.

### Key Components
- **Coordinator Node**: Manages metadata, distributes queries, coordinates transactions
- **Worker Nodes**: Store distributed table data, execute queries on local shards
- **Distributed Tables**: Tables partitioned across worker nodes
- **Reference Tables**: Replicated on all nodes for joins

### Architecture Patterns
1. **Single-Node (Standalone)**: All roles on one instance for development/testing
2. **Multi-Node Cluster**: Separate coordinator and worker instances
3. **High-Availability**: Multiple coordinators with failover, worker redundancy

## Integration with Existing Container

### Current PostgreSQL Setup
- Base: Debian Bookworm
- PostgreSQL 13.5 with Citus 11.3.1 pre-installed
- Patroni v3.0.2 for HA clustering
- pgBackRest for backup/restore
- Python 3.11.2 for scripting

### Citus Enablement Strategy
- Extension already installed via setup scripts
- Need runtime activation via `CREATE EXTENSION citus;`
- Configuration through postgresql.conf and citus-specific settings
- Environment variable control: `CITUS_ENABLE=true`

### Standalone Mode
- Single container instance
- Citus runs in coordinator-only mode
- All data local, but distributed table support enabled
- Suitable for development, testing, small-scale production

### Patroni Integration Mode
- Multi-container cluster with Patroni
- Coordinator role on Patroni primary
- Worker roles on additional instances
- Automatic failover requires Citus metadata synchronization
- Complex: Patroni manages PostgreSQL failover, Citus manages data distribution

## Configuration Requirements

### Environment Variables
- `CITUS_ENABLE`: Enable/disable Citus (default: false)
- `CITUS_ROLE`: coordinator/worker (default: coordinator for standalone)
- `CITUS_COORDINATOR_HOST`: Coordinator hostname/IP
- `CITUS_COORDINATOR_PORT`: Coordinator port (default: 5432)

### PostgreSQL Configuration
- `shared_preload_libraries = 'citus'`
- `citus.max_worker_processes = <num_workers>`
- `citus.distributed_executor = 'task-tracker'` (or adaptive)

### Networking
- All nodes communicate on PostgreSQL port (5432)
- Workers connect to coordinator for metadata
- No additional ports required beyond PostgreSQL

## Implementation Challenges

### Standalone Mode
- Simple: enable extension on startup
- Initialize Citus metadata tables
- Configure as self-coordinating node

### Patroni + Citus Mode
- Patroni failover must preserve Citus role
- Coordinator metadata must survive failovers
- Workers must reconnect to new coordinator
- Potential split-brain scenarios
- Patroni DCS (etcd/consul) for Citus coordination?

### Data Persistence
- Citus metadata in pg_dist_* tables
- Must persist across restarts/failovers
- Workers need access to shared schemas

### Security
- Inter-node authentication
- Coordinator access control
- Worker node isolation

## Research Findings

### Citus Documentation
- Official docs recommend separate coordinator/worker for production
- Standalone mode for development only
- Patroni integration possible but requires careful configuration
- Citus 11.3.1 compatible with PostgreSQL 13.5

### Best Practices
- Use reference tables for dimension data
- Distribute fact tables by appropriate key
- Monitor coordinator performance
- Plan for coordinator as bottleneck

### Compatibility
- All existing PostgreSQL features preserved
- Patroni continues to work for HA
- pgBackRest can backup distributed data
- Monitoring tools need Citus awareness

## Recommendations

1. **Enable via Environment**: `CITUS_ENABLE=true` to activate
2. **Role-Based Configuration**: Support coordinator/worker roles
3. **Standalone First**: Implement standalone mode initially
4. **Patroni Integration**: Add cluster mode with proper failover handling
5. **Documentation**: Clear usage examples for both modes
6. **Testing**: Validate distributed queries, failover scenarios

## Open Questions
- How to handle Citus metadata during Patroni failover?
- Worker auto-discovery in dynamic clusters?
- Performance impact on existing workloads?
- Backup/restore procedures for distributed data?