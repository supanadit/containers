#!/bin/bash
set -euo pipefail

GRAFANA_MIMIR_CONFIG=${GRAFANA_MIMIR_CONFIG:-/etc/mimir.yaml}
MIMIR_BIN=${GRAFANA_MIMIR_BIN:-/usr/share/grafana/mimir}

# Configuring Target ( target: all,alertmanager,overrides-exporter )
export MIMIR_TARGET=${MIMIR_TARGET:-all}
export MIMIR_STORAGE_PREFIX=${MIMIR_STORAGE_PREFIX:-blocks}
export MIMIR_TSDB_DIR=${MIMIR_TSDB_DIR:-/var/lib/mimir/ingester}
export MIMIR_MEMBER_LIST=${MIMIR_MEMBER_LIST:-} # Comma separated list of ingester addresses

# Get total number of ingesters from MEMBER_LIST
if [ -n "${MIMIR_MEMBER_LIST}" ]; then
    IFS=',' read -r -a INGESTER_ADDRESSES <<< "${MIMIR_MEMBER_LIST}"
    TOTAL_INGESTERS=${#INGESTER_ADDRESSES[@]}
else
    TOTAL_INGESTERS=1
fi

export MIMIR_INGERSTER_REPLICATION_FACTOR=${MIMIR_INGESTER_REPLICATION_FACTOR:-${TOTAL_INGESTERS}}

# Generate mimir.yaml using configuration.sh
/opt/container/entrypoint.d/scripts/init/configuration.sh

if [ ! -x "${MIMIR_BIN}" ]; then
    echo "Unable to locate executable at ${MIMIR_BIN}" >&2
    exit 1
fi

MIMIR_ARG_LIST=(
    "${MIMIR_BIN}"
    "--config.file=${GRAFANA_MIMIR_CONFIG}"
)

if [ -n "${GRAFANA_MIMIR_EXTRA_ARGS:-}" ]; then
    read -r -a EXTRA_ARGS <<< "${GRAFANA_MIMIR_EXTRA_ARGS}"
    MIMIR_ARG_LIST+=("${EXTRA_ARGS[@]}")
fi

exec "${MIMIR_ARG_LIST[@]}"
