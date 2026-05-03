#!/bin/bash
set -e

echo "=== Building and installing MariaDB ==="

# Use cached temp directory if available, otherwise create it
mkdir -p /temp/sources
cd /temp/sources

# Clean up any previous build artifacts
rm -rf server/

# https://github.com/MariaDB/server.git
git clone --branch mariadb-$MARIADB_VERSION https://github.com/MariaDB/server.git --depth 1

# Install MariaDB
cd server
mkdir build

cd build
cmake .. \
    -DCMAKE_INSTALL_PREFIX=/usr/local/mariadb \
    -DCMAKE_BUILD_TYPE=Release \
    -DWITH_SSL=system \
    -DWITH_ZLIB=system \
    -DWITH_READLINE=ON \
    -DWITH_EMBEDDED_SERVER=OFF \
    -DWITH_UNIT_TESTS=OFF \
    -DWITH_WSREP=ON \
    -DWSREP_PROVIDER=/usr/lib/galera/libgalera_smm.so \
    -DENABLED_PROFILING=OFF \
    -DENABLE_DTRACE=OFF \
    -DWITH_SAFEMALLOC=OFF \
    -DWITH_VALGRIND=OFF \
    -DINSTALL_SCRIPTS=ON \
    -DWITHOUT_OQGRAPH=OFF \
    -DWITH_ROCKSDB=OFF \
    -DWITH_CONNECT=OFF

make -j$(nproc)
make install

# Strip binaries to reduce size
find /usr/local/mariadb/bin -type f -executable -exec strip {} \;
find /usr/local/mariadb/lib -name "*.so*" -exec strip {} \;

echo "=== MariaDB installed successfully ==="

# Create mysql user and group for MariaDB
echo "=== Creating mysql user ==="
groupadd -r mysql
useradd -r -g mysql -s /bin/false mysql

echo "=== MySQL user created successfully ==="
