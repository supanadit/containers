#!/bin/bash
set -e

echo "=== Installing system dependencies ==="

apt-get update -y && apt-get install -y curl wget tar gzip ca-certificates

echo "=== Dependencies installed successfully ==="
