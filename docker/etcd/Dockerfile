# Multi-stage build for etcd (built from Go source).
#
# Layout: `toolchain` -> `setup` -> `runtime`.
#
# - `toolchain` downloads and checksum-verifies the forge builder. It depends
#   only on FORGE_VERSION / TARGETARCH, so bumping forge rebuilds a curl-sized
#   layer instead of the whole Go build.
# - `setup` copies forge from `toolchain` and runs the TOML manifest in a single
#   RUN. Its cache key is driven by GO_VERSION / ETCD_VERSION and forge.toml.
# - `runtime` is debian:bookworm-slim with just the built binaries, plus the ezx
#   entrypoint engine and the bootstrap scripts. The etcd user is created here
#   (the build stage's account does not carry over).
# syntax=docker/dockerfile:1.6
FROM debian:bookworm AS base

ARG GO_VERSION=1.24.12
ARG ETCD_VERSION=3.6.7

# Build metadata
ARG BUILD_DATE
ARG VCS_REF

LABEL org.opencontainers.image.created=${BUILD_DATE} \
    org.opencontainers.image.revision=${VCS_REF} \
    org.opencontainers.image.title="etcd" \
    org.opencontainers.image.description="etcd distributed key-value store built from Go source, with an ezx entrypoint" \
    org.opencontainers.image.authors="Supan Adit Pratama <email@supanadit.com>" \
    org.opencontainers.image.source=https://github.com/supanadit/containers

ENV PATH="/usr/local/go/bin:/go/bin:/usr/local/bin:${PATH}" \
    GOROOT=/usr/local/go \
    GOPATH=/go

# ---------------------------------------------------------------------------
# Toolchain layer — download the forge builder (release binary,
# checksum-verified). Isolated so a FORGE_VERSION bump does not invalidate the
# source build layer below.
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

ARG GO_VERSION=1.24.12
ARG ETCD_VERSION=3.6.7
ARG TARGETARCH=amd64

COPY forge.toml /opt/forge.toml

# forge build shells out to apt-get install, which needs a current package
# index. The toolchain layer's index was discarded with its apt lists, so
# refresh here first.
RUN apt-get update \
    && forge build --verbose \
        --var GO_VERSION=${GO_VERSION} \
        --var ETCD_VERSION=${ETCD_VERSION} \
        --var ARCH=${TARGETARCH} \
        /opt/forge.toml \
    && rm -f /opt/forge.toml /usr/local/bin/forge \
    && rm -rf /var/lib/apt/lists/*

# ---------------------------------------------------------------------------
# Runtime stage — a slim image with the built binaries. etcd is a set of static
# binaries, so nothing else from the build stage is needed.
# ---------------------------------------------------------------------------
FROM debian:bookworm-slim AS runtime

ARG EZX_VERSION=0.8.0
ARG TARGETARCH=amd64

COPY --from=setup /usr/local/bin/etcd /usr/local/bin/etcd
COPY --from=setup /usr/local/bin/etcdctl /usr/local/bin/etcdctl
COPY --from=setup /usr/local/bin/etcdutl /usr/local/bin/etcdutl

# Download and verify the ezx entrypoint engine (runtime-only dependency), then
# create the etcd account and runtime libs.
RUN apt-get update && apt-get install -y --no-install-recommends curl ca-certificates \
    && cd /tmp \
    && curl -fsSL https://github.com/supanadit/ezx/releases/download/${EZX_VERSION}/ezx-${EZX_VERSION}-linux-${TARGETARCH} -o ezx-${EZX_VERSION}-linux-${TARGETARCH} \
    && curl -fsSL https://github.com/supanadit/ezx/releases/download/${EZX_VERSION}/ezx-${EZX_VERSION}-linux-${TARGETARCH}.sha256 -o ezx.sha256 \
    && sha256sum -c ezx.sha256 \
    && mv ezx-${EZX_VERSION}-linux-${TARGETARCH} /usr/local/bin/ezx \
    && chmod +x /usr/local/bin/ezx \
    && rm -f ezx.sha256 \
    && rm -rf /var/lib/apt/lists/* \
    && groupadd --system etcd \
    && useradd --system --gid etcd --no-create-home --home-dir /opt/containers/data --shell /usr/sbin/nologin etcd

# Copy entrypoint scripts (volatile files that change frequently during development)
COPY entrypoint.d/ /opt/container/entrypoint.d/

# Pre-create the volume-normalized directories and hand ownership to the etcd
# user. The runtime bootstrap (directories.js) also ensures these, but creating
# them here keeps the paths present while /opt is root-owned. ezx stays PID 1
# and each node drops privileges via process.user/group.
RUN mkdir -p /opt/containers/data /opt/containers/config /opt/containers/logs /opt/containers/run /opt/containers/backup \
    && chown -R etcd:etcd /opt/container /opt/containers \
    && chmod -R 750 /opt/containers \
    && chmod -R 755 /opt/container/

# Set the stop signal for proper container shutdown
STOPSIGNAL SIGTERM

# Expose the etcd client, peer, metrics and the ezx health API ports
EXPOSE 2379 2380 8080

# Declared so the mount point is obvious; the data directory itself is created
# above under the normalized /opt/containers tree.
VOLUME ["/opt/containers/data"]

ENTRYPOINT ["/usr/local/bin/ezx", "bootstrap", "/opt/container/entrypoint.d/bootstrap/main.js"]
