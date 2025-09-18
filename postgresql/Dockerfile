FROM debian:bookworm

ARG POSTGRESQL_VERSION=13.5
ARG PGBACKREST_VERSION=2.56.0
ARG CITUS_VERSION=11.3.1
ARG PG_STAT_MONITOR_VERSION=2.2.0
ARG DECODERBUFS_VERSION=v3.2.2.Final
ARG PYTHON_VERSION=v3.11.2
ARG PATRONI_VERSION=v3.0.2

ENV PG_CONFIG=/usr/local/pgsql/bin/pg_config

# Copy all setup scripts and resources
COPY setup.sh /opt/setup.sh
COPY setup/ /opt/setup/

# Run the complete setup in a single layer
RUN chmod +x /opt/setup.sh && \
    /opt/setup.sh && \
    rm /opt/setup.sh && \
    rm -rf /opt/setup/

# Copy entrypoint script
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]