# Multi-stage build for Apache Kafka (KRaft).
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

ARG KAFKA_VERSION=3.9.2
ARG SCALA_VERSION=2.13
ARG JAVA_VERSION=21
ARG CORRETTO_VERSION=21.0.12.9.1
ARG CORRETTO_SHA256_X64=f79824540cef882da0cdf1369f9d1d69afc14b5a9bc3a771fd5bb795793ce2f2
ARG CORRETTO_SHA256_AARCH64=cda6f38775da6ba19e154dd2194a309dabfb12da87ad13f396893d9a555eb1ce
ARG KAFKA_SHA512=01186a5086b5ae753811ee71808a797baec1303d4e0d4b1c0acf42c489654a7b8988136f8469d0b66f0be439f8e3e9b816171ea0b0d7a36462b07aa2d3ef0023

# Build metadata
ARG BUILD_DATE
ARG VCS_REF

LABEL org.opencontainers.image.created=$BUILD_DATE \
    org.opencontainers.image.revision=$VCS_REF \
    org.opencontainers.image.title="Kafka" \
    org.opencontainers.image.description="Apache Kafka in KRaft mode on Amazon Corretto, with TLS/SASL and ezx entrypoint" \
    org.opencontainers.image.authors="Supan Adit Pratama <email@supanadit.com>" \
    org.opencontainers.image.source=https://github.com/supanadit/containers

ENV JAVA_HOME=/opt/java
ENV KAFKA_HOME=/opt/kafka
ENV PATH="/opt/java/bin:/opt/kafka/bin:$PATH"

# ---------------------------------------------------------------------------
# Toolchain layer — download the forge builder (release binary,
# checksum-verified). Isolated so a FORGE_VERSION bump does not invalidate the
# source build layer below.
# ---------------------------------------------------------------------------
FROM base AS toolchain

ARG FORGE_VERSION=1.0.3
ARG TARGETARCH=amd64

# Install forge (checksum-verified).
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

ARG KAFKA_VERSION=3.9.2
ARG SCALA_VERSION=2.13
ARG CORRETTO_VERSION=21.0.12.9.1
ARG CORRETTO_SHA256_X64=f79824540cef882da0cdf1369f9d1d69afc14b5a9bc3a771fd5bb795793ce2f2
ARG CORRETTO_SHA256_AARCH64=cda6f38775da6ba19e154dd2194a309dabfb12da87ad13f396893d9a555eb1ce
ARG KAFKA_SHA512=01186a5086b5ae753811ee71808a797baec1303d4e0d4b1c0acf42c489654a7b8988136f8469d0b66f0be439f8e3e9b816171ea0b0d7a36462b07aa2d3ef0023
ARG TARGETARCH=amd64

COPY forge.toml /opt/forge.toml

# forge build shells out to apt-get install, which needs a current package
# index. The toolchain layer's index was discarded with its apt lists, so
# refresh here first.
RUN apt-get update \
    && forge build --verbose \
        --var KAFKA_VERSION=${KAFKA_VERSION} \
        --var SCALA_VERSION=${SCALA_VERSION} \
        --var KAFKA_SHA512=${KAFKA_SHA512} \
        --var CORRETTO_VERSION=${CORRETTO_VERSION} \
        --var CORRETTO_SHA256_X64=${CORRETTO_SHA256_X64} \
        --var CORRETTO_SHA256_AARCH64=${CORRETTO_SHA256_AARCH64} \
        --var TARGETARCH=${TARGETARCH} \
        /opt/forge.toml \
    && rm -f /opt/forge.toml /usr/local/bin/forge \
    && rm -rf /var/lib/apt/lists/*

# ---------------------------------------------------------------------------
# Runtime layer — the ezx engine is fetched here (it is only needed at run
# time), then the entrypoint scripts are copied. Because the ezx download sits
# in its own layer above the heavy setup stage, bumping EZX_VERSION rebuilds a
# curl-sized layer instead of the whole source build, and editing entrypoint
# scripts does not re-download ezx.
# ---------------------------------------------------------------------------
FROM setup AS runtime

ARG KAFKA_VERSION=3.9.2
ARG EZX_VERSION=0.7.0
ARG TARGETARCH=amd64

# The bootstrap reads KAFKA_VERSION to pick the log4j flavour (log4j 1.x on
# 3.9.x, log4j2 on 4.x) and any version-conditional config key.
ENV KAFKA_VERSION=${KAFKA_VERSION}

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

# Pre-create the volume-normalized directories and hand ownership to the kafka
# user. The runtime bootstrap (directories.js) also ensures these, but creating
# them here keeps the paths present when /opt is root-owned.
RUN mkdir -p /opt/containers/data /opt/containers/config /opt/containers/logs /opt/containers/run /opt/containers/backup \
    && chown -R kafka:kafka /opt/container /opt/containers /opt/kafka /opt/java \
    && chmod -R 755 /opt/container/

# Set the stop signal for proper container shutdown
STOPSIGNAL SIGTERM

# Expose Kafka broker, controller, and the ezx health API ports
EXPOSE 9092 9093 8080

ENTRYPOINT ["/usr/local/bin/ezx", "bootstrap", "/opt/container/entrypoint.d/bootstrap/main.js"]
