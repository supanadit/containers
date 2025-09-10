FROM debian:bookworm

ARG POSTGRESQL_VERSION=13.5

RUN apt-get update -y && apt-get install curl wget -y

WORKDIR /temp/sources
RUN curl -O https://ftp.postgresql.org/pub/source/v${POSTGRESQL_VERSION}/postgresql-${POSTGRESQL_VERSION}.tar.gz

RUN tar -xzf postgresql-${POSTGRESQL_VERSION}.tar.gz

RUN apt-get update && apt-get install -y build-essential libreadline-dev zlib1g-dev

WORKDIR /temp/sources/postgresql-${POSTGRESQL_VERSION}

# Install PostgreSQL
RUN ./configure --prefix=/usr/local/pgsql && make && make install

RUN mkdir -p /usr/local/pgsql/data

RUN useradd -m postgres
RUN chown -R postgres:postgres /usr/local/pgsql
RUN chmod 700 /usr/local/pgsql/data
# End PostgreSQL

# Start PG Backrest
ARG PGBACKREST_VERSION=2.56.0
WORKDIR /temp
RUN mkdir -p /temp/build
RUN wget -q -O - https://github.com/pgbackrest/pgbackrest/archive/release/${PGBACKREST_VERSION}.tar.gz | tar zx -C /temp/build

RUN apt-get update -y && apt-get install -y python3-distutils meson gcc libpq-dev libssl-dev libxml2-dev pkg-config liblz4-dev libzstd-dev libbz2-dev libz-dev libyaml-dev libssh2-1-dev

RUN meson setup /temp/build/pgbackrest /temp/build/pgbackrest-release-${PGBACKREST_VERSION}
RUN ninja -C /temp/build/pgbackrest

RUN cp /temp/build/pgbackrest/src/pgbackrest /usr/bin
RUN chmod 755 /usr/bin/pgbackrest
RUN mkdir -p /etc/pgbackrest
RUN mkdir -p /etc/pgbackrest/conf.d
RUN touch /etc/pgbackrest/pgbackrest.conf
RUN chmod 640 /etc/pgbackrest/pgbackrest.conf
RUN chown postgres:postgres /etc/pgbackrest/pgbackrest.conf

RUN mkdir -p -m 770 /var/log/pgbackrest
RUN chown postgres:postgres /var/log/pgbackrest
# End PG Backrest

RUN apt-get install -y git autoconf automake
ENV PG_CONFIG=/usr/local/pgsql/bin/pg_config

# Start Citus
ARG CITUS_VERSION=11.3.1
WORKDIR /temp
RUN git config --global http.sslVerify false
RUN git clone -b v${CITUS_VERSION} --depth 1 https://github.com/citusdata/citus.git

WORKDIR /temp/citus

RUN apt-get install -y libcurl4-openssl-dev

RUN chmod +x ./configure && bash ./configure
RUN make -s clean && make -s -j8 install
# End Citus

# Start Percona PG Stat Monitor
ARG PG_STAT_MONITOR_VERSION=2.2.0

WORKDIR /temp
RUN git clone -b ${PG_STAT_MONITOR_VERSION} --depth 1 https://github.com/percona/pg_stat_monitor.git

WORKDIR /temp/pg_stat_monitor

RUN make USE_PGXS=1
RUN make USE_PGXS=1 install
# End Percona PG Stat Monitor

# Start Decoderbufs
ARG DECODERBUFS_VERSION=v3.2.2.Final
WORKDIR /temp
RUN git clone -b ${DECODERBUFS_VERSION} --depth 1 https://github.com/debezium/postgres-decoderbufs.git

# Notes: We can build protobuf-c and libprotobuf-c from source, but it too complicated and too many step to execute which lead to very long build time
RUN apt-get install -y protobuf-c-compiler libprotobuf-c-dev

WORKDIR /temp/postgres-decoderbufs/proto
RUN protoc-c --c_out=../src/proto pg_logicaldec.proto

WORKDIR /temp/postgres-decoderbufs
RUN make
RUN make install
# End Decoderbufs

# Install Python
# FAQ
# Q: Why not just install Python via Debian package ?
# A: Because we need custom version of Patroni, which requires a specific Python version.

ARG PYTHON_VERSION=v3.11.2
WORKDIR /temp
RUN git clone -b ${PYTHON_VERSION} --depth 1 https://github.com/python/cpython.git

RUN apt-get install -y libffi-dev

WORKDIR /temp/cpython
RUN ./configure --enable-optimizations && make -j$(nproc) && make altinstall

RUN ln -s /usr/local/bin/python3.11 /usr/local/bin/python3
# End Python

# Install Python 3.11 pip
RUN curl -sS https://bootstrap.pypa.io/get-pip.py | python3
RUN pip3 install --no-cache-dir --upgrade pip setuptools wheel
# END: Install Python 3.11

# Start Patroni
ARG PATRONI_VERSION=v3.0.2
WORKDIR /temp
RUN git clone -b ${PATRONI_VERSION} --depth 1 https://github.com/patroni/patroni.git

WORKDIR /temp/patroni

RUN pip install "psycopg[c]"
RUN pip install cdiff

RUN pip install -r requirements.txt
RUN pip install .[etcd]
# End Patroni

# Finishing ( PostgreSQL )
USER postgres

ENV HOME=/home/postgres

# Initialize the database cluster
RUN /usr/local/pgsql/bin/initdb -D /usr/local/pgsql/data

WORKDIR /home/postgres

CMD ["/usr/local/pgsql/bin/postgres", "-D", "/usr/local/pgsql/data", "-k"]