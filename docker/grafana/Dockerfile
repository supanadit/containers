FROM debian:bookworm

ARG GRAFANA_VERSION="12.2.1"
ARG GRAFANA_EDITION="oss"

# Build metadata
ARG BUILD_DATE
ARG VCS_REF

LABEL org.opencontainers.image.created=$BUILD_DATE \
    org.opencontainers.image.revision=$VCS_REF \
    org.opencontainers.image.title="Grafana" \
    org.opencontainers.image.description="Optimized Grafana container for analytics and monitoring platform" \
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