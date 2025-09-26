# Dockerfile Design: PostgreSQL External Access

## Multi-stage Build Strategy
- **base**: debian:bookworm with build args for versions
- **setup**: Install all dependencies, PostgreSQL, extensions, cleanup
- **runtime**: Copy entrypoint scripts, set user, expose ports

## Base Image Justification
- debian:bookworm: Stable, secure, compatible with PostgreSQL ecosystem
- Security: Regular updates, no known vulnerabilities in chosen version

## Build Dependencies vs Runtime Dependencies
- **Build**: gcc, make, python-dev, postgresql-dev for extensions
- **Runtime**: postgresql, patroni, python, minimal libs
- **Cleanup**: Remove build tools and caches in setup stage

## Layer Optimization and Caching
- Stable files (setup.sh, setup/) copied early for caching
- Volatile files (entrypoint.d/) copied late
- BuildKit mounts for apt cache to speed up rebuilds

## User Creation and Permission Model
- postgres user created in setup stage
- Ownership set for /opt/container/ and data directories
- Non-root execution for security

## Working Directory and File System Layout
- /usr/local/pgsql/: PostgreSQL installation
- /opt/container/: Entrypoint scripts and configs
- /var/lib/postgresql/: Data directory (volume)
- /etc/postgresql/: Config files

## Feature-Specific Modifications
- No Dockerfile changes required - external access handled in entrypoint scripts
- pg_hba.conf template prepared for runtime modification</content>
<parameter name="filePath">/home/supanadit/Workspaces/Personal/Docker/containers/specs/002-allow-external-connection/dockerfile-design.md