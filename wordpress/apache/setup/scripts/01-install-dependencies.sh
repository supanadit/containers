#!/bin/bash
set -e

echo "=== Installing system dependencies ==="

apt-get update && apt-get install -y \
    wget \
    unzip \
    build-essential \
    perl \
    libexpat1 \
    libexpat1-dev \
    libpcre3 \
    libpcre3-dev \
    libssl3 \
    libssl-dev \
    pkg-config \
    libxml2 \
    libxml2-dev \
    libsqlite3-0 \
    libsqlite3-dev \
    libcurl4-openssl-dev \
    libonig5 \
    libonig-dev \
    zlib1g \
    zlib1g-dev \
    curl \
    git \
    autoconf \
    libmemcached11 \
    libmemcached-dev \
    libzip4 \
    libzip-dev \
    libicu72 \
    libicu-dev \
    libgd3 \
    libgd-dev

echo "=== Dependencies installed successfully ==="
