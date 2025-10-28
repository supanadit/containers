#!/bin/bash
set -e

echo "=== Building and installing GOLANG ==="

mkdir /temp

cd /temp
curl -LO https://go.dev/dl/go${GO_VERSION}.linux-amd64.tar.gz
tar -C /usr/local -xzf go${GO_VERSION}.linux-amd64.tar.gz
rm -rf go${GO_VERSION}.linux-amd64.tar.gz

echo "=== GOLANG installed successfully ==="
