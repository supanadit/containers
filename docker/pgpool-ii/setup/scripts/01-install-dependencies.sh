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
    bison \
    jq \
    gosu

echo "=== Creating postgres user ==="
# Create postgres user and group if they don't exist
if ! id -u postgres >/dev/null 2>&1; then
    groupadd -r postgres
    useradd -r -g postgres -d /var/lib/postgresql -s /bin/bash postgres
fi

echo "=== Dependencies installed successfully ==="
