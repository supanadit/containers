#!/bin/bash
set -e

echo "=== Installing Dexter from source ==="

cd /temp
git clone -b ${DEXTER_VERSION} --depth 1 https://github.com/ankane/dexter.git

cd /temp/dexter

# Install dependencies
bundle install

# Create binstubs for the executable
bundle binstubs pgdexter

# Make the executable available system-wide
chmod +x bin/dexter
cp bin/dexter /usr/local/bin/dexter

echo "=== Dexter installed successfully ==="