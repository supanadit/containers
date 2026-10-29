# Multi-stage build for PgPool-II.
#
# Layout: `toolchain` → `setup` → `runtime`.
#
# - `toolchain` downloads and checksum-verifies the forge builder. It depends
#   only on FORGE_VERSION / TARGETARCH, so bumping forge rebuilds a curl-sized
#   layer instead of the whole source build.
# - `setup` runs the full forge.toml manifest in a single RUN (forge's scheduler
#   parallelizes steps inside it). Its cache key is driven by the app version
#   args and forge.toml — the things that genuinely require recompiling.
# - `runtime` downloads the ezx entrypoint engine (needed only at run time) and
#   copies the entrypoint scripts, keeping both out of the heavy setup stage.
# syntax=docker/dockerfile:1.6
FROM debian:bookworm AS base

ARG PGPOOLII_VERSION=4.6.8

# Build metadata
ARG BUILD_DATE
ARG VCS_REF

LABEL org.opencontainers.image.created=$BUILD_DATE \
    org.opencontainers.image.revision=$VCS_REF \
    org.opencontainers.image.title="pgpool-ii" \
    org.opencontainers.image.description="PgPool-II connection pooler for any PostgreSQL instance" \
    org.opencontainers.image.authors="Supan Adit Pratama <email@supanadit.com>" \
    org.opencontainers.image.source=https://github.com/supanadit/containers

# ---------------------------------------------------------------------------
# Toolchain layer — download the forge builder (release binary,
# checksum-verified). Isolated so a FORGE_VERSION bump does not invalidate the
# source build layer below.
# ---------------------------------------------------------------------------
FROM base AS toolchain

ARG FORGE_VERSION=1.0.6
ARG TARGETARCH

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

ARG PGPOOLII_VERSION=4.6.8
# pgpool2 git tags encode the version with underscores (V4_6_8 for 4.6.8).
ARG PGPOOLII_TAG=V4_6_8

COPY forge.toml /opt/forge.toml

# forge build shells out to apt-get install, which needs a current package
# index. The toolchain layer's index was discarded with its apt lists, so
# refresh here first.
RUN apt-get update \
    && forge build --verbose \
        --var PGPOOLII_VERSION=${PGPOOLII_VERSION} \
        --var PGPOOLII_TAG=${PGPOOLII_TAG} \
        /opt/forge.toml \
    && rm -f /opt/forge.toml /usr/local/bin/forge \
    && rm -rf /var/lib/apt/lists/*

# Set PATH for pgpool-II binaries
ENV PATH="/usr/local/pgpool/bin:$PATH"

# The ezx health API (which every container's api.js registers routes on, and
# which the HEALTHCHECK below probes) only listens when EZX_HEALTH_ADDR is set.
# Bind it to loopback: it is an in-container surface for the healthcheck and
# operators, not a public port, so it is deliberately not published.
ENV EZX_HEALTH_ADDR="127.0.0.1:8080"

# ---------------------------------------------------------------------------
# Runtime layer — the ezx engine is fetched here (it is only needed at run
# time), then the entrypoint scripts are copied. Because the ezx download sits
# in its own layer above the heavy setup stage, bumping EZX_VERSION rebuilds a
# curl-sized layer instead of the whole source build, and editing entrypoint
# scripts does not re-download ezx.
# ---------------------------------------------------------------------------
FROM setup AS runtime

ARG EZX_VERSION=0.8.1
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

# Pre-create the volume-normalized config/log/run directories and hand ownership
# to the postgres user. The runtime bootstrap (directories.js) also ensures
# these, but creating them here keeps the paths present when /opt is root-owned.
RUN mkdir -p /opt/containers/config /opt/containers/logs /opt/containers/run \
    && chown -R postgres:postgres /opt/container /opt/containers \
    && chmod -R 755 /opt/container/

# Set the stop signal for proper container shutdown
STOPSIGNAL SIGTERM

# Expose the pgpool-II listener, PCP port, and the ezx health API port
EXPOSE 5432 9898 8080

# Healthcheck runs a real query through pgpool, not just a port check: pgpool
# accepts connections and passes a TCP probe while rejecting every query with
# "failed to authenticate with backend using SCRAM" — green while broken.
# ezx.api always answers HTTP 200 whatever the body, so the check greps the
# payload for "healthy":true rather than relying on the status code.
# Requires EZX_HEALTH_ADDR (set above) and PGPOOL_HEALTH_CHECK_PASSWORD.
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD curl -fsS "http://${EZX_HEALTH_ADDR}/health/comprehensive" | grep -q '"healthy":true' || exit 1

ENTRYPOINT ["/usr/local/bin/ezx", "bootstrap", "/opt/container/entrypoint.d/bootstrap/main.js"]
