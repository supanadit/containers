#!/bin/bash
set -euo pipefail

get_config_auth() {
  cat <<EOF
auth_enabled: false
EOF
}

get_config_memberlist() {
  if [ -n "${GRAFANA_LOKI_MEMBERLIST:-}" ]; then
    echo "memberlist:"
    echo "  join_members:"
    IFS=',' read -ra MEMBERS <<< "$GRAFANA_LOKI_MEMBERLIST"
    for member in "${MEMBERS[@]}"; do
      echo "    - \"$member\""
    done
    cat <<EOF
  dead_node_reclaim_time: 30s
  gossip_to_dead_nodes_time: 15s
  left_ingesters_timeout: 30s
  bind_addr: ['0.0.0.0']
  bind_port: 7946
  gossip_interval: 2s
EOF
  fi
}

get_config_server() {
  cat <<EOF
server:
  http_listen_address: 0.0.0.0
  http_listen_port: ${GRAFANA_LOKI_LISTEN_PORT_HTTP}
  grpc_listen_port: ${GRAFANA_LOKI_LISTEN_PORT_GRPC}
EOF
}

get_config_common_compactor() {
  if [ -n "${GRAFANA_LOKI_COMPACTOR_ADDRESS:-}" ]; then
    cat <<EOF
  compactor_address: ${GRAFANA_LOKI_COMPACTOR_ADDRESS}
EOF
  fi
}

get_config_common_ring() {
  if [ -n "${GRAFANA_LOKI_MEMBERLIST:-}" ]; then
    cat <<EOF
  ring:
    kvstore:
      store: memberlist
EOF
  else
    cat <<EOF
  ring:
    kvstore:
      store: inmemory
EOF
  fi
}

get_config_common() {
  cat <<EOF
common:
  path_prefix: ${GRAFANA_LOKI_DATA_DIR}
  storage:
    filesystem:
      chunks_directory: ${GRAFANA_LOKI_DATA_DIR}/chunks
      rules_directory: ${GRAFANA_LOKI_DATA_DIR}/rules
  replication_factor: 1
EOF
  if [ -n "${GRAFANA_LOKI_INSTANCE_ADDRESS}" ]; then
    cat <<EOF
  instance_address: ${GRAFANA_LOKI_INSTANCE_ADDRESS}
EOF
  fi
  get_config_common_ring
  get_config_common_compactor
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
  get_config_memberlist
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