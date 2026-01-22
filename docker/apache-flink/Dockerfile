# Multi-stage build for Apache Flink with optimized layer caching
# syntax=docker/dockerfile:1.4
FROM debian:bookworm AS base

ARG JAVA_VERSION=21
ARG FLINK_VERSION=2.1.1

# Build metadata
ARG BUILD_DATE
ARG VCS_REF

LABEL org.opencontainers.image.created=$BUILD_DATE \
    org.opencontainers.image.revision=$VCS_REF \
    org.opencontainers.image.title="flink" \
    org.opencontainers.image.description="Optimized Apache Flink container" \
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

# Set Flink environment
ENV FLINK_HOME=/opt/flink
ENV PATH=/opt/flink/bin:$PATH

# Copy entrypoint scripts (volatile files that change frequently during development)
COPY entrypoint.d/ /opt/container/entrypoint.d/

# Copy main entrypoint script
COPY entrypoint.d/entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# Create flink user
RUN groupadd -r flink && useradd -r -g flink flink

# Create necessary directories
RUN mkdir -p /opt/flink/logs && \
    chown -R flink:flink /opt/flink

# Switch to flink user
USER flink

# Expose Flink ports
EXPOSE 8081 6123 6124

ENTRYPOINT ["/entrypoint.sh"]