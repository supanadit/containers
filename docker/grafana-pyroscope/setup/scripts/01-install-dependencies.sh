#!/bin/bash
set -e

echo "=== Installing system dependencies ==="

apt-get update && apt-get install -y curl

echo "=== Dependencies installed successfully ==="
