# Multi-stage build for Grafana Alloy (built from Go + Vite source).
#
# Layout: `toolchain` -> `setup` -> `runtime`.
#
# - `toolchain` downloads and checksum-verifies the forge builder. It depends
#   only on FORGE_VERSION / TARGETARCH, so bumping forge rebuilds a curl-sized
#   layer instead of the whole build.
# - `setup` copies forge from `toolchain`, installs Go + Node, builds the Vite
#   UI and compiles Alloy with the upstream release tags. Its cache key is
#   driven by GO_VERSION / NODE_VERSION / GRAFANA_ALLOY_VERSION and forge.toml.
# - `runtime` is debian:bookworm-slim with the built binary (cgo, journal
#   support), the example config, the ezx entrypoint engine and the bootstrap
#   scripts. The alloy user is created here.
# syntax=docker/dockerfile:1.6
FROM debian:bookworm AS base

ARG GO_VERSION=1.25.14
ARG NODE_VERSION=24.4.0
ARG GRAFANA_ALLOY_VERSION=1.12.1

# Build metadata
ARG BUILD_DATE
ARG VCS_REF

LABEL org.opencontainers.image.created=${BUILD_DATE} \
    org.opencontainers.image.revision=${VCS_REF} \
    org.opencontainers.image.title="Grafana Alloy" \
    org.opencontainers.image.description="Grafana Alloy telemetry collector, built from source for the ezx runtime" \
    org.opencontainers.image.authors="Supan Adit Pratama <email@supanadit.com>" \
    org.opencontainers.image.source=https://github.com/supanadit/containers

ENV PATH="/usr/share/grafana/bin:/usr/share/grafana:/usr/local/node/bin:/usr/local/go/bin:/go/bin:/usr/local/bin:${PATH}" \
    GOROOT=/usr/local/go \
    GOPATH=/go

# ---------------------------------------------------------------------------
# Toolchain layer — download the forge builder (release binary,
# checksum-verified). Isolated so a FORGE_VERSION bump does not invalidate
# the source build layer.
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

ARG GO_VERSION=1.25.14
ARG NODE_VERSION=24.4.0
ARG GRAFANA_ALLOY_VERSION=1.12.1
ARG TARGETARCH=amd64

# Official Go and Node release checksums, used by forge to verify the toolchain
# tarballs.
ARG GO_SHA256_AMD64=a21ae5633a269bcd7e90cf767e48225633795e99d831742cbf3397064fee7712
ARG GO_SHA256_ARM64=9bf234ea70ffec9347fdf6b22ce4add51717d3386a38a441e8c8743fceb5eaee
ARG NODE_SHA256_AMD64=292c187efeb7a360dee81efb519518dea2e02cb98e4c0d1d5a0f0af62c31e4b6
ARG NODE_SHA256_ARM64=637ab954900450101c9a254df9014771f5f21d5fd12fec53e4cf4f8bae7e7365

COPY forge.toml /opt/forge.toml

# forge build shells out to apt-get install, which needs a current package
# index. The toolchain layer's index was discarded with its apt lists, so
# refresh here first. The checksums and Node archive name are resolved per
# target architecture because a forge var can only hold one value.
RUN apt-get update \
    && GO_SHA256="$(case "${TARGETARCH}" in amd64) echo "${GO_SHA256_AMD64}" ;; arm64) echo "${GO_SHA256_ARM64}" ;; *) echo "unsupported TARGETARCH=${TARGETARCH}" >&2; exit 1 ;; esac)" \
    && NODE_SHA256="$(case "${TARGETARCH}" in amd64) echo "${NODE_SHA256_AMD64}" ;; arm64) echo "${NODE_SHA256_ARM64}" ;; *) echo "unsupported TARGETARCH=${TARGETARCH}" >&2; exit 1 ;; esac)" \
    && NODE_ARCH="$(case "${TARGETARCH}" in amd64) echo x64 ;; arm64) echo arm64 ;; *) echo "unsupported TARGETARCH=${TARGETARCH}" >&2; exit 1 ;; esac)" \
    && forge build --verbose \
        --var GO_VERSION=${GO_VERSION} \
        --var GO_SHA256=${GO_SHA256} \
        --var NODE_VERSION=${NODE_VERSION} \
        --var NODE_SHA256=${NODE_SHA256} \
        --var NODE_ARCH=${NODE_ARCH} \
        --var GRAFANA_ALLOY_VERSION=${GRAFANA_ALLOY_VERSION} \
        --var ARCH=${TARGETARCH} \
        /opt/forge.toml \
    && rm -f /opt/forge.toml /usr/local/bin/forge \
    && rm -rf /var/lib/apt/lists/*

# ---------------------------------------------------------------------------
# Runtime stage — a slim image with the built binary, its example config and
# libsystemd0 (the journal-enabled build tag links against it).
# ---------------------------------------------------------------------------
FROM debian:bookworm-slim AS runtime

ARG EZX_VERSION=0.8.1
ARG TARGETARCH=amd64

COPY --from=setup /usr/share/grafana/alloy /usr/share/grafana/alloy
COPY --from=setup /etc/alloy/config.alloy /etc/alloy/config.alloy

# Download and verify the ezx entrypoint engine (runtime-only dependency), then
# install the runtime libs and create the alloy account.
RUN apt-get update && apt-get install -y --no-install-recommends curl ca-certificates tzdata procps libsystemd0 \
    && cd /tmp \
    && curl -fsSL https://github.com/supanadit/ezx/releases/download/${EZX_VERSION}/ezx-${EZX_VERSION}-linux-${TARGETARCH} -o ezx-${EZX_VERSION}-linux-${TARGETARCH} \
    && curl -fsSL https://github.com/supanadit/ezx/releases/download/${EZX_VERSION}/ezx-${EZX_VERSION}-linux-${TARGETARCH}.sha256 -o ezx.sha256 \
    && sha256sum -c ezx.sha256 \
    && mv ezx-${EZX_VERSION}-linux-${TARGETARCH} /usr/local/bin/ezx \
    && chmod +x /usr/local/bin/ezx \
    && rm -f ezx.sha256 \
    && rm -rf /var/lib/apt/lists/* \
    && groupadd --system alloy \
    && useradd --system --gid alloy --no-create-home --home-dir /opt/containers/data --shell /usr/sbin/nologin alloy

ENV PATH="/usr/share/grafana/bin:/usr/share/grafana:/usr/local/bin:${PATH}"

# Copy entrypoint scripts (volatile files that change frequently during development)
COPY entrypoint.d/ /opt/container/entrypoint.d/

# Pre-create the volume-normalized directories and hand ownership to the app
# user. The runtime bootstrap (directories.js) also ensures these, but creating
# them here keeps the paths present while /opt is root-owned. ezx stays PID 1
# and each node drops privileges via process.user/group.
RUN mkdir -p /opt/containers/data /opt/containers/config /opt/containers/logs /opt/containers/run /opt/containers/backup \
    && chown -R alloy:alloy /opt/container /opt/containers \
    && chmod -R 750 /opt/containers \
    && chmod -R 755 /opt/container/

# Set the stop signal for proper container shutdown
STOPSIGNAL SIGTERM

# Expose the application and the ezx health API ports
EXPOSE 12345 8080

# Declared so the mount point is obvious; the directory itself is created
# above under the normalized /opt/containers tree.
VOLUME ["/opt/containers/data"]

ENTRYPOINT ["/usr/local/bin/ezx", "bootstrap", "/opt/container/entrypoint.d/bootstrap/main.js"]
