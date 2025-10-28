#!/bin/bash
set -euo pipefail

GRAFANA_MIMIR_CONFIG=${GRAFANA_MIMIR_CONFIG:-/etc/mimir.yaml}
MIMIR_BIN=${GRAFANA_MIMIR_BIN:-/usr/share/grafana/mimir}

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
