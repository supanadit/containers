#!/bin/bash
set -e

echo "=== Installing system dependencies ==="

apt-get update -y && apt-get install -y \
    curl \
    wget \
    tar \
    gzip \
    ca-certificates \
    build-essential \
    libssl-dev \
    libffi-dev \
    libxml2-dev \
    libxslt-dev \
    libpq-dev \
    git

echo "=== Dependencies installed successfully ==="