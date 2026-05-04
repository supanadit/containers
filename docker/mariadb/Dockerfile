# Multi-stage build for MariaDB with optimized layer caching
# syntax=docker/dockerfile:1.4
FROM debian:bookworm-slim AS base

ARG MARIADB_VERSION=11.8.3
ARG MARIADB_GALERA_VERSION=26.4.16

STOPSIGNAL SIGTERM

HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD /opt/container/entrypoint.d/scripts/runtime/healthcheck.sh || exit 1

# Build metadata
ARG BUILD_DATE
ARG VCS_REF

LABEL org.opencontainers.image.created=$BUILD_DATE \
    org.opencontainers.image.revision=$VCS_REF \
    org.opencontainers.image.title="MariaDB" \
    org.opencontainers.image.description="Optimized MariaDB container" \
    org.opencontainers.image.authors="Supan Adit Pratama <email@supanadit.com>" \
    org.opencontainers.image.source=https://github.com/supanadit/containers

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

ENV PATH="/usr/local/mariadb/bin:$PATH"

# Runtime layer - copy volatile files later
FROM setup AS runtime
# Create postgres user for security (already created in setup stage)

# Copy entrypoint scripts (volatile files that change frequently during development)
COPY entrypoint.d/ /opt/container/entrypoint.d/
RUN find /opt/container/entrypoint.d -name "*.sh" -exec chmod +x {} \;

# Copy main entrypoint script
COPY entrypoint.d/entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# Expose MariaDB port
EXPOSE 3306

ENTRYPOINT ["/entrypoint.sh"]