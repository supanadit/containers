# Multi-stage build for Grafana Mimir.
#
# Layout: `toolchain` -> `setup` -> `runtime`.
#
# - `toolchain` downloads and checksum-verifies the forge builder. It depends
#   only on FORGE_VERSION / TARGETARCH, so bumping forge rebuilds a curl-sized
#   layer instead of the whole build.
# - `setup` copies forge from `toolchain` and runs the TOML manifest in a single
#   RUN. Grafana Mimir ships prebuilt release artifacts, so this layer is the
#   download plus the runtime packages — its cache key is driven by the app
#   version args.
# - `runtime` downloads the ezx entrypoint engine (needed only at run time) and
#   copies the entrypoint scripts, keeping both out of the setup layer.
# syntax=docker/dockerfile:1.6
FROM debian:bookworm AS base

ARG GRAFANA_MIMIR_VERSION=2.17.1

# Build metadata
ARG BUILD_DATE
ARG VCS_REF

LABEL org.opencontainers.image.created=${BUILD_DATE} \
    org.opencontainers.image.revision=${VCS_REF} \
    org.opencontainers.image.title="Grafana Mimir" \
    org.opencontainers.image.description="Grafana Mimir scalable long-term Prometheus storage, packaged for the ezx runtime" \
    org.opencontainers.image.authors="Supan Adit Pratama <email@supanadit.com>" \
    org.opencontainers.image.source=https://github.com/supanadit/containers

ENV PATH="/usr/share/grafana/bin:/usr/share/grafana:/usr/local/bin:${PATH}"

# ---------------------------------------------------------------------------
# Toolchain layer — download the forge builder (release binary,
# checksum-verified). Isolated so a FORGE_VERSION bump does not invalidate
# the source build layer below.
# ---------------------------------------------------------------------------
FROM base AS toolchain

ARG FORGE_VERSION=1.0.6
ARG TARGETARCH=amd64

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
# Setup layer — reuse the prebuilt toolchain and run the TOML manifest.
# ---------------------------------------------------------------------------
FROM toolchain AS setup

ARG GRAFANA_MIMIR_VERSION=2.17.1

COPY forge.toml /opt/forge.toml

# forge build shells out to apt-get install, which needs a current package
# index. The toolchain layer's index was discarded with its apt lists, so
# refresh here first.
RUN apt-get update \
    && forge build --verbose \
        --var GRAFANA_MIMIR_VERSION=${GRAFANA_MIMIR_VERSION} \
        --var ARCH=${TARGETARCH} \
        /opt/forge.toml \
    && rm -f /opt/forge.toml /usr/local/bin/forge \
    && rm -rf /var/lib/apt/lists/*

ENV PATH="/usr/share/grafana/bin:/usr/share/grafana:/usr/local/bin:${PATH}"

# ---------------------------------------------------------------------------
# Runtime layer — the ezx engine is fetched here (it is only needed at run
# time), then the entrypoint scripts are copied. Bumping EZX_VERSION rebuilds
# a curl-sized layer, and editing entrypoint scripts does not re-download ezx.
# ---------------------------------------------------------------------------
FROM setup AS runtime

ARG EZX_VERSION=0.8.0
ARG TARGETARCH=amd64

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

# Pre-create the volume-normalized directories and hand ownership to the app
# user. The runtime bootstrap (directories.js) also ensures these, but creating
# them here keeps the paths present while /opt is root-owned. ezx stays PID 1
# and each node drops privileges via process.user/group.
RUN mkdir -p /opt/containers/data /opt/containers/config /opt/containers/logs /opt/containers/run /opt/containers/backup \
    && chown -R mimir:mimir /opt/container /opt/containers \
    && chmod -R 750 /opt/containers \
    && chmod -R 755 /opt/container/

# Set the stop signal for proper container shutdown
STOPSIGNAL SIGTERM

# Expose the application and the ezx health API ports
EXPOSE 8080 9095 8081

# Declared so the mount point is obvious; the directory itself is created
# above under the normalized /opt/containers tree.
VOLUME ["/opt/containers/data"]

ENTRYPOINT ["/usr/local/bin/ezx", "bootstrap", "/opt/container/entrypoint.d/bootstrap/main.js"]
