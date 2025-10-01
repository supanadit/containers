# Container Dockerfile Design: Citus PostgreSQL Support

**Date**: October 1, 2025  
**Designer**: GitHub Copilot  
**Scope**: Modifications to enable Citus extension in PostgreSQL container

## Current Dockerfile Analysis

The existing Dockerfile uses multi-stage builds:
- **base**: Debian Bookworm with build args
- **setup**: Installs PostgreSQL, Citus, Patroni, and dependencies
- **runtime**: Configures entrypoint and runtime environment

Citus 11.3.1 is already installed during setup phase via `05-install-citus.sh`.

## Proposed Modifications

### Environment Variables
Add Citus-specific environment variables in runtime stage:

```dockerfile
ENV CITUS_ENABLE=${CITUS_ENABLE:-false} \
    CITUS_ROLE=${CITUS_ROLE:-coordinator} \
    CITUS_COORDINATOR_HOST=${CITUS_COORDINATOR_HOST:-localhost} \
    CITUS_COORDINATOR_PORT=${CITUS_COORDINATOR_PORT:-5432}
```

### Entrypoint Script Modifications

Modify `/opt/container/entrypoint.d/scripts/init/03-config.sh` to:

1. Check `CITUS_ENABLE=true`
2. Add `shared_preload_libraries = 'citus'` to postgresql.conf
3. Set Citus-specific configurations based on role
4. Initialize Citus extension on first startup

### Citus Configuration Logic

For **Coordinator Role**:
```sql
CREATE EXTENSION IF NOT EXISTS citus;
SELECT citus_set_coordinator_host('${CITUS_COORDINATOR_HOST}', ${CITUS_COORDINATOR_PORT});
```

For **Worker Role**:
```sql
CREATE EXTENSION IF NOT EXISTS citus;
SELECT citus_add_node('${CITUS_COORDINATOR_HOST}', ${CITUS_COORDINATOR_PORT});
```

### Standalone Mode Handling
When `CITUS_ROLE=coordinator` and no external coordinator specified, configure as self-coordinating node.

### Patroni Integration
- Ensure Citus configuration persists across Patroni failovers
- Use Patroni callbacks for Citus role changes
- Store Citus metadata in persistent volume

## Build Optimization

### Layer Caching
- Citus installation already in setup stage (stable)
- Runtime configuration in entrypoint (volatile)
- No additional dependencies required

### Image Size Impact
- Citus already installed: ~50MB additional
- No significant size increase for enablement logic
- Maintains <500MB target

## Security Considerations

- Citus inter-node communication uses PostgreSQL authentication
- No additional ports exposed
- Coordinator access controlled via PostgreSQL users
- Worker nodes isolated by network policies

## Testing Strategy

### Build Verification
- Dockerfile builds successfully with Citus enabled
- Extension loads without errors
- Basic Citus functions work

### Runtime Testing
- Standalone mode: create distributed table
- Cluster mode: coordinator/worker communication
- Patroni failover: Citus metadata preservation

## Rollback Plan

- Citus disabled by default (`CITUS_ENABLE=false`)
- Existing functionality unchanged when disabled
- Can disable Citus by setting environment variable
- No breaking changes to current deployments