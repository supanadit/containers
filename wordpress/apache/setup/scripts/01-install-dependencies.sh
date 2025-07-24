#!/bin/bash
set -e

echo "=== Installing system dependencies ==="

apt-get update && apt-get install -y \
    wget \
    unzip \
    build-essential \
    perl \
    libexpat1-dev \
    libpcre3-dev \
    libssl-dev \
    pkg-config \
    libxml2-dev \
    sqlite3 \
    libsqlite3-dev \
    libcurl4-openssl-dev \
    libonig-dev \
    zlib1g-dev \
    curl \
    git \
    autoconf \
    libmemcached-dev

echo "=== Dependencies installed successfully ==="
