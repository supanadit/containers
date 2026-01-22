#!/bin/bash
set -e

echo "=== Installing system dependencies ==="

apt-get update -y && apt-get install -y \
    curl \
    wget \
    git \
    make \
    build-essential

echo "=== Dependencies installed successfully ==="
