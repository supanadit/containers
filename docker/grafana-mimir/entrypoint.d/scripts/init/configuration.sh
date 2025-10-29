#!/bin/bash
set -euo pipefail

get_config_target() {
  echo "target: ${MIMIR_TARGET:-all}"
}

get_config_blocks_storage() {
  if [ -n "${MIMIR_STORAGE_PREFIX:-}" ]; then
    cat <<EOF
blocks_storage:
  storage_prefix: ${MIMIR_STORAGE_PREFIX}
EOF
    get_tsdb_dir
  fi
}

get_tsdb_dir() {
  if [ -n "${MIMIR_TSDB_DIR:-}" ]; then
    cat <<EOF
  tsdb:
    dir: ${MIMIR_TSDB_DIR}
EOF
  fi
  
  # Check if directory exists, if not create it
  if [ ! -d "${MIMIR_TSDB_DIR}" ]; then
    mkdir -p "${MIMIR_TSDB_DIR}"
  fi
}

get_config_replication() {
  cat <<EOF
ingester:
  ring:
    replication_factor: ${MIMIR_INGERSTER_REPLICATION_FACTOR}
EOF
}

get_config_memberlist() {
  if [ -n "${MIMIR_MEMBER_LIST:-}" ]; then
    cat <<EOF
memberlist:
  join_members: [$(echo "${MIMIR_MEMBER_LIST}")]
EOF
  fi
}

{
  get_config_target
  get_config_blocks_storage
  get_config_replication
  get_config_memberlist
} > /etc/mimir.yaml