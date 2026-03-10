#!/bin/bash
set -e

echo "=== Building and installing pg_cron ==="


cd /temp
git config --global http.sslVerify false

if [ "$PG_CRON_VERSION" = "main" ]; then
	git clone -b main --depth 1 https://github.com/citusdata/pg_cron.git
else
	git clone -b v${PG_CRON_VERSION} --depth 1 https://github.com/citusdata/pg_cron.git
fi

cd /temp/pg_cron

chmod +x ./configure && PG_CONFIG=/usr/local/pgsql/bin/pg_config bash ./configure
make -s clean && make -s -j8 install

echo "=== pg_cron installed successfully ==="

echo "=== Verifying pg_cron installation ==="

PG_CONFIG="${PG_CONFIG:-/usr/local/pgsql/bin/pg_config}"

if ! "$PG_CONFIG" --version >/dev/null 2>&1; then
	echo "pg_config not available after pg_cron build" >&2
	exit 1
fi

SHARE_DIR="$("$PG_CONFIG" --sharedir)"
LIB_DIR="$("$PG_CONFIG" --pkglibdir)"

if [ ! -f "${SHARE_DIR}/extension/pg_cron.control" ]; then
	echo "pg_cron.control not found in ${SHARE_DIR}/extension" >&2
	exit 1
fi

if [ ! -f "${LIB_DIR}/pg_cron.so" ]; then
	echo "pg_cron.so not found in ${LIB_DIR}" >&2
	exit 1
fi

echo "=== pg_cron verification complete ==="