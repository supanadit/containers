#!/bin/bash
set -e

echo "=== Installing system dependencies ==="

apt-get update -y && apt-get install -y \
    curl \
    wget \
    tar \
    gzip \
    ca-certificates \
    build-essential \
    procps \
    python3 \
    python3-pip

echo "=== Dependencies installed successfully ==="