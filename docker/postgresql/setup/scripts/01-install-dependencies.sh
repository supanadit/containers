#!/bin/bash
set -e

echo "=== Installing system dependencies ==="

apt-get update -y && apt-get install -y \
    curl \
    wget \
    git \
    autoconf \
    automake \
    python3-distutils \
    build-essential \
    libreadline-dev \
    zlib1g-dev \
    meson \
    gcc \
    libpq-dev \
    libssl-dev \
    libxml2-dev \
    pkg-config \
    liblz4-dev \
    libzstd-dev \
    libbz2-dev \
    libz-dev \
    libyaml-dev \
    libssh2-1-dev \
    libcurl4-openssl-dev \
    libffi-dev \
    procps

echo "=== Dependencies installed successfully ==="
