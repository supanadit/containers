#!/bin/bash
set -e

echo "=== Building and installing Patroni ==="

cd /temp
git clone -b ${PATRONI_VERSION} --depth 1 https://github.com/patroni/patroni.git

cd /temp/patroni

pip install "psycopg[c]"
pip install cdiff

pip install -r requirements.txt
pip install .[etcd]

echo "=== Patroni installed successfully ==="
