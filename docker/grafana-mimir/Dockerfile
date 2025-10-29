FROM debian:bookworm

ARG GRAFANA_MIMIR_VERSION="2.17.1"

COPY setup.sh /opt/setup.sh
COPY setup/ /opt/setup/

# Run the complete setup in a single layer
RUN chmod +x /opt/setup.sh && \
    /opt/setup.sh && \
    rm /opt/setup.sh && \
    rm -rf /opt/setup

WORKDIR /opt/grafana

# Copy entrypoint scripts (volatile files that change frequently during development)
COPY entrypoint.d/ /opt/container/entrypoint.d/

# Ensure all scripts in entrypoint.d are executable
RUN chmod -R +x /opt/container/entrypoint.d/

# Copy main entrypoint script
COPY entrypoint.d/entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
