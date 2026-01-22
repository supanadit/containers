FROM debian:bookworm AS build

ARG GO_VERSION=1.23.12
ARG ETCD_VERSION=3.5.21

# Copy all setup scripts and resources
COPY setup.sh /opt/setup.sh
COPY setup/ /opt/setup/

# Run the complete setup in a single layer
RUN chmod +x /opt/setup.sh && \
    /opt/setup.sh && \
    rm /opt/setup.sh && \
    rm -rf /opt/setup/

FROM debian:bookworm-slim

COPY --from=build /usr/local/bin/etcd* /usr/local/bin/
COPY --from=build /usr/local/bin/etcdctl /usr/local/bin/etcdctl
COPY --from=build /usr/local/bin/etcdutl /usr/local/bin/etcdutl

# Copy entrypoint script
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]