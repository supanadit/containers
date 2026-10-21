# Multi-stage build for WordPress with Apache HTTP Server and PHP.
#
# Layout: `toolchain` → `setup` → `runtime`.
#
# - `toolchain` downloads and checksum-verifies the forge builder. It depends
#   only on FORGE_VERSION / TARGETARCH, so bumping forge rebuilds a curl-sized
#   layer instead of the whole source build.
# - `setup` copies forge from `toolchain` and runs the full TOML manifest in a
#   single RUN (forge's scheduler parallelizes steps inside it). Its cache key
#   is driven by the app version args and forge.toml — the things that genuinely
#   require recompiling (APR, httpd, PHP and its extensions).
# - `runtime` downloads the ezx entrypoint engine (needed only at run time) and
#   copies the entrypoint scripts, keeping both out of the heavy setup stage.
# syntax=docker/dockerfile:1.6
FROM debian:bookworm AS base

ARG WORDPRESS_VERSION="6.9.5"
ARG APACHE_VERSION="2.4.66"
ARG PHP_VERSION="8.3.23"
ARG APR_VERSION="1.7.6"
ARG APR_UTIL_VERSION="1.6.5"
ARG APACHE_EXPORTER_VERSION="1.0.10"

# Build metadata
ARG BUILD_DATE
ARG VCS_REF

LABEL org.opencontainers.image.created=$BUILD_DATE \
    org.opencontainers.image.revision=$VCS_REF \
    org.opencontainers.image.title="WordPress with Apache and PHP" \
    org.opencontainers.image.description="Optimized WordPress container with Apache, PHP, and monitoring" \
    org.opencontainers.image.authors="Supan Adit Pratama <email@supanadit.com>" \
    org.opencontainers.image.source=https://github.com/supanadit/containers

ENV PATH="/usr/local/apache2/bin:/usr/local/bin:$PATH"

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
# a single layer. User plugins and themes are copied into /tmp first so the
# manifest's addons component can bake them into wp-content.
# ---------------------------------------------------------------------------
FROM toolchain AS setup

ARG WORDPRESS_VERSION="6.9.5"
ARG APACHE_VERSION="2.4.66"
ARG PHP_VERSION="8.3.23"
ARG APR_VERSION="1.7.6"
ARG APR_UTIL_VERSION="1.6.5"
ARG APACHE_EXPORTER_VERSION="1.0.10"
ARG TARGETARCH=amd64

COPY forge.toml /opt/forge.toml
COPY plugins/ /tmp/plugins/
COPY themes/ /tmp/themes/

# forge build shells out to apt-get install, which needs a current package
# index. The toolchain layer's index was discarded with its apt lists, so
# refresh here first.
RUN apt-get update \
    && forge build --verbose \
        --var WORDPRESS_VERSION=${WORDPRESS_VERSION} \
        --var APACHE_VERSION=${APACHE_VERSION} \
        --var PHP_VERSION=${PHP_VERSION} \
        --var APR_VERSION=${APR_VERSION} \
        --var APR_UTIL_VERSION=${APR_UTIL_VERSION} \
        --var APACHE_EXPORTER_VERSION=${APACHE_EXPORTER_VERSION} \
        --var ARCH=${TARGETARCH} \
        /opt/forge.toml \
    && rm -f /opt/forge.toml /usr/local/bin/forge \
    && rm -rf /tmp/plugins /tmp/themes \
    && rm -rf /var/lib/apt/lists/*

# The ezx health API (which the HEALTHCHECK probes) only listens when
# EZX_HEALTH_ADDR is set. Bind it to loopback: it is an in-container surface for
# the healthcheck and operators, not a public port.
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

# Copy the shipped application source fragments (PHP) that the entrypoint
# includes into config files by path — so no PHP is written as a JS string.
COPY config/ /opt/container/config/

# Pre-create the volume-normalized directories and hand ownership to the
# www-data user. The runtime bootstrap (directories.js) also ensures these, but
# creating them here keeps the paths present while /opt is root-owned. ezx stays
# PID 1 and each node drops privileges via process.user/group.
RUN mkdir -p /opt/containers/data /opt/containers/config /opt/containers/logs /opt/containers/run \
    && chown -R www-data:www-data /opt/container /opt/containers /var/www/html \
    && chmod -R 755 /opt/container/

# Set working directory
WORKDIR /var/www/html

# Set the stop signal for proper container shutdown
STOPSIGNAL SIGTERM

# Expose the Apache listener, the apache_exporter metrics port and the ezx
# health API port.
EXPOSE 80 9117 8080

# Healthcheck hits the ezx health API. ezx.api always answers HTTP 200 whatever
# the body, so the check greps the payload for "healthy":true rather than
# relying on the status code. Requires EZX_HEALTH_ADDR (set above).
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD curl -fsS "http://${EZX_HEALTH_ADDR}/health/comprehensive" | grep -q '"healthy":true' || exit 1

ENTRYPOINT ["/usr/local/bin/ezx", "bootstrap", "/opt/container/entrypoint.d/bootstrap/main.js"]
