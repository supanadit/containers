#!/bin/bash
set -e

echo "=== Building and installing HypoPG ==="

cd /temp
git clone -b ${HYPO_PG_VERSION} --depth 1 https://github.com/HypoPG/hypopg.git

cd /temp/hypopg

make
make install

echo "=== HypoPG installed successfully ==="