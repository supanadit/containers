#!/bin/bash

if [ ! -f /config/grafana.ini ]; then
    cp /usr/share/grafana/conf/defaults.ini /config/grafana.ini
fi

if [ -f /config/grafana.ini ]; then
    if [ -f /etc/grafana/grafana.ini ]; then
        rm /etc/grafana/grafana.ini
    fi
    ln -sf /config/grafana.ini /etc/grafana/grafana.ini
fi

GRAFANA_HOME_PATH=${GRAFANA_HOME_PATH:-/usr/share/grafana}
GRAFANA_CONFIG_PATH=${GRAFANA_CONFIG_PATH:-/etc/grafana/grafana.ini}

GRAFANA_ARG_LIST=(
    "/usr/share/grafana/bin/grafana"
    "server"
    "--homepath=${GRAFANA_HOME_PATH}"
    "--config=${GRAFANA_CONFIG_PATH}"
)

exec "${GRAFANA_ARG_LIST[@]}"