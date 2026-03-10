FROM debian:bookworm

ARG GRAFANA_PYROSCOPE_VERSION="1.16.0"

# Build metadata
ARG BUILD_DATE
ARG VCS_REF

LABEL org.opencontainers.image.created=$BUILD_DATE \
    org.opencontainers.image.revision=$VCS_REF \
    org.opencontainers.image.title="Grafana Pyroscope" \
    org.opencontainers.image.description="Optimized Grafana Pyroscope container for continuous profiling" \ 
    org.opencontainers.image.authors="Supan Adit Pratama <email@supanadit.com>" \
    org.opencontainers.image.source=https://github.com/supanadit/containers

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