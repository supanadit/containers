#!/bin/bash
set -e

# Get container IP address
CONTAINER_IP=$(hostname -i)

export GRAFANA_TEMPO_CONFIG=${GRAFANA_TEMPO_CONFIG:-/etc/tempo.yaml}

export GRAFANA_TEMPO_DATA_DIR=${GRAFANA_TEMPO_DATA_DIR:-/var/lib/tempo}
export GRAFANA_TEMPO_LISTEN_PORT_HTTP=${GRAFANA_TEMPO_LISTEN_PORT_HTTP:-3200}
export GRAFANA_TEMPO_STORAGE_BACKEND=${GRAFANA_TEMPO_STORAGE_BACKEND:-local}

export GRAFANA_TEMPO_TARGET=${GRAFANA_TEMPO_TARGET:-scalable-single-binary}

export GRAFANA_TEMPO_ADDRESS_FRONTEND_WORKER=${GRAFANA_TEMPO_ADDRESS_FRONTEND_WORKER:-${CONTAINER_IP}:9095}

# Configuring /etc/tempo.yaml
/opt/container/entrypoint.d/scripts/init/configuration.sh

GRAFANA_TEMPO_ARG_LIST=(
    "/usr/share/grafana/tempo"
    "-target=${GRAFANA_TEMPO_TARGET}"
    "-config.file=${GRAFANA_TEMPO_CONFIG}"
)

exec "${GRAFANA_TEMPO_ARG_LIST[@]}"