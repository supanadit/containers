#!/bin/bash
set -e

echo "=== Building and installing CPython ==="

cd /temp
git clone -b ${PYTHON_VERSION} --depth 1 https://github.com/python/cpython.git

cd /temp/cpython
./configure --enable-optimizations && make -j$(nproc) && make altinstall

# Extract major.minor version from PYTHON_VERSION (e.g., v3.13.9 -> 3.13)
PYTHON_MAJOR_MINOR=$(echo ${PYTHON_VERSION} | sed 's/^v//' | cut -d'.' -f1,2)
ln -s /usr/local/bin/python${PYTHON_MAJOR_MINOR} /usr/local/bin/python3
# End Python

# Install Python pip
curl -sS https://bootstrap.pypa.io/get-pip.py | python3
pip3 install --no-cache-dir --upgrade pip setuptools wheel

echo "=== CPython installed successfully ==="
