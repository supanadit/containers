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

# Copy entrypoint scripts
COPY entrypoint.d/ /opt/container/entrypoint.d/

# Run the complete setup in a single layer
RUN chmod +x /opt/setup.sh && \
    /opt/setup.sh && \
    rm /opt/setup.sh && \
    rm -rf /opt/setup/

# Install BATS testing framework
RUN /opt/container/entrypoint.d/scripts/test/bats/install_bats.sh && \
    rm -rf /tmp/bats-*

ENV PATH="/usr/local/pgsql/bin:/opt/bats/bin:$PATH"

# Copy main entrypoint script
COPY entrypoint.d/entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# Make all entrypoint scripts executable
RUN find /opt/container/entrypoint.d/ -name "*.sh" -exec chmod +x {} \;

# Set the stop signal for proper container shutdown
STOPSIGNAL SIGTERM

ENTRYPOINT ["/entrypoint.sh"]