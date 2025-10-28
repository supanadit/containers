#!/bin/bash
set -e

GRAFANA_HOME_PATH=${GRAFANA_HOME_PATH:-/var/lib/grafana}
GRAFANA_CONFIG_PATH=${GRAFANA_CONFIG_PATH:-/etc/grafana/grafana.ini}

GRAFANA_ARG_LIST=(
    "/usr/share/grafana/bin/grafana"
    "server"
    "--homepath=${GRAFANA_HOME_PATH}"
    "--config=${GRAFANA_CONFIG_PATH}"
)

exec "${GRAFANA_ARG_LIST[@]}"