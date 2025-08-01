#!/bin/bash

if [ ! -f /etc/grafana/grafana.ini ]; then
    cp /usr/share/grafana/conf/defaults.ini /etc/grafana/grafana.ini
fi

exec "$@"