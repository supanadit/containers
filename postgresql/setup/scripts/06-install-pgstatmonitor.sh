#!/bin/bash
set -e

echo "=== Building and installing pg_stat_monitor ==="


cd /temp
git clone -b ${PG_STAT_MONITOR_VERSION} --depth 1 https://github.com/percona/pg_stat_monitor.git

cd /temp/pg_stat_monitor

make USE_PGXS=1
make USE_PGXS=1 install

echo "=== pg_stat_monitor installed successfully ==="
