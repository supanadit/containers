FROM debian:bookworm

ARG THANOS_VERSION="0.40.1"

# Build metadata
ARG BUILD_DATE
ARG VCS_REF

LABEL org.opencontainers.image.created=$BUILD_DATE \
    org.opencontainers.image.revision=$VCS_REF \
    org.opencontainers.image.title="Thanos with Build Optimization" \
    org.opencontainers.image.description="Optimized Thanos container with advanced features" \
    org.opencontainers.image.authors="Supan Adit Pratama <email@supanadit.com>" \
    org.opencontainers.image.source=https://github.com/supanadit/containers

COPY setup.sh /opt/setup.sh
COPY setup/ /opt/setup/

# Run the complete setup in a single layer
RUN chmod +x /opt/setup.sh && \
    /opt/setup.sh && \
    rm /opt/setup.sh && \
    rm -rf /opt/setup

WORKDIR /opt/thanos

# Copy entrypoint script
COPY entrypoint.sh /opt/thanos/entrypoint.sh
RUN chmod +x /opt/thanos/entrypoint.sh

ENTRYPOINT ["/opt/thanos/entrypoint.sh"]

VOLUME ["/thanos"]