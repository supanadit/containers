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
    procps \
    gosu \
    uuid-dev \
    libossp-uuid-dev \
    libevent-dev \
    libc-ares-dev \
    gettext-base
    
apt-get update && apt-get install -y locales

# Ensure en_US.UTF-8 is in /etc/locale.gen and generate it
echo 'en_US.UTF-8 UTF-8' >> /etc/locale.gen
locale-gen

# Set the default locale
update-locale LANG=en_US.UTF-8

echo "=== Dependencies installed successfully ==="
