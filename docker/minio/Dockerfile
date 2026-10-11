# Multi-stage build for MinIO (community edition, built from Go source).
#
# Layout: `base` (build) → `toolchain` → `setup` → `build` → `runtime`.
#
# MinIO stopped publishing community binaries and containers, so the binary is
# built from the pinned release tag and then copied into a slim runtime image.
#
# - `toolchain` downloads and checksum-verifies the forge builder. It depends
#   only on FORGE_VERSION / TARGETARCH, so bumping forge rebuilds a curl-sized
#   layer instead of the whole Go build.
# - `setup` copies forge from `toolchain` and runs the TOML manifest in a single
#   RUN. Its cache key is driven by GO_VERSION / MINIO_VERSION and forge.toml.
# - `runtime` is debian:bookworm-slim with just the built binary, plus the ezx
#   entrypoint engine and the bootstrap scripts.
# syntax=docker/dockerfile:1.6
FROM debian:bookworm AS base

ARG GO_VERSION=1.23.12
# This is the last best version of MinIO, above this version they changed to
# Community Edition and some features were removed or made inaccessible in the
# dashboard.
ARG MINIO_VERSION=RELEASE.2025-04-22T22-12-26Z

# Build metadata
ARG BUILD_DATE
ARG VCS_REF

LABEL org.opencontainers.image.created=$BUILD_DATE \
    org.opencontainers.image.revision=$VCS_REF \
    org.opencontainers.image.title="MinIO" \
    org.opencontainers.image.description="MinIO community edition built from Go source, with an ezx entrypoint" \
    org.opencontainers.image.authors="Supan Adit Pratama <email@supanadit.com>" \
    org.opencontainers.image.source=https://github.com/supanadit/containers

ENV PATH="/usr/local/go/bin:/go/bin:$PATH" \
    GOROOT=/usr/local/go \
    GOPATH=/go

# ---------------------------------------------------------------------------
# Toolchain layer — download the forge builder (release binary,
# checksum-verified). Isolated so a FORGE_VERSION bump does not invalidate the
# Go build layer.
# ---------------------------------------------------------------------------
FROM base AS toolchain

ARG FORGE_VERSION=1.0.3
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

ARG GO_VERSION=1.23.12
ARG MINIO_VERSION=RELEASE.2025-04-22T22-12-26Z
ARG TARGETARCH=amd64

COPY forge.toml /opt/forge.toml

# forge build shells out to apt-get install, which needs a current package
# index. The toolchain layer's index was discarded with its apt lists, so
# refresh here first.
RUN apt-get update \
    && forge build --verbose \
        --var GO_VERSION=${GO_VERSION} \
        --var MINIO_VERSION=${MINIO_VERSION} \
        --var ARCH=${TARGETARCH} \
        /opt/forge.toml \
    && rm -f /opt/forge.toml /usr/local/bin/forge \
    && rm -rf /var/lib/apt/lists/*

# ---------------------------------------------------------------------------
# Runtime stage — a slim image with the built binary. MinIO is a single static
# binary, so nothing else from the build stage is needed.
# ---------------------------------------------------------------------------
FROM debian:bookworm-slim AS runtime

ARG EZX_VERSION=0.7.0
ARG TARGETARCH=amd64

COPY --from=setup /usr/local/bin/minio /usr/local/bin/minio

# Download and verify the ezx entrypoint engine (runtime-only dependency).
RUN apt-get update && apt-get install -y --no-install-recommends curl ca-certificates \
    && cd /tmp \
    && curl -fsSL https://github.com/supanadit/ezx/releases/download/${EZX_VERSION}/ezx-${EZX_VERSION}-linux-${TARGETARCH} -o ezx-${EZX_VERSION}-linux-${TARGETARCH} \
    && curl -fsSL https://github.com/supanadit/ezx/releases/download/${EZX_VERSION}/ezx-${EZX_VERSION}-linux-${TARGETARCH}.sha256 -o ezx.sha256 \
    && sha256sum -c ezx.sha256 \
    && mv ezx-${EZX_VERSION}-linux-${TARGETARCH} /usr/local/bin/ezx \
    && chmod +x /usr/local/bin/ezx \
    && rm -f ezx.sha256 \
    && rm -rf /var/lib/apt/lists/* \
    # The minio account lives in the runtime stage: the build stage's account
    # does not carry over, and the runtime image has no useradd by default.
    && groupadd --system minio \
    && useradd --system --gid minio --no-create-home --home-dir /opt/containers/data --shell /usr/sbin/nologin minio

# Copy entrypoint scripts (volatile files that change frequently during development)
COPY entrypoint.d/ /opt/container/entrypoint.d/

# Pre-create the volume-normalized directories and hand ownership to the minio
# user. The runtime bootstrap (directories.js) also ensures these, but creating
# them here keeps the paths present while /opt is root-owned. ezx stays PID 1 and
# each node drops privileges via process.user/group.
RUN mkdir -p /opt/containers/data /opt/containers/config /opt/containers/logs /opt/containers/run /opt/containers/backup \
    && chown -R minio:minio /opt/container /opt/containers \
    && chmod -R 750 /opt/containers \
    && chmod -R 755 /opt/container/

ENV PATH="/usr/local/bin:$PATH"

# Set the stop signal for proper container shutdown
STOPSIGNAL SIGTERM

# Expose the MinIO S3 API, the console, and the ezx health API ports
EXPOSE 9000 9001 8080

# Declared so the mount point is obvious; the data directory itself is created
# above under the normalized /opt/containers tree.
VOLUME ["/opt/containers/data"]

ENTRYPOINT ["/usr/local/bin/ezx", "bootstrap", "/opt/container/entrypoint.d/bootstrap/main.js"]
