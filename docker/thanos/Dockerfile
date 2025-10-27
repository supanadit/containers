FROM debian:bookworm

ARG THANOS_VERSION="0.39.2"

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