#!/bin/bash
set -e

echo "=== Building and installing Citus ==="


cd /temp
git config --global http.sslVerify false
git clone -b v${CITUS_VERSION} --depth 1 https://github.com/citusdata/citus.git

cd /temp/citus

chmod +x ./configure && bash ./configure
make -s clean && make -s -j8 install

echo "=== Citus installed successfully ==="
