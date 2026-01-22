# Multi-stage build for Apache ZooKeeper with optimized layer caching
# syntax=docker/dockerfile:1.4
FROM debian:bookworm AS base

ARG JAVA_VERSION=21
ARG ZOOKEEPER_VERSION=3.9.4

# Build metadata
ARG BUILD_DATE
ARG VCS_REF

LABEL org.opencontainers.image.created=$BUILD_DATE \
    org.opencontainers.image.revision=$VCS_REF \
    org.opencontainers.image.title="zookeeper" \
    org.opencontainers.image.description="Optimized Apache ZooKeeper container" \
    org.opencontainers.image.authors="Supan Adit Pratama <email@supanadit.com>"

# Setup layer - copy stable files first for better caching
FROM base AS setup

# Set Java environment
ENV JAVA_HOME=/opt/java
ENV PATH=/opt/java/bin:$PATH

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

# Set Java environment
ENV JAVA_HOME=/opt/java
ENV PATH=/opt/java/bin:$PATH

# Set ZooKeeper environment
ENV ZOOKEEPER_HOME=/opt/zookeeper
ENV PATH=/opt/zookeeper/bin:$PATH

# Copy entrypoint scripts (volatile files that change frequently during development)
COPY entrypoint.d/ /opt/container/entrypoint.d/

# Copy configuration files
COPY config/ /opt/zookeeper/conf/

# Copy main entrypoint script
COPY entrypoint.d/entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# Create zookeeper user
RUN groupadd -r zookeeper && useradd -r -g zookeeper zookeeper

# Create necessary directories
RUN mkdir -p /opt/zookeeper/logs /opt/zookeeper/data && \
    chown -R zookeeper:zookeeper /opt/zookeeper

# Switch to zookeeper user
USER zookeeper

# Expose ZooKeeper ports
EXPOSE 2181 2888 3888

ENTRYPOINT ["/entrypoint.sh"]