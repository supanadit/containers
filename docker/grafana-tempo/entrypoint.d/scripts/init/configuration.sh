#!/bin/bash
set -euo pipefail

get_config_http_listen() {
    cat <<EOF
  http_listen_port: 3200
EOF
}

get_config_server() {
    cat <<EOF
server:
EOF
  get_config_http_listen
}

get_config_storage_trace_local() {
  # If GRAFANA_TEMPO_STORAGE_BACKEND is local
  if [ "${GRAFANA_TEMPO_STORAGE_BACKEND}" = "local" ]; then
    cat <<EOF
      local:
        path: ${GRAFANA_TEMPO_DATA_DIR}/blocks
EOF
  fi
}

get_config_storage_trace() {
    cat <<EOF
    trace:
      backend: ${GRAFANA_TEMPO_STORAGE_BACKEND}
      wal:
        path: ${GRAFANA_TEMPO_DATA_DIR}/wal
EOF
  get_config_storage_trace_local
}

get_config_storage() {
    cat <<EOF
storage:
EOF
  get_config_storage_trace
}

get_config_metric_generator_storage() {
  # If GRAFANA_TEMPO_STORAGE_BACKEND is local
  if [ "${GRAFANA_TEMPO_STORAGE_BACKEND}" = "local" ]; then
    cat <<EOF
  storage:
    path: ${GRAFANA_TEMPO_DATA_DIR}/generators/wal
EOF
  fi
}

get_config_metric_generator() {
  # TODO: External Labels must be configurable
  cat <<EOF
metrics_generator:
  registry:
    external_labels:
EOF
  # Check if any EXTERNAL_LABELS_ env vars are defined
  if [ -z "$(env | grep '^EXTERNAL_LABELS_')" ]; then
    # Use default values if no env vars are set
    echo "      source: tempo"
    echo "      cluster: demo"
  else
    # Dynamically add external labels from env vars prefixed with EXTERNAL_LABELS_
    for var in $(env | grep '^EXTERNAL_LABELS_' | cut -d'=' -f1); do
      key=$(echo "$var" | sed 's/^EXTERNAL_LABELS_//' | tr '[:upper:]' '[:lower:]')
      value="${!var}"
      echo "      $key: $value"
    done
  fi
  get_config_metric_generator_storage
}

get_config_querier() {
  cat <<EOF
querier:
  frontend_worker:
    frontend_address: ${GRAFANA_TEMPO_ADDRESS_FRONTEND_WORKER}
EOF
}

{
  get_config_server
  get_config_storage
  get_config_metric_generator
  get_config_querier
} > ${GRAFANA_TEMPO_CONFIG}