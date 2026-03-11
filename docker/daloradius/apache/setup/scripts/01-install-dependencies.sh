#!/bin/bash
set -e

echo "=== Installing system dependencies ==="

apt-get update

apt-get install -y \
    build-essential \
    autoconf \
    libtool \
    libssl-dev \
    libxml2-dev \
    libpng-dev \
    libjpeg-dev \
    libfreetype6-dev \
    libmariadb-dev \
    libcurl4-openssl-dev \
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
    libgettextpo-dev \
    default-mysql-client \
    mime-support \
    freeradius-utils \
    && rm -rf /var/lib/apt/lists/*

echo "=== Dependencies installed successfully ==="
