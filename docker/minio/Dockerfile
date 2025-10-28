FROM debian:bookworm AS build

ARG GO_VERSION=1.23.12
ARG MINIO_VERSION=RELEASE.2025-10-15T17-29-55Z

# Copy all setup scripts and resources
COPY setup.sh /opt/setup.sh
COPY setup/ /opt/setup/

# Run the complete setup in a single layer
RUN chmod +x /opt/setup.sh && \
    /opt/setup.sh && \
    rm /opt/setup.sh && \
    rm -rf /opt/setup/

FROM debian:bookworm-slim

COPY --from=build /usr/local/bin/minio /usr/local/bin/minio

# Copy entrypoint script
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]