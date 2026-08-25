#!/bin/bash
set -e

echo "=== Installing system dependencies ==="

apt-get update -y && apt-get install -y --no-install-recommends \
    curl \
    wget \
    git \
    ca-certificates \
    build-essential \
    cmake \
    pkg-config \
    libssl-dev \
    libncurses-dev \
    libreadline-dev \
    zlib1g-dev \
    libbz2-dev \
    liblz4-dev \
    libzstd-dev \
    liblzma-dev \
    libxml2-dev \
    libcurl4-openssl-dev \
    libpcre2-dev \
    libjemalloc-dev \
    libsnappy-dev \
    bison \
    gnutls-dev \
    libgnutls28-dev \
    libpam0g-dev \
    libaio1 \
    libnuma-dev \
    libsystemd-dev \
    libkrb5-dev \
    libgssapi-krb5-2 \
    procps \
    gosu \
    sudo \
    rsync \
    netcat-openbsd \
    openssl \
    gnupg2 \
    lsb-release \
    mariadb-backup \
    galera-4 \
    socat \
    libaio1

git config --global http.sslverify false
git config --global http.postBuffer 524288000

echo "=== Dependencies installed successfully ==="
