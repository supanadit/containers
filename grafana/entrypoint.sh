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
GRAFANA_CFG_DEFAULT_PATHS_DATA=${GRAFANA_CFG_DEFAULT_PATHS_DATA:-/var/lib/grafana}
GRAFANA_CFG_DEFAULT_PATHS_LOGS=${GRAFANA_CFG_DEFAULT_PATHS_LOGS:-/var/log/grafana}
GRAFANA_CFG_DEFAULT_PATHS_PLUGINS=${GRAFANA_CFG_DEFAULT_PATHS_PLUGINS:-/var/lib/grafana/plugins}
GRAFANA_CFG_DEFAULT_PATHS_PROVISIONING=${GRAFANA_CFG_DEFAULT_PATHS_PROVISIONING:-/etc/grafana/provisioning}

GRAFANA_ARG_LIST=(
    "/usr/share/grafana/bin/grafana"
    "server"
    "--homepath=${GRAFANA_HOME_PATH}"
    "--config=${GRAFANA_CONFIG_PATH}"
    "cfg:default.paths.data=${GRAFANA_CFG_DEFAULT_PATHS_DATA}"
    "cfg:default.paths.logs=${GRAFANA_CFG_DEFAULT_PATHS_LOGS}"
    "cfg:default.paths.plugins=${GRAFANA_CFG_DEFAULT_PATHS_PLUGINS}"
    "cfg:default.paths.provisioning=${GRAFANA_CFG_DEFAULT_PATHS_PROVISIONING}"
)

exec "${GRAFANA_ARG_LIST[@]}"