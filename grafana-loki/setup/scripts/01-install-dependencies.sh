#!/bin/bash
set -e

echo "=== Installing system dependencies ==="

apt-get update && apt-get install -y curl unzip

echo "=== Dependencies installed successfully ==="
