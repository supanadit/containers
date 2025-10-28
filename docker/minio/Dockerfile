FROM debian:bookworm AS build

ARG GO_VERSION=1.23.12
# This is the last best version of MinIO, above this version they changed to Community Edition
# in Community Edition, some features are removed or not accessible in the dashboard
ARG MINIO_VERSION=RELEASE.2025-04-22T22-12-26Z

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