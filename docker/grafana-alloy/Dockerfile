FROM debian:bookworm

ARG GRAFANA_ALLOY_VERSION="1.12.1"

COPY setup.sh /opt/setup.sh
COPY setup/ /opt/setup/

# Run the complete setup in a single layer
RUN chmod +x /opt/setup.sh && \
    /opt/setup.sh && \
    rm /opt/setup.sh && \
    rm -rf /opt/setup

WORKDIR /opt/grafana

# Copy entrypoint script
COPY entrypoint.sh /opt/grafana/entrypoint.sh
RUN chmod +x /opt/grafana/entrypoint.sh

ENTRYPOINT ["/opt/grafana/entrypoint.sh"]