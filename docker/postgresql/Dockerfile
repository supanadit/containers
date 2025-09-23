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
      org.opencontainers.image.description="Optimized PostgreSQL container with Patroni, pgBackRest, and Citus"

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

ENV PATH="/usr/local/pgsql/bin:/opt/bats/bin:$PATH"

# Runtime layer - copy volatile files later
FROM setup AS runtime
# Create postgres user for security (already created in setup stage)

# Copy entrypoint scripts (volatile files that change frequently during development)
COPY entrypoint.d/ /opt/container/entrypoint.d/

# Make all entrypoint scripts executable first
RUN find /opt/container/entrypoint.d/ -name "*.sh" -exec chmod +x {} \;

# Install BATS testing framework (depends on entrypoint scripts)
# Temporarily disabled for faster builds - can be enabled when needed
# RUN /opt/container/entrypoint.d/scripts/test/bats/install_bats.sh && \
#     rm -rf /tmp/bats-*

# Copy main entrypoint script
COPY entrypoint.d/entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# Set proper ownership
RUN chown -R postgres:postgres /opt/container/ && \
    chmod -R 755 /opt/container/

# Create data directory with proper permissions
RUN mkdir -p /var/lib/postgresql/data && \
    chown -R postgres:postgres /var/lib/postgresql && \
    chmod 700 /var/lib/postgresql/data

# Environment variables for runtime configuration
ENV POSTGRES_USER=postgres \
    POSTGRES_DB=postgres \
    PGDATA=/var/lib/postgresql/data \
    POSTGRES_INITDB_ARGS="" \
    POSTGRES_INITDB_WALDIR="" \
    POSTGRES_HOST_AUTH_METHOD=trust \
    USE_PATRONI=false \
    LOG_LEVEL=INFO

# Set the stop signal for proper container shutdown
STOPSIGNAL SIGTERM

# Health check configuration
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD /opt/container/entrypoint.d/scripts/runtime/healthcheck.sh || exit 1

# Switch to postgres user for security (handled in entrypoint)

# Expose PostgreSQL port
EXPOSE 5432

ENTRYPOINT ["/entrypoint.sh"]