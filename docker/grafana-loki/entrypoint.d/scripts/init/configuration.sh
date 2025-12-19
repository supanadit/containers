#!/bin/bash
set -euo pipefail

get_config_auth() {
  cat <<EOF
auth_enabled: false
EOF
}

get_config_server() {
  cat <<EOF
server:
  http_listen_port: ${GRAFANA_LOKI_LISTEN_PORT_HTTP}
  grpc_listen_port: ${GRAFANA_LOKI_LISTEN_PORT_GRPC}
EOF
}

get_config_common() {
  cat <<EOF
common:
  instance_addr: ${GRAFANA_LOKI_INSTANCE_ADDRESS}
  path_prefix: ${GRAFANA_LOKI_DATA_DIR}
  storage:
    filesystem:
      chunks_directory: ${GRAFANA_LOKI_DATA_DIR}/chunks
      rules_directory: ${GRAFANA_LOKI_DATA_DIR}/rules
  replication_factor: 1
  ring:
    kvstore:
      store: inmemory
EOF
}

get_config_query_range() {
  cat <<EOF
query_range:
  results_cache:
    cache:
      embedded_cache:
        enabled: true
        max_size_mb: 100
EOF
}

get_config_limits_config() {
  cat <<EOF
limits_config:
  metric_aggregation_enabled: true
EOF
}

get_config_schema_config() {
  cat <<EOF
schema_config:
  configs:
    - from: 2020-10-24
      store: tsdb
      object_store: filesystem
      schema: v13
      index:
        prefix: index_
        period: 24h
EOF
}

get_config_pattern_ingester() {
  cat <<EOF
pattern_ingester:
  enabled: true
  metric_aggregation:
    loki_address: localhost:3100
EOF
}

get_config_ruler() {
  cat <<EOF
ruler:
  alertmanager_url: http://localhost:9093
EOF
}

get_config_frontend(){
  cat <<EOF
frontend:
  encoding: protobuf
EOF
}

get_config_compactor() {
  cat <<EOF
compactor:
  working_directory: ${GRAFANA_LOKI_DATA_DIR}/retention
  delete_request_store: filesystem
  retention_enabled: true
EOF
}

# Generate the config
{
  get_config_auth
  get_config_server
  get_config_common
  get_config_query_range
  get_config_limits_config
  get_config_schema_config
  get_config_pattern_ingester
  get_config_ruler
  get_config_frontend
  get_config_compactor
} > ${GRAFANA_LOKI_CONFIG}