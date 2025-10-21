# Thanos

This image packages Thanos for long-term storage and querying of Prometheus metrics. The container downloads the upstream release archive during build and extracts the binary to `/usr/local/bin/thanos`.

## Components

Thanos consists of multiple components that can be run in this container:

- **query**: The main query endpoint that federates queries across multiple Prometheus instances and Thanos stores.
- **query-frontend**: Provides query caching, retry logic, and query splitting in front of the query component.
- **sidecar**: Runs alongside Prometheus to upload metrics to object storage and expose a gRPC endpoint for the query component.
- **store**: Exposes a gRPC endpoint for querying metrics stored in object storage.
- **compact**: Continuously compacts blocks in an object store bucket to improve query performance.
- **receive**: Accepts Prometheus remote write API requests and writes to local TSDB.
- **rule**: Evaluates Prometheus rules against given Query nodes, exposing Store API and storing old blocks in bucket.

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

# Run Thanos Receive
docker run \
  -p 10902:10902 \
  -p 10901:10901 \
  -e THANOS_COMPONENT=receive \
  -v thanos-data:/opt/thanos/data \
  thanos

# Run Thanos Ruler
docker run \
  -p 10902:10902 \
  -p 10901:10901 \
  -e THANOS_COMPONENT=rule \
  -e THANOS_QUERY_ENDPOINTS=http://thanos-query:9090 \
  -e THANOS_RULE_FILES=/etc/thanos/rules/*.yaml \
  -e THANOS_ALERTMANAGERS_URL=http://alertmanager:9093 \
  -v /path/to/rules:/etc/thanos/rules \
  -v thanos-data:/opt/thanos/data \
  thanos

# Run Thanos Compact with Minio S3
docker run \
  -e THANOS_COMPONENT=compact \
  -e THANOS_S3_BUCKET=thanos \
  -e THANOS_S3_ENDPOINT=http://minio:9000 \
  -e THANOS_S3_ACCESS_KEY=minioadmin \
  -e THANOS_S3_SECRET_KEY=minioadmin \
  -e THANOS_S3_INSECURE=true \
  thanos

# Run Thanos Compact with AWS S3
docker run \
  -e THANOS_COMPONENT=compact \
  -e THANOS_S3_BUCKET=my-thanos-bucket \
  -e THANOS_S3_ENDPOINT=https://s3.us-west-2.amazonaws.com \
  -e THANOS_S3_ACCESS_KEY=<aws-access-key> \
  -e THANOS_S3_SECRET_KEY=<aws-secret-key> \
  thanos
```

## Environment Variables

- `THANOS_COMPONENT`: Component to run (query, query-frontend, sidecar, store, compact, receive, rule). Default: query
- `THANOS_HTTP_ADDRESS`: HTTP listen address. Default: 0.0.0.0:10902
- `THANOS_GRPC_ADDRESS`: gRPC listen address for query, sidecar, store, receive, and rule components. Default: 0.0.0.0:10901
- `THANOS_QUERY_STORES`: Comma-separated list of store endpoints for query component
- `THANOS_QUERY_FRONTEND_DOWNSTREAM_URL`: Downstream query URL for query-frontend component (e.g., http://thanos-query:9090)
- `THANOS_DATA_DIR`: Data directory path. Default: /opt/thanos/data
- `THANOS_OBJSTORE_CONFIG`: Object store configuration as YAML content for compact, receive, and rule components
- `THANOS_OBJSTORE_CONFIG_FILE`: Path to object store configuration file for compact, receive, and rule components
- `THANOS_S3_BUCKET`: S3 bucket name for automatic S3 configuration
- `THANOS_S3_ENDPOINT`: S3 endpoint URL (e.g., https://s3.amazonaws.com or http://minio:9000)
- `THANOS_S3_ACCESS_KEY`: S3 access key
- `THANOS_S3_SECRET_KEY`: S3 secret key
- `THANOS_S3_INSECURE`: Use insecure connection (true/false, default: false) - useful for Minio
- `THANOS_S3_SIGNATURE_V2`: Use signature version 2 (true/false, default: false) - useful for Minio
- `THANOS_QUERY_ENDPOINTS`: Comma-separated list of query endpoints for rule component
- `THANOS_RULE_FILES`: Comma-separated list of rule files/directories for rule component
- `THANOS_ALERTMANAGERS_URL`: Comma-separated list of Alertmanager URLs for rule component