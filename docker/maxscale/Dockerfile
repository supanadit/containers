FROM debian:bookworm-slim

ARG MAXSCALE_VERSION=24.02.1

LABEL org.opencontainers.image.title="MaxScale" \
    org.opencontainers.image.description="MariaDB MaxScale database proxy" \
    org.opencontainers.image.authors="Supan Adit Pratama <email@supanadit.com>"

RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    ca-certificates \
    gnupg2 \
    lsb-release \
    mariadb-client \
    netcat-openbsd \
    openssl \
    procps \
    sudo \
    && rm -rf /var/lib/apt/lists/*

RUN curl -fsSL https://downloads.mariadb.com/MaxScale/MariaDB-MaxScale-24.02.1-kkulls-latest.debian.bookworm.amd64.deb -o /tmp/maxscale.deb && \
    dpkg --install --force-depends /tmp/maxscale.deb || apt-get install -f -y && \
    rm -f /tmp/maxscale.deb

COPY entrypoint.d/ /opt/container/entrypoint.d/
COPY entrypoint.d/entrypoint.sh /entrypoint.sh

RUN chmod +x /entrypoint.sh

EXPOSE 3306 8989

HEALTHCHECK --interval=30s --timeout=10s --start-period=30s --retries=3 \
    CMD maxctrl list servers || exit 1

ENTRYPOINT ["/entrypoint.sh"]