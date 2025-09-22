#!/bin/bash
set -e

echo "=== Building and installing ETCD ==="

# Set Go environment variables
export GOROOT=/usr/local/go
export GOPATH=/go
export PATH=$GOPATH/bin:$GOROOT/bin:$PATH

# Create GOPATH directory if it doesn't exist
mkdir -p $GOPATH

cd /temp
git clone -b ${ETCD_VERSION} https://github.com/etcd-io/etcd.git

cd etcd
./build.sh

cp -r bin/* /usr/local/bin/

echo "=== ETCD installed successfully ==="
