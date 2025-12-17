#!/bin/bash
set -e

GRAFANA_ALLOY_CONFIG=${GRAFANA_ALLOY_CONFIG:-/etc/alloy/config.alloy}
GRAFANA_ALLOY_DATA=${GRAFANA_ALLOY_DATA:-/var/lib/alloy/data}

GRAFANA_ALLOY_EXPERIMENTAL_FEATURES=${GRAFANA_ALLOY_EXPERIMENTAL_FEATURES:-true}

GRAFANA_ALLOY_ARG_LIST=(
    "run"
    "${GRAFANA_ALLOY_CONFIG}"
    "--storage.path=${GRAFANA_ALLOY_DATA}"
    "--server.http.listen-addr=0.0.0.0:12345"
)

if [ "${GRAFANA_ALLOY_EXPERIMENTAL_FEATURES}" = "true" ]; then
    GRAFANA_ALLOY_ARG_LIST+=("--stability.level=experimental")
fi

exec "${GRAFANA_ALLOY_ARG_LIST[@]}"