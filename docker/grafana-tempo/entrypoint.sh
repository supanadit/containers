#!/bin/bash
set -e

GRAFANA_TEMPO_CONFIG=${GRAFANA_TEMPO_CONFIG:-/etc/tempo.yaml}

GRAFANA_TEMPO_ARG_LIST=(
    "/usr/share/grafana/tempo"
    "-config.file=${GRAFANA_TEMPO_CONFIG}"
)

exec "${GRAFANA_TEMPO_ARG_LIST[@]}"