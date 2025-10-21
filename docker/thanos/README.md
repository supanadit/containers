# Thanos

This image packages Thanos for long-term storage and querying of Prometheus metrics. The container downloads the upstream release archive during build and extracts the binary to `/usr/local/bin/thanos`.

## Components

Thanos consists of multiple components that can be run in this container:

- **query**: The main query endpoint that federates queries across multiple Prometheus instances and Thanos stores.
- **query-frontend**: Provides query caching, retry logic, and query splitting in front of the query component.
- **sidecar**: Runs alongside Prometheus to upload metrics to object storage and expose a gRPC endpoint for the query component.
- **store**: Exposes a gRPC endpoint for querying metrics stored in object storage.
- **compact**: Continuously compacts blocks in an object store bucket to improve query performance.

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

# Run Thanos Query Frontend
docker run \
  -p 10902:10902 \
  -e THANOS_COMPONENT=query-frontend \
  -e THANOS_QUERY_FRONTEND_DOWNSTREAM_URL=http://thanos-query:9090 \
  thanos

# Run Thanos Compact
docker run \
  -v /path/to/objstore-config.yaml:/config/objstore.yaml \
  -e THANOS_COMPONENT=compact \
  -e THANOS_OBJSTORE_CONFIG_FILE=/config/objstore.yaml \
  thanos
```

## Environment Variables

- `THANOS_COMPONENT`: Component to run (query, query-frontend, sidecar, store, compact). Default: query
- `THANOS_HTTP_ADDRESS`: HTTP listen address. Default: 0.0.0.0:10902
- `THANOS_GRPC_ADDRESS`: gRPC listen address for query, sidecar, and store components. Default: 0.0.0.0:10901
- `THANOS_QUERY_STORES`: Comma-separated list of store endpoints for query component
- `THANOS_QUERY_FRONTEND_DOWNSTREAM_URL`: Downstream query URL for query-frontend component (e.g., http://thanos-query:9090)
- `THANOS_DATA_DIR`: Data directory path. Default: /opt/thanos/data
- `THANOS_OBJSTORE_CONFIG`: Object store configuration as YAML content for compact component
- `THANOS_OBJSTORE_CONFIG_FILE`: Path to object store configuration file for compact component