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
    pkg-config \
    libpq-dev \
    postgresql-client \
    flex \
    bison

echo "=== Dependencies installed successfully ==="
