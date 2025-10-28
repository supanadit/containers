#!/bin/bash
set -e

echo "=== Building and installing MinIO ==="

# Set Go environment variables
export GOROOT=/usr/local/go
export GOPATH=/go
export PATH=$GOPATH/bin:$GOROOT/bin:$PATH

# Create GOPATH directory if it doesn't exist
mkdir -p $GOPATH

cd /temp
git clone -b ${MINIO_VERSION} https://github.com/minio/minio.git --depth 1

cd minio
if [ -d "cmd/minio" ]; then
    go build -o bin/minio ./cmd/minio
elif [ -f "main.go" ]; then
    go build -o bin/minio .
else
    echo "Error: Unable to find MinIO build path. Check repository structure."
    exit 1
fi

mv bin/minio /usr/local/bin/minio

echo "=== MinIO installed successfully ==="
