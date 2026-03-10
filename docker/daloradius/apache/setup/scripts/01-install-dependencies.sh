#!/bin/bash
set -e

echo "=== Installing system dependencies ==="

apt-get update

# Install standard Bookworm dependencies first (not SSL-related)
apt-get install -y \
    build-essential \
    autoconf \
    libtool \
    libxml2-dev \
    libpng-dev \
    libjpeg-dev \
    libfreetype6-dev \
    libmariadb-dev \
    libzip-dev \
    bison \
    pkg-config \
    wget \
    curl \
    git \
    unzip \
    libonig-dev \
    libicu-dev \
    libgdbm-dev \
    libreadline-dev \
    libsqlite3-dev \
    libpcre3-dev \
    libcap-dev \
    libargon2-1 \
    libedit-dev \
    libtidy-dev \
    libwebp-dev \
    libexpat1-dev \
    libdb-dev \
    libsnmp-dev \
    libsystemd-dev \
    libpam0g-dev \
    libkrb5-dev \
    libldap2-dev \
    libsasl2-dev \
    libperl-dev \
    libbz2-dev \
    zlib1g-dev \
    libmcrypt-dev \
    libgettextpo-dev

# Add Debian Bullseye repo for OpenSSL 1.1 (needed for PHP 7.4 compatibility)
echo "deb http://deb.debian.org/debian bullseye main" > /etc/apt/sources.list.d/bullseye.list
echo "deb http://security.debian.org/debian-security bullseye-security main" >> /etc/apt/sources.list.d/bullseye.list

apt-get update

# Install OpenSSL 1.1 and Curl 1.1 (needed for PHP 7.4 compilation)
apt-get install -y -t bullseye \
    libssl1.1 \
    libssl-dev \
    libcurl4-openssl-dev

# Hold these packages to prevent them from being upgraded during subsequent installs
apt-mark hold libssl-dev libssl1.1 libcurl4-openssl-dev || true

# Clean up apt cache
rm -rf /var/lib/apt/lists/*

echo "=== Dependencies installed successfully ==="
