# Thanos

This image packages Thanos for long-term storage and querying of Prometheus metrics. The container downloads the upstream release archive during build and extracts the binary to `/usr/local/bin/thanos`.

## Components

Thanos consists of multiple components that can be run in this container:

- **query**: The main query endpoint that federates queries across multiple Prometheus instances and Thanos stores.
- **sidecar**: Runs alongside Prometheus to upload metrics to object storage and expose a gRPC endpoint for the query component.
- **store**: Exposes a gRPC endpoint for querying metrics stored in object storage.

## Usage

```bash
# Build
cd docker/thanos
docker build -t thanos .

# Run Thanos Query (default)
docker run \
  -p 10902:10902 \
  -e THANOS_QUERY_STORES=prometheus:9090 \
  thanos

# Run Thanos Sidecar alongside Prometheus
docker run \
  -p 10901:10901 \
  -e THANOS_COMPONENT=sidecar \
  -v prometheus-data:/opt/thanos/data \
  thanos
```

## Environment Variables

- `THANOS_COMPONENT`: Component to run (query, sidecar, store). Default: query
- `THANOS_HTTP_ADDRESS`: HTTP listen address. Default: 0.0.0.0:10902
- `THANOS_GRPC_ADDRESS`: gRPC listen address. Default: 0.0.0.0:10901
- `THANOS_QUERY_STORES`: Comma-separated list of store endpoints for query component
- `THANOS_DATA_DIR`: Data directory path. Default: /opt/thanos/data