#!/bin/bash
set -e

export GRAFANA_LOKI_CONFIG=${GRAFANA_LOKI_CONFIG:-/etc/loki/loki.yaml}

export GRAFANA_LOKI_DATA_DIR=${GRAFANA_LOKI_DATA_DIR:-/var/lib/loki}
export GRAFANA_LOKI_LISTEN_PORT_HTTP=${GRAFANA_LOKI_LISTEN_PORT_HTTP:-3100}
export GRAFANA_LOKI_LISTEN_PORT_GRPC=${GRAFANA_LOKI_LISTEN_PORT_GRPC:-9096}
export GRAFANA_LOKI_STORAGE_BACKEND=${GRAFANA_LOKI_STORAGE_BACKEND:-filesystem}

export GRAFANA_LOKI_INSTANCE_ADDRESS=${GRAFANA_LOKI_INSTANCE_ADDRESS:-0.0.0.0}

# Configuring /etc/loki/loki.yaml
/opt/container/entrypoint.d/scripts/init/configuration.sh

GRAFANA_LOKI_ARG_LIST=(
    "/usr/share/grafana/loki"
    "-config.file=${GRAFANA_LOKI_CONFIG}"
)

exec "${GRAFANA_LOKI_ARG_LIST[@]}"