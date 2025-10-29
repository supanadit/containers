#!/bin/bash
set -e

export GF_PATHS_HOME=${GF_PATHS_HOME:-/usr/share/grafana}
export GF_PATHS_DATA=${GF_PATHS_DATA:-/var/lib/grafana}
export GF_PATHS_LOGS=${GF_PATHS_LOGS:-/var/log/grafana}
export GF_PATHS_CONFIG=${GF_PATHS_CONFIG:-/etc/grafana/grafana.ini}


# /usr/share/grafana/conf/defaults.ini is the default config file provided by Grafana
# If /etc/grafana/grafana.ini does not exist, copy the default config
if [ ! -f "${GF_PATHS_CONFIG}" ]; then
    echo "=== Copying default Grafana config to ${GF_PATHS_CONFIG} ==="
    cp /usr/share/grafana/conf/defaults.ini "${GF_PATHS_CONFIG}"
fi

GRAFANA_ARG_LIST=(
    "/usr/share/grafana/bin/grafana"
    "server"
    "--homepath=${GF_PATHS_HOME}"
    "--config=${GF_PATHS_CONFIG}"
    "--packaging=docker"
    "cfg:default.paths.data=${GF_PATHS_DATA}"
    "cfg:default.paths.logs=${GF_PATHS_LOGS}"
    "cfg:default.paths.plugins=${GF_PATHS_PLUGINS}"
)

exec "${GRAFANA_ARG_LIST[@]}"