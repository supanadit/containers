FROM debian:bookworm

ARG PROMETHEUS_VERSION="3.7.2"

COPY setup.sh /opt/setup.sh
COPY setup/ /opt/setup/

# Run the complete setup in a single layer
RUN chmod +x /opt/setup.sh && \
    /opt/setup.sh && \
    rm /opt/setup.sh && \
    rm -rf /opt/setup

WORKDIR /opt/prometheus

# Copy entrypoint script
COPY entrypoint.sh /opt/prometheus/entrypoint.sh
RUN chmod +x /opt/prometheus/entrypoint.sh

ENTRYPOINT ["/opt/prometheus/entrypoint.sh"]

VOLUME ["/prometheus"]