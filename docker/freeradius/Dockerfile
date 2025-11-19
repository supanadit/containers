FROM debian:bookworm

ARG FREERADIUS_VERSION="3.2.8"

COPY setup.sh /opt/setup.sh
COPY setup/ /opt/setup/

# Run the complete setup in a single layer
RUN chmod +x /opt/setup.sh && \
    /opt/setup.sh && \
    rm /opt/setup.sh && \
    rm -rf /opt/setup

WORKDIR /usr/local/freeradius

# Copy entrypoint script
COPY entrypoint.sh /usr/local/freeradius/entrypoint.sh
RUN chmod +x /usr/local/freeradius/entrypoint.sh

ENTRYPOINT ["/usr/local/freeradius/entrypoint.sh"]

VOLUME ["/usr/local/freeradius/etc/raddb"]