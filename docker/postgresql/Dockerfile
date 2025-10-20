# Multi-stage build for PostgreSQL with optimized layer caching
# syntax=docker/dockerfile:1.4
FROM debian:bookworm AS base

ARG POSTGRESQL_VERSION=13.5
ARG PGBACKREST_VERSION=2.56.0
ARG CITUS_VERSION=11.3.1
ARG PG_STAT_MONITOR_VERSION=2.2.0
ARG DECODERBUFS_VERSION=v3.2.2.Final
ARG PYTHON_VERSION=v3.11.2
ARG PATRONI_VERSION=v3.0.2

# Build metadata
ARG BUILD_DATE
ARG VCS_REF

LABEL org.opencontainers.image.created=$BUILD_DATE \
    org.opencontainers.image.revision=$VCS_REF \
    org.opencontainers.image.title="PostgreSQL with Build Optimization" \
    org.opencontainers.image.description="Optimized PostgreSQL container with Patroni, pgBackRest, and Citus" \
    org.opencontainers.image.authors="Supan Adit Pratama <email@supanadit.com>"

ENV PG_CONFIG=/usr/local/pgsql/bin/pg_config

# Setup layer - copy stable files first for better caching
FROM base AS setup

# Copy setup scripts and configuration (stable files that change infrequently)
COPY setup.sh /opt/setup.sh
COPY setup/ /opt/setup/

# Run the complete setup in a single layer with BuildKit cache mounts
RUN --mount=type=cache,target=/var/cache/apt \
    --mount=type=cache,target=/var/lib/apt \
    chmod +x /opt/setup.sh && \
    /opt/setup.sh && \
    rm /opt/setup.sh && \
    rm -rf /opt/setup/

ENV PATH="/usr/local/pgsql/bin:/usr/local/pgbouncer/bin:$PATH"

# Runtime layer - copy volatile files later
FROM setup AS runtime
# Create postgres user for security (already created in setup stage)

# Copy entrypoint scripts (volatile files that change frequently during development)
COPY entrypoint.d/ /opt/container/entrypoint.d/

# Copy configuration files
COPY config/ /etc/pgbouncer/

# Set proper ownership
RUN chown -R postgres:postgres /opt/container/ && \
    chmod -R 755 /opt/container/

# Copy main entrypoint script
COPY entrypoint.d/entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# Set the stop signal for proper container shutdown
STOPSIGNAL SIGTERM

# Health check configuration
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD /opt/container/entrypoint.d/scripts/runtime/healthcheck.sh || exit 1

# Expose PostgreSQL and PgBouncer ports
EXPOSE 5432 6432

ENTRYPOINT ["/entrypoint.sh"]