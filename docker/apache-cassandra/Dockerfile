# Multi-stage build for Apache Cassandra with optimized layer caching
# syntax=docker/dockerfile:1.4
FROM openjdk:17-jdk-slim AS base

ARG CASSANDRA_VERSION=5.0.5
ARG CASSANDRA_HOME=/opt/cassandra

# Build metadata
ARG BUILD_DATE
ARG VCS_REF

LABEL org.opencontainers.image.created=$BUILD_DATE \
    org.opencontainers.image.revision=$VCS_REF \
    org.opencontainers.image.title="cassandra" \
    org.opencontainers.image.description="Optimized Apache Cassandra container" \
    org.opencontainers.image.authors="Supan Adit Pratama <email@supanadit.com>"

# Setup layer - copy stable files first for better caching
FROM base AS setup

# Set Cassandra environment
ENV CASSANDRA_HOME=/opt/cassandra
ENV PATH=/opt/cassandra/bin:$PATH

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

# Set Cassandra environment
ENV CASSANDRA_HOME=/opt/cassandra
ENV PATH=/opt/cassandra/bin:$PATH

# Copy configuration files
COPY config/ /opt/cassandra/conf/

# Copy main entrypoint script
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# Create cassandra user
RUN groupadd -r cassandra && useradd -r -g cassandra cassandra

# Create necessary directories
RUN mkdir -p /opt/cassandra/data /opt/cassandra/logs /opt/cassandra/commitlog && \
    chown -R cassandra:cassandra /opt/cassandra

# Switch to cassandra user
USER cassandra

# Expose Cassandra ports
EXPOSE 7000 7001 7199 9042 9160

ENTRYPOINT ["/entrypoint.sh"]