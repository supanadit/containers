#!/bin/bash
set -e

echo "=== Building and installing Citus ==="


cd /temp
git config --global http.sslVerify false

if [ "$CITUS_VERSION" = "main" ]; then
	git clone -b main --depth 1 https://github.com/citusdata/citus.git
else
	git clone -b v${CITUS_VERSION} --depth 1 https://github.com/citusdata/citus.git
fi

cd /temp/citus

chmod +x ./configure && PG_CONFIG=/usr/local/pgsql/bin/pg_config bash ./configure
make -s clean && make -s -j8 install

echo "=== Citus installed successfully ==="

echo "=== Verifying Citus installation ==="

PG_CONFIG="${PG_CONFIG:-/usr/local/pgsql/bin/pg_config}"

if ! "$PG_CONFIG" --version >/dev/null 2>&1; then
	echo "pg_config not available after Citus build" >&2
	exit 1
fi

SHARE_DIR="$("$PG_CONFIG" --sharedir)"
LIB_DIR="$("$PG_CONFIG" --pkglibdir)"

if [ ! -f "${SHARE_DIR}/extension/citus.control" ]; then
	echo "citus.control not found in ${SHARE_DIR}/extension" >&2
	exit 1
fi

if [ ! -f "${LIB_DIR}/citus.so" ]; then
	echo "citus.so not found in ${LIB_DIR}" >&2
	exit 1
fi

echo "=== Citus verification complete ==="
