FROM debian:bookworm

ARG POSTGRESQL_VERSION=13.5

RUN apt-get update -y && apt-get install curl -y

WORKDIR /temp/sources
RUN curl -O https://ftp.postgresql.org/pub/source/v${POSTGRESQL_VERSION}/postgresql-${POSTGRESQL_VERSION}.tar.gz

RUN tar -xzf postgresql-${POSTGRESQL_VERSION}.tar.gz

RUN apt-get update && apt-get install -y \
    build-essential \
    libreadline-dev \
    zlib1g-dev \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /temp/sources/postgresql-${POSTGRESQL_VERSION}

# Install PostgreSQL
RUN ./configure --prefix=/usr/local/pgsql && make && make install

RUN mkdir -p /usr/local/pgsql/data

RUN useradd -m postgres
RUN chown -R postgres:postgres /usr/local/pgsql
RUN chmod 700 /usr/local/pgsql/data

# Switch to postgres user
USER postgres

# Initialize the database cluster
RUN /usr/local/pgsql/bin/initdb -D /usr/local/pgsql/data


ENV HOME=/home/postgres

CMD ["/usr/local/pgsql/bin/postgres", "-D", "/usr/local/pgsql/data"]