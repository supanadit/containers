#!/bin/bash
set -euo pipefail

get_config_target() {
  echo "target: ${MIMIR_TARGET:-all}"
}

get_storage_prefix() {
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
}


{
  get_config_target
} > /etc/mimir.yaml