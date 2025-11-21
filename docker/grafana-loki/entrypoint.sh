#!/bin/bash
set -e

GRAFANA_LOKI_CONFIG=${GRAFANA_LOKI_CONFIG:-/etc/loki/loki.yaml}

ENABLE_LISTEN_ALL_INTERFACE=${ENABLE_LISTEN_ALL_INTERFACE:-true}

if [ "${ENABLE_LISTEN_ALL_INTERFACE}" = "true" ]; then
    # It will check /config/loki.yaml on instance_addr: 127.0.0.1
    # Then will change to instance_addr: 0.0.0.0
    sed -i 's/instance_addr: 127.0.0.1/instance_addr: 0.0.0.0/g' /config/loki.yaml
fi

# TODO:
# 1. Add support for generating /etc/loki/loki.yaml, similar to grafana-mimir, grafana-tempo 

GRAFANA_LOKI_ARG_LIST=(
    "/usr/share/grafana/loki"
    "-config.file=${GRAFANA_LOKI_CONFIG}"
)

exec "${GRAFANA_LOKI_ARG_LIST[@]}"