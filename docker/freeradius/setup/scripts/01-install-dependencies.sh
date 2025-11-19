#!/bin/bash
set -e

echo "=== Installing system dependencies ==="

apt-get update && apt-get install -y \
    build-essential \
    autoconf \
    libtool \
    libssl-dev \
    libtalloc-dev \
    libpcap-dev \
    libmariadb-dev \
    libpq-dev \
    libldap2-dev \
    libsasl2-dev \
    libreadline-dev \
    libidn2-dev \
    libcurl4-openssl-dev \
    libjson-c-dev \
    libkrb5-dev \
    libwbclient-dev \
    libpam0g-dev \
    python3-dev \
    curl \
    git

echo "=== Dependencies installed successfully ==="
