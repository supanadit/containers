#!/bin/bash
set -euo pipefail

get_config_server() {
  cat <<EOF
server:
  http_listen_port: ${GRAFANA_LOKI_LISTEN_PORT_HTTP:-3100}
EOF
}

get_config_memberlist() {
  if [ "${ENABLE_MEMBERLIST:-false}" = "true" ]; then
    MEMBERLIST_BIND_PORT="${MEMBERLIST_BIND_PORT:-7946}"
    cat <<EOF
memberlist:
  bind_port: ${MEMBERLIST_BIND_PORT}
EOF
    if [ -n "${MEMBERLIST_JOIN_MEMBERS:-}" ]; then
      cat <<EOF
  join_members:
EOF
      IFS=',' read -ra MEMBERS <<< "${MEMBERLIST_JOIN_MEMBERS}"
      for member in "${MEMBERS[@]}"; do
        echo "  - ${member}"
      done
    fi
  fi
}

get_config_schema() {
  cat <<EOF
schema_config:
  configs:
EOF
  if [ "${GRAFANA_LOKI_STORAGE_BACKEND:-filesystem}" = "filesystem" ]; then
    cat <<EOF
  - from: 2020-10-24
    store: boltdb-shipper
    object_store: filesystem
    schema: v11
    index:
      prefix: index_
      period: 24h
EOF
  else
    cat <<EOF
  - from: 2023-01-01
    store: tsdb
    object_store: ${GRAFANA_LOKI_STORAGE_BACKEND}
    schema: v13
    index:
      prefix: index_
      period: 24h
EOF
  fi
}

get_config_storage() {
  cat <<EOF
common:
  path_prefix: /loki
  replication_factor: ${GRAFANA_LOKI_REPLICATION_FACTOR:-1}
EOF
  if [ "${GRAFANA_LOKI_TARGET:-scalable-single-binary}" != "backend" ]; then
    cat <<EOF
  compactor_address: http://backend:3100
EOF
  fi
  if [ "${GRAFANA_LOKI_STORAGE_BACKEND:-filesystem}" = "filesystem" ]; then
    cat <<EOF
  storage:
    filesystem:
      chunks_directory: ${GRAFANA_LOKI_DATA_DIR:-/loki}/chunks
      rules_directory: ${GRAFANA_LOKI_DATA_DIR:-/loki}/rules
EOF
  elif [ "${GRAFANA_LOKI_STORAGE_BACKEND}" = "s3" ]; then
    cat <<EOF
  storage:
    s3:
      endpoint: ${S3_ENDPOINT}
      bucketnames: ${S3_BUCKET}
      access_key_id: ${S3_ACCESS_KEY}
      secret_access_key: ${S3_SECRET_KEY}
      s3forcepathstyle: true
      insecure: ${S3_INSECURE:-false}
EOF
    if [ -n "${S3_REGION:-}" ]; then
      echo "      region: ${S3_REGION}"
    fi
  fi
  cat <<EOF
  ring:
    kvstore:
      store: ${RING_KVSTORE:-memberlist}
EOF
}

get_config_ruler() {
  if [ "${GRAFANA_LOKI_TARGET:-scalable-single-binary}" = "scalable-single-binary" ] || [ "${GRAFANA_LOKI_TARGET}" = "ruler" ]; then
    if [ "${GRAFANA_LOKI_STORAGE_BACKEND}" = "s3" ]; then
      cat <<EOF
ruler:
  storage:
    s3:
      bucketnames: ${S3_RULER_BUCKET:-${S3_BUCKET}}
      endpoint: ${S3_ENDPOINT}
      access_key_id: ${S3_ACCESS_KEY}
      secret_access_key: ${S3_SECRET_KEY}
      s3forcepathstyle: true
      insecure: ${S3_INSECURE:-false}
EOF
      if [ -n "${S3_REGION:-}" ]; then
        echo "      region: ${S3_REGION}"
      fi
    fi
  fi
}

get_config_compactor() {
  if [ "${GRAFANA_LOKI_TARGET:-scalable-single-binary}" = "scalable-single-binary" ] || [ "${GRAFANA_LOKI_TARGET}" = "backend" ]; then
    cat <<EOF
compactor:
  working_directory: ${GRAFANA_LOKI_DATA_DIR:-/loki}/compactor
EOF
  fi
}

get_config_querier() {
  if [ "${GRAFANA_LOKI_TARGET}" = "read" ]; then
    cat <<EOF
querier:
  max_concurrent: ${GRAFANA_LOKI_QUERIER_MAX_CONCURRENT:-10}
EOF
  fi
}

get_config_ingester() {
  if [ "${GRAFANA_LOKI_TARGET}" = "write" ]; then
    cat <<EOF
ingester:
  wal:
    dir: ${GRAFANA_LOKI_DATA_DIR:-/loki}/wal
EOF
  fi
}

get_config_distributor() {
  if [ "${GRAFANA_LOKI_TARGET}" = "write" ]; then
    cat <<EOF
distributor:
  ring:
    kvstore:
      store: ${RING_KVSTORE:-memberlist}
EOF
  fi
}

# Generate the config
{
  get_config_server
  get_config_memberlist
  get_config_schema
  get_config_storage
  get_config_ruler
  get_config_compactor
  get_config_querier
  get_config_ingester
  get_config_distributor
} > ${GRAFANA_LOKI_CONFIG}