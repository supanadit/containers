#!/bin/bash

if [ ! -f /config/tempo.yaml ]; then
    cp /etc/tempo-sample.yaml /config/tempo.yaml
fi

GRAFANA_TEMPO_CONFIG=${GRAFANA_TEMPO_CONFIG:-/etc/tempo.yaml}

if [ ! -f ${GRAFANA_TEMPO_CONFIG} ]; then
    ln -sf /config/tempo.yaml ${GRAFANA_TEMPO_CONFIG}
fi

GRAFANA_TEMPO_ARG_LIST=(
    "/usr/share/grafana/tempo"
    "-config.file=${GRAFANA_TEMPO_CONFIG}"
)

exec "${GRAFANA_TEMPO_ARG_LIST[@]}"