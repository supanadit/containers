#!/bin/bash
set -e

echo "=== Installing system dependencies ==="

apt-get update -y && apt-get install -y \
    curl \
    wget \
    git \
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
    libaio-dev \
    libnuma-dev \
    libsystemd-dev \
    libkrb5-dev \
    libgssapi-krb5-2 \
    procps \
    gosu

echo "=== Dependencies installed successfully ==="
