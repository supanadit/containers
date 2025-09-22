#!/bin/bash
set -e

echo "=== Building and installing CPython 3.11 ==="

cd /temp
git clone -b ${PYTHON_VERSION} --depth 1 https://github.com/python/cpython.git

cd /temp/cpython
./configure --enable-optimizations && make -j$(nproc) && make altinstall

ln -s /usr/local/bin/python3.11 /usr/local/bin/python3
# End Python

# Install Python 3.11 pip
curl -sS https://bootstrap.pypa.io/get-pip.py | python3
pip3 install --no-cache-dir --upgrade pip setuptools wheel

echo "=== CPython 3.11 installed successfully ==="
