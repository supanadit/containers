#!/bin/bash
set -e

echo "=== Building and installing decoderbufs ==="

cd /temp
git clone -b ${DECODERBUFS_VERSION} --depth 1 https://github.com/debezium/postgres-decoderbufs.git

# Notes: We can build protobuf-c and libprotobuf-c from source, but it too complicated and too many step to execute which lead to very long build time
apt-get install -y protobuf-c-compiler libprotobuf-c-dev

mkdir -p /temp/postgres-decoderbufs/proto
cd /temp/postgres-decoderbufs/proto
protoc-c --c_out=../src/proto pg_logicaldec.proto

mkdir -p /temp/postgres-decoderbufs/build
cd /temp/postgres-decoderbufs

make
make install

echo "=== decoderbufs installed successfully ==="
