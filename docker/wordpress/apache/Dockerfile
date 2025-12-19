# Multi-stage build for WordPress with optimized layer caching
# syntax=docker/dockerfile:1.4
FROM debian:bookworm AS base

ARG WORDPRESS_VERSION="6.9"
ARG APACHE_VERSION="2.4.66"
ARG PHP_VERSION="8.3.23"
ARG APR_VERSION="1.7.6"
ARG APR_UTIL_VERSION="1.6.3"
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
    rm -rf /opt/setup

# Runtime layer - copy volatile files later
FROM setup AS runtime

# Set working directory
WORKDIR /var/www/html

COPY addons.sh /opt/addons.sh
COPY addons/ /opt/addons/

COPY plugins /tmp/plugins
COPY themes /tmp/themes

RUN chmod +x /opt/addons.sh && \
    /opt/addons.sh && \
    rm /opt/addons.sh && \
    rm -rf /opt/addons

# Copy entrypoint script
COPY entrypoint.d /opt/container/entrypoint.d
RUN find /opt/container/entrypoint.d -name "*.sh" -exec chmod +x {} \;

# Set the stop signal for proper container shutdown
STOPSIGNAL SIGTERM

ENTRYPOINT ["/opt/container/entrypoint.d/entrypoint.sh"]
CMD ["/usr/local/apache2/bin/httpd", "-D", "FOREGROUND"]
EXPOSE 80 9117