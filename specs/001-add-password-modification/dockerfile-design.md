# Dockerfile Design: postgresql

## Multi-stage Build Strategy

### Stage 1: base
```dockerfile
FROM debian:bookworm AS base
```
**Purpose**: Define build arguments and metadata
**Contents**: ARG declarations for versions, LABEL metadata
**Caching**: Stable layer, changes infrequently

### Stage 2: setup
```dockerfile
FROM base AS setup
COPY setup.sh /opt/setup.sh
COPY setup/ /opt/setup/
RUN --mount=type=cache,target=/var/cache/apt \
    --mount=type=cache,target=/var/lib/apt \
    chmod +x /opt/setup.sh && \
    /opt/setup.sh && \
    rm /opt/setup.sh && \
    rm -rf /opt/setup/
```
**Purpose**: Install and compile all dependencies
**Contents**: PostgreSQL, Patroni, extensions, Python
**Caching**: Optimized with cache mounts for apt
**Cleanup**: Remove setup scripts and temporary files

### Stage 3: runtime
```dockerfile
FROM setup AS runtime
COPY entrypoint.d/ /opt/container/entrypoint.d/
RUN chown -R postgres:postgres /opt/container/ && \
    chmod -R 755 /opt/container/
COPY entrypoint.d/entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh
```
**Purpose**: Final runtime image
**Contents**: Only runtime components, entrypoint scripts
**Security**: Proper ownership and permissions
**Size**: Minimal by excluding build dependencies

## Base Image Justification
**debian:bookworm** selected for:
- Excellent PostgreSQL ecosystem compatibility
- Reliable security updates
- Long-term support (LTS)
- Package availability for all required extensions

## Build Dependencies vs Runtime Dependencies
**Build Dependencies** (setup stage only):
- build-essential, gcc, make
- PostgreSQL source and extension sources
- Development libraries

**Runtime Dependencies** (runtime stage):
- PostgreSQL binaries
- Patroni, Citus runtime
- Python runtime
- glibc, essential libraries

## Layer Optimization and Caching Strategy
1. **Stable layers first**: Base image, ARG declarations
2. **Cached setup**: Apt cache mounts, setup scripts copied early
3. **Volatile layers last**: Entrypoint scripts copied after setup
4. **Cleanup in setup**: Build artifacts removed before runtime stage

## User Creation and Permission Model
- **postgres user**: Created during setup stage
- **Permissions**: /opt/container/ owned by postgres:postgres
- **Runtime**: Container runs as postgres user (implied by USER directive if present)
- **Security**: No root access at runtime

## Working Directory and File System Layout
- **Working Directory**: / (default)
- **PostgreSQL Data**: /var/lib/postgresql/data (volume)
- **Config**: /etc/postgresql/ (generated)
- **Entrypoint Scripts**: /opt/container/entrypoint.d/
- **Logs**: /var/log/postgresql/

## Health Check Implementation
```dockerfile
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD /opt/container/entrypoint.d/scripts/runtime/healthcheck.sh || exit 1
```
- **Interval**: 30 seconds
- **Timeout**: 10 seconds
- **Start Period**: 60 seconds (allows initialization)
- **Retries**: 3

## Port Exposure
```dockerfile
EXPOSE 5432
```
- **Protocol**: TCP
- **Purpose**: PostgreSQL client connections
- **Security**: No automatic host binding

## Entrypoint Configuration
```dockerfile
ENTRYPOINT ["/entrypoint.sh"]
STOPSIGNAL SIGTERM
```
- **Entrypoint**: Custom script handling initialization
- **Stop Signal**: SIGTERM for graceful shutdown