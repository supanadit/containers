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
    gosu \
    && rm -rf /var/lib/apt/lists/*

RUN curl -LsS https://r.mariadb.com/downloads/mariadb_repo_setup | bash -s -- --maxscale && \
    apt-get update && \
    apt-get install -y --no-install-recommends maxscale && \
    rm -rf /var/lib/apt/lists/* /etc/apt/sources.list.d/mariadb.list

COPY entrypoint.d/ /opt/container/entrypoint.d/
COPY entrypoint.d/entrypoint.sh /entrypoint.sh

RUN chmod +x /entrypoint.sh && \
    find /opt/container/entrypoint.d -type f -name "*.sh" -exec chmod +x {} \;

EXPOSE 3306 8989

HEALTHCHECK --interval=30s --timeout=10s --start-period=30s --retries=3 \
    CMD maxctrl list servers || exit 1

ENTRYPOINT ["/entrypoint.sh"]