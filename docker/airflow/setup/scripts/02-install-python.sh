#!/bin/bash
set -e

echo "=== Setting up Python environment ==="

# Upgrade pip
pip install --upgrade pip setuptools wheel

# Install virtualenv for isolation (optional)
pip install virtualenv

echo "=== Python environment setup completed ==="