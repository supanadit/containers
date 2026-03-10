# Multi-stage build for daloRADIUS with optimized layer caching
# syntax=docker/dockerfile:1.4
FROM debian:bullseye AS base

ARG DALORADIUS_VERSION="master"
ARG PHP_VERSION="7.4.33"
ARG APACHE_VERSION="2.4.66"
ARG APR_VERSION="1.7.4"
ARG APR_UTIL_VERSION="1.6.3"

# Build metadata
ARG BUILD_DATE
ARG VCS_REF

LABEL org.opencontainers.image.created=$BUILD_DATE \
    org.opencontainers.image.revision=$VCS_REF \
    org.opencontainers.image.title="daloRADIUS with Apache and PHP" \
    org.opencontainers.image.description="Optimized daloRADIUS container with Apache and PHP" \
    org.opencontainers.image.authors="Supan Adit Pratama <email@supanadit.com>" \
    org.opencontainers.image.source=https://github.com/supanadit/containers

# Setup layer - copy stable files first for better caching
FROM base AS setup

# Copy setup scripts and configuration
COPY setup.sh /opt/setup.sh
COPY setup/ /opt/setup/

# Run the complete setup in a single layer with BuildKit cache mounts
RUN --mount=type=cache,target=/var/cache/apt \
    --mount=type=cache,target=/var/lib/apt \
    chmod +x /opt/setup.sh && \
    /opt/setup.sh && \
    rm /opt/setup.sh && \
    rm -rf /opt/setup

# Runtime layer
FROM setup AS runtime

# Set working directory
WORKDIR /var/www/html

# Copy entrypoint script
COPY entrypoint.d /opt/container/entrypoint.d
RUN find /opt/container/entrypoint.d -name "*.sh" -exec chmod +x {} \;

# Set the stop signal for proper container shutdown
STOPSIGNAL SIGTERM

ENTRYPOINT ["/opt/container/entrypoint.d/entrypoint.sh"]
CMD ["/usr/local/apache2/bin/httpd", "-D", "FOREGROUND"]
EXPOSE 80
