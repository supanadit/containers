#!/bin/bash
set -e

echo "=== Installing Dexter from source ==="

cd /temp
git clone -b ${DEXTER_VERSION} --depth 1 https://github.com/ankane/dexter.git

cd /temp/dexter

# Install dependencies
bundle install

# Build the gem
gem build pgdexter.gemspec

# Install the gem system-wide
gem install pgdexter-*.gem

echo "=== Dexter installed successfully ==="