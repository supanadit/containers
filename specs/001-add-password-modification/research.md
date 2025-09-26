# Container Research & Analysis: postgresql

## Base Image Decision
**Chosen**: debian:bookworm
**Rationale**: Provides excellent compatibility with PostgreSQL and its extensions (Patroni, Citus, pgBackRest). Debian's package ecosystem ensures reliable builds and security updates. Bookworm (Debian 12) offers long-term support and stability required for database containers.
**Security**: Regular security updates, minimal attack surface for database workloads.
**Size**: ~50MB base layer, acceptable for database container with ~500MB final image.
**Alternatives Considered**:
- alpine:3.18 - Rejected due to glibc compatibility issues with PostgreSQL extensions and Patroni
- ubuntu:22.04 - Rejected due to larger size (~70MB base) without significant benefits over Debian

## Build Strategy
**Multi-stage Approach**: base → setup → runtime
- **base**: Debian bookworm with build arguments
- **setup**: Dependency installation and compilation (cached layer)
- **runtime**: Final runtime image with only necessary runtime components
**Optimization Techniques**:
- BuildKit cache mounts for apt and package caches
- Early copying of stable setup scripts for better layer caching
- Cleanup of build dependencies in setup stage
- Volatile files (entrypoint scripts) copied last to avoid cache invalidation

## Security Approach
**User Configuration**: postgres user created during setup, no root access at runtime
**Hardening Measures**:
- Non-root execution
- Minimal package installation in runtime stage
- Proper file permissions on /opt/container/
- No hardcoded credentials
**Password Handling**: POSTGRES_PASSWORD environment variable will be processed securely:
- Sanitization of invalid input
- No logging of actual password values
- Secure SQL execution for password changes

## Configuration Strategy
**Environment Variables**:
- POSTGRES_PASSWORD: Database superuser password (new usage)
- TIMEOUT_CHANGE_PASSWORD: Timeout for password modification (default 5s)
- Existing: PostgreSQL configuration via env vars
**Volumes**: /var/lib/postgresql/data for data persistence
**Secrets Management**: Environment variables for sensitive data, no file-based secrets

## Monitoring & Health
**Health Check**: Existing script verifies PostgreSQL connectivity
**Logging**: Structured JSON logging with configurable levels
**Metrics**: pg_stat_monitor extension for performance monitoring
**Observability**: Patroni integration for cluster health and failover monitoring

## Alternatives Considered
**Password Setting Methods**:
- Direct SQL ALTER USER - Chosen for simplicity and reliability
- Patroni integration - Rejected as overkill for single-instance password setting
- Init script modification - Chosen as fits existing architecture

**Timeout Handling**:
- No timeout - Rejected due to potential hangs on database issues
- Configurable timeout - Chosen for flexibility and safety