#!/bin/bash
set -e

echo "=== Cleaning up build artifacts and temporary files ==="

# Remove remaining temporary download directories
rm -rf /tmp/downloads

echo "=== Removing development packages ==="
apt-get remove -y \
    build-essential \
    autoconf \
    automake \
    autotools-dev \
    binutils-common \
    binutils-x86-64-linux-gnu \
    binutils \
    cpp-12 \
    cpp \
    dpkg-dev \
    fakeroot \
    g++-12 \
    g++ \
    gcc-12 \
    gcc \
    git-man \
    git \
    libc-dev-bin \
    libc-devtools \
    libc6-dev \
    libcrypt-dev \
    libcurl4-openssl-dev \
    libexpat1-dev \
    libgcc-12-dev \
    libhashkit-dev \
    libicu-dev \
    libmemcached-dev \
    libnsl-dev \
    libonig-dev \
    libpcre3-dev \
    libsasl2-dev \
    libsqlite3-dev \
    libssl-dev \
    libstdc++-12-dev \
    libtirpc-dev \
    libxml2-dev \
    linux-libc-dev \
    m4 \
    make \
    manpages-dev \
    patch \
    pkg-config \
    pkgconf-bin \
    pkgconf \
    rpcsvc-proto \
    zlib1g-dev \
    icu-devtools \
    libicu-dev \
    libzip-dev \
    libgd-dev

# Clean up apt cache
apt-get clean
rm -rf /var/lib/apt/lists/* /var/cache/apt/archives

# Remove unnecessary packages
apt-get autoremove --purge -y
apt-get autoclean -y

echo "=== Cleanup completed successfully ==="
