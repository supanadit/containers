# Multi-stage build for PostgreSQL with optimized layer caching
# syntax=docker/dockerfile:1.4
FROM debian:bookworm AS base

ARG POSTGRESQL_VERSION=13.5
ARG PGAUDIT_VERSION=1.5.3
ARG PGBACKREST_VERSION=2.58.0
ARG CITUS_VERSION=11.3.1
ARG PG_STAT_MONITOR_VERSION=2.3.1
ARG DECODERBUFS_VERSION=v3.4.1.Final
ARG PYTHON_VERSION=v3.13.9
ARG PATRONI_VERSION=v4.1.0
ARG HYPO_PG_VERSION=1.4.2
ARG DEXTER_VERSION=v0.6.3
ARG PGMETRICS_VERSION=1.18.0
ARG PGREPACK_VERSION=1.5.3
ARG PG_CRON_VERSION=1.6.7

# Build metadata
ARG BUILD_DATE
ARG VCS_REF

LABEL org.opencontainers.image.created=$BUILD_DATE \
    org.opencontainers.image.revision=$VCS_REF \
    org.opencontainers.image.title="PostgreSQL with Build Optimization" \
    org.opencontainers.image.description="Optimized PostgreSQL container with Patroni, pgBackRest, and Citus" \
    org.opencontainers.image.authors="Supan Adit Pratama <email@supanadit.com>" \
    org.opencontainers.image.source=https://github.com/supanadit/containers

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

# Set proper ownership
RUN chown -R postgres:postgres /opt/container/ && \
    chmod -R 755 /opt/container/

# Install the EZX entrypoint engine (release binary, checksum-verified).
# curl stays in the image: it is the binary child used by the Patroni
# role-change poller and operator curl to the health server.
ARG EZX_VERSION=0.1.1
ARG TARGETARCH
RUN apt-get update && apt-get install -y --no-install-recommends curl ca-certificates \
    && curl -fsSL https://github.com/supanadit/ezx/releases/download/${EZX_VERSION}/ezx-${EZX_VERSION}-linux-${TARGETARCH} -o /tmp/ezx-${EZX_VERSION}-linux-${TARGETARCH} \
    && curl -fsSL https://github.com/supanadit/ezx/releases/download/${EZX_VERSION}/ezx-${EZX_VERSION}-linux-${TARGETARCH}.sha256 -o /tmp/ezx.sha256 \
    && (cd /tmp && sha256sum -c ezx.sha256) \
    && mv /tmp/ezx-${EZX_VERSION}-linux-${TARGETARCH} /usr/local/bin/ezx \
    && chmod +x /usr/local/bin/ezx \
    && rm -f /tmp/ezx.sha256 \
    && rm -rf /var/lib/apt/lists/*

# Set the stop signal for proper container shutdown
STOPSIGNAL SIGTERM

# Health check: pg_isready (PostgreSQL is accepting connections)
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD pg_isready -h 127.0.0.1 -p 5432 -U postgres -d postgres || exit 1

# Expose PostgreSQL and PgBouncer ports
EXPOSE 5432 6432

ENTRYPOINT ["/usr/local/bin/ezx", "bootstrap", "/opt/container/entrypoint.d/bootstrap/main.js"]