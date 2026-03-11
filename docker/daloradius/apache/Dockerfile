# Multi-stage build for daloRADIUS with optimized layer caching
# syntax=docker/dockerfile:1.4
FROM debian:bullseye AS base

# ARG DALORADIUS_VERSION="1.3"
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

# ==========================================
# SETUP Layer: Apache, PHP, PEAR, etc.
# ==========================================
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

# ==========================================
# DALORADIUS Layer: Download & prepare source
# ==========================================
FROM setup AS daloradius

ARG DALORADIUS_VERSION

# Download and prepare daloRADIUS source (persists in image)
RUN mkdir -p /tmp/downloads/daloradius && \
    cd /tmp/downloads/daloradius && \
    if [ "$DALORADIUS_VERSION" = "master" ]; then \
        wget -q https://github.com/lirantal/daloradius/archive/refs/heads/master.zip -O daloradius.zip; \
    else \
        wget -q https://github.com/lirantal/daloradius/archive/refs/tags/${DALORADIUS_VERSION}.zip -O daloradius.zip; \
    fi && \
    unzip -q daloradius.zip && \
    rm daloradius.zip && \
    mkdir -p /usr/src && \
    mv daloradius-* /usr/src/daloradius-source && \
    rm -rf /tmp/downloads

# ==========================================
# RUNTIME Layer: Entry point
# ==========================================
FROM daloradius AS runtime

# Set working directory
WORKDIR /var/www/daloradius

# Copy daloRADIUS source to web root
COPY --from=daloradius /usr/src/daloradius-source /var/www/daloradius

# Copy Apache virtual host configs from official daloRADIUS
COPY contrib/docker/operators.conf /usr/local/apache2/conf/sites-available/
COPY contrib/docker/users.conf /usr/local/apache2/conf/sites-available/
COPY contrib/docker/operators-v1.conf /usr/local/apache2/conf/sites-available/
COPY contrib/docker/users-v1.conf /usr/local/apache2/conf/sites-available/

# Enable virtual hosts
RUN mkdir -p /usr/local/apache2/conf/sites-enabled && \
    ln -sf /usr/local/apache2/conf/sites-available/operators.conf /usr/local/apache2/conf/sites-enabled/ && \
    ln -sf /usr/local/apache2/conf/sites-available/users.conf /usr/local/apache2/conf/sites-enabled/

# Include sites-enabled in httpd.conf
RUN echo "Define APACHE_LOG_DIR /usr/local/apache2/logs" > /tmp/httpd-append.conf && \
    echo "Listen 3080" >> /tmp/httpd-append.conf && \
    echo "Listen 4080" >> /tmp/httpd-append.conf && \
    echo "DirectoryIndex index.php index.html index.htm" >> /tmp/httpd-append.conf && \
    echo "<FilesMatch \\.php$>" >> /tmp/httpd-append.conf && \
    echo "    SetHandler application/x-httpd-php" >> /tmp/httpd-append.conf && \
    echo "</FilesMatch>" >> /tmp/httpd-append.conf && \
    echo "Include conf/sites-enabled/*.conf" >> /tmp/httpd-append.conf && \
    cat /usr/local/apache2/conf/httpd.conf /tmp/httpd-append.conf > /tmp/httpd-new.conf && \
    mv /tmp/httpd-new.conf /usr/local/apache2/conf/httpd.conf

# Copy init script
COPY init.sh /var/www/daloradius/init.sh
RUN chmod +x /var/www/daloradius/init.sh

# Create data directory for lock files
RUN mkdir -p /data

# Create Apache log directories
RUN mkdir -p /usr/local/apache2/logs/daloradius

# Set the stop signal for proper container shutdown
STOPSIGNAL SIGTERM

EXPOSE 3080 4080

CMD ["/var/www/daloradius/init.sh"]
