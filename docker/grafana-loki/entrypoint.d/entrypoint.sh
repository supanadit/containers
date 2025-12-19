#!/bin/bash
set -e

export GRAFANA_LOKI_CONFIG=${GRAFANA_LOKI_CONFIG:-/etc/loki/loki.yaml}

export GRAFANA_LOKI_DATA_DIR=${GRAFANA_LOKI_DATA_DIR:-/var/lib/loki}
export GRAFANA_LOKI_LISTEN_PORT_HTTP=${GRAFANA_LOKI_LISTEN_PORT_HTTP:-3100}
export GRAFANA_LOKI_LISTEN_PORT_GRPC=${GRAFANA_LOKI_LISTEN_PORT_GRPC:-9096}
export GRAFANA_LOKI_STORAGE_BACKEND=${GRAFANA_LOKI_STORAGE_BACKEND:-filesystem}

export GRAFANA_LOKI_INSTANCE_ADDRESS=${GRAFANA_LOKI_INSTANCE_ADDRESS:-}

# Available targets: ( By default if not set, type all is used )
# read
# write
# backend
# Docs: https://grafana.com/docs/loki/latest/get-started/components
# For Microservcice mode: https://grafana.com/docs/loki/latest/get-started/deployment-modes/#microservices-mode
export GRAFANA_LOKI_TARGET=${GRAFANA_LOKI_TARGET:-}
export GRAFANA_LOKI_MEMBERLIST=${GRAFANA_LOKI_MEMBERLIST:-}
export GRAFANA_LOKI_COMPACTOR_ADDRESS=${GRAFANA_LOKI_COMPACTOR_ADDRESS:-}

# Configuring /etc/loki/loki.yaml
/opt/container/entrypoint.d/scripts/init/configuration.sh

GRAFANA_LOKI_ARG_LIST=(
    "/usr/share/grafana/loki"
    "-config.file=${GRAFANA_LOKI_CONFIG}"
)

if [ -n "$GRAFANA_LOKI_TARGET" ]; then
    GRAFANA_LOKI_ARG_LIST+=("-target=${GRAFANA_LOKI_TARGET}")
    if [ "$GRAFANA_LOKI_TARGET" = "backend" ]; then
        GRAFANA_LOKI_ARG_LIST+=("-legacy-read-mode=false")
    fi
fi

exec "${GRAFANA_LOKI_ARG_LIST[@]}"