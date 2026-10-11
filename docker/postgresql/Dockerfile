# Multi-stage build for PostgreSQL.
#
# Layout: `toolchain` → `setup` → `runtime`.
#
# - `toolchain` downloads and checksum-verifies the forge builder. It depends
#   only on FORGE_VERSION / TARGETARCH, so bumping forge rebuilds a curl-sized
#   layer instead of the whole source build.
# - `setup` copies forge from `toolchain` and runs the full TOML manifest in a
#   single RUN (forge's scheduler parallelizes steps inside it). Its cache key
#   is driven by the app version args and forge.toml — the things that genuinely
#   require recompiling.
# - `runtime` downloads the ezx entrypoint engine (needed only at run time) and
#   copies the entrypoint scripts, keeping both out of the heavy setup stage.
# syntax=docker/dockerfile:1.6
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
    org.opencontainers.image.title="PostgreSQL" \
    org.opencontainers.image.description="PostgreSQL container with Patroni, pgBackRest, and Citus" \
    org.opencontainers.image.authors="Supan Adit Pratama <email@supanadit.com>" \
    org.opencontainers.image.source=https://github.com/supanadit/containers

ENV PG_CONFIG=/usr/local/pgsql/bin/pg_config

# ---------------------------------------------------------------------------
# Toolchain layer — download the forge builder (release binary,
# checksum-verified). Isolated so a FORGE_VERSION bump does not invalidate the
# source build layer below.
# ---------------------------------------------------------------------------
FROM base AS toolchain

ARG FORGE_VERSION=1.0.3
ARG TARGETARCH

# Download and verify the builder. Its own layer, keyed only on FORGE_VERSION
# and TARGETARCH.
RUN apt-get update && apt-get install -y --no-install-recommends curl ca-certificates \
    && cd /tmp \
    && curl -fsSL https://github.com/supanadit/forge/releases/download/${FORGE_VERSION}/forge-${FORGE_VERSION}-linux-${TARGETARCH} -o forge-${FORGE_VERSION}-linux-${TARGETARCH} \
    && curl -fsSL https://github.com/supanadit/forge/releases/download/${FORGE_VERSION}/forge-${FORGE_VERSION}-linux-${TARGETARCH}.sha256 -o forge.sha256 \
    && sha256sum -c forge.sha256 \
    && mv forge-${FORGE_VERSION}-linux-${TARGETARCH} /usr/local/bin/forge \
    && chmod +x /usr/local/bin/forge \
    && rm -f forge.sha256 \
    && rm -rf /var/lib/apt/lists/*

# ---------------------------------------------------------------------------
# Setup layer — reuse the prebuilt toolchain and run the full TOML manifest in
# a single layer.
# ---------------------------------------------------------------------------
FROM toolchain AS setup

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

COPY forge.toml /opt/forge.toml

# forge build shells out to apt-get install, which needs a current package
# index. The toolchain layer's index was discarded with its apt lists, so
# refresh here first.
RUN apt-get update \
    && forge build --verbose \
        --var POSTGRESQL_VERSION=${POSTGRESQL_VERSION} \
        --var PGAUDIT_VERSION=${PGAUDIT_VERSION} \
        --var PGBACKREST_VERSION=${PGBACKREST_VERSION} \
        --var CITUS_VERSION=${CITUS_VERSION} \
        --var PG_STAT_MONITOR_VERSION=${PG_STAT_MONITOR_VERSION} \
        --var DECODERBUFS_VERSION=${DECODERBUFS_VERSION} \
        --var PYTHON_VERSION=${PYTHON_VERSION} \
        --var PATRONI_VERSION=${PATRONI_VERSION} \
        --var HYPO_PG_VERSION=${HYPO_PG_VERSION} \
        --var DEXTER_VERSION=${DEXTER_VERSION} \
        --var PGMETRICS_VERSION=${PGMETRICS_VERSION} \
        --var PGREPACK_VERSION=${PGREPACK_VERSION} \
        --var PG_CRON_VERSION=${PG_CRON_VERSION} \
        /opt/forge.toml \
    && rm -f /opt/forge.toml /usr/local/bin/forge \
    && rm -rf /var/lib/apt/lists/*

ENV PATH="/usr/local/pgsql/bin:/usr/local/pgbouncer/bin:$PATH"

# ---------------------------------------------------------------------------
# Runtime layer — the ezx engine is fetched here (it is only needed at run
# time), then the entrypoint scripts are copied. Because the ezx download sits
# in its own layer above the heavy setup stage, bumping EZX_VERSION rebuilds a
# curl-sized layer instead of the whole source build, and editing entrypoint
# scripts does not re-download ezx.
# ---------------------------------------------------------------------------
FROM setup AS runtime

ARG EZX_VERSION=0.7.1
ARG TARGETARCH

# Download and verify the ezx entrypoint engine (runtime-only dependency).
RUN apt-get update && apt-get install -y --no-install-recommends curl ca-certificates \
    && cd /tmp \
    && curl -fsSL https://github.com/supanadit/ezx/releases/download/${EZX_VERSION}/ezx-${EZX_VERSION}-linux-${TARGETARCH} -o ezx-${EZX_VERSION}-linux-${TARGETARCH} \
    && curl -fsSL https://github.com/supanadit/ezx/releases/download/${EZX_VERSION}/ezx-${EZX_VERSION}-linux-${TARGETARCH}.sha256 -o ezx.sha256 \
    && sha256sum -c ezx.sha256 \
    && mv ezx-${EZX_VERSION}-linux-${TARGETARCH} /usr/local/bin/ezx \
    && chmod +x /usr/local/bin/ezx \
    && rm -f ezx.sha256 \
    && rm -rf /var/lib/apt/lists/*

# Copy entrypoint scripts (volatile files that change frequently during development)
COPY entrypoint.d/ /opt/container/entrypoint.d/

# Set proper ownership of the entrypoint and the container data/config/log/run
# directories. The runtime bootstrap (directories.js) owns these paths but
# cannot create them when the parent /opt is root-owned and the bootstrap
# drops to the postgres user; pre-creating them keeps initdb working.
RUN mkdir -p /opt/containers/data /opt/containers/config /opt/containers/logs /opt/containers/run /opt/containers/backup \
    && chown -R postgres:postgres /opt/container /opt/containers \
    && chmod -R 755 /opt/container/

# Set the stop signal for proper container shutdown
STOPSIGNAL SIGTERM

# Expose PostgreSQL, PgBouncer, and the ezx health API ports
EXPOSE 5432 6432 8080

ENTRYPOINT ["/usr/local/bin/ezx", "bootstrap", "/opt/container/entrypoint.d/bootstrap/main.js"]
