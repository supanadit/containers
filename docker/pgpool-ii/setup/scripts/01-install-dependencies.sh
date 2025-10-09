#!/bin/bash
set -e

echo "=== Installing system dependencies ==="

apt-get update -y && apt-get install -y \
    curl \
    wget \
    git \
    build-essential \
    autoconf \
    automake \
    libtool \
    pkg-config

echo "=== Dependencies installed successfully ==="
