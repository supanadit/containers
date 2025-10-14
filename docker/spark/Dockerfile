# Multi-stage build for Spark with optimized layer caching
# syntax=docker/dockerfile:1.4
FROM debian:bookworm AS base

ARG JAVA_VERSION=21
ARG SPARK_VERSION=4.0.1

# Build metadata
ARG BUILD_DATE
ARG VCS_REF

LABEL org.opencontainers.image.created=$BUILD_DATE \
    org.opencontainers.image.revision=$VCS_REF \
    org.opencontainers.image.title="spark" \
    org.opencontainers.image.description="Optimized Spark container" \
    org.opencontainers.image.authors="Supan Adit Pratama <email@supanadit.com>"

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

# Runtime layer - copy volatile files later
FROM setup AS runtime

# Copy entrypoint scripts (volatile files that change frequently during development)
COPY entrypoint.d/ /opt/container/entrypoint.d/

# Copy configuration files
COPY config/ /opt/spark/conf/

# Copy main entrypoint script
COPY entrypoint.d/entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# Expose Spark ports
EXPOSE 7077 8080

ENTRYPOINT ["/entrypoint.sh"]