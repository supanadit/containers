#!/bin/bash
set -e

echo "=========================================="
echo "Starting PostgreSQL Setup"
echo "=========================================="

# Set script directory
SCRIPT_DIR="/opt/setup/scripts"

# Make all scripts executable
chmod +x ${SCRIPT_DIR}/*.sh

# Get PostgreSQL major version from environment variable
PG_MAJOR_VERSION="$(echo $POSTGRESQL_VERSION | cut -d'.' -f1)"

# Execute setup scripts in order
${SCRIPT_DIR}/01-install-dependencies.sh
${SCRIPT_DIR}/02-install-postgresql.sh
${SCRIPT_DIR}/03-install-python.sh
${SCRIPT_DIR}/04-install-pgbackrest.sh

if [[ "$PG_MAJOR_VERSION" -lt 18 ]]; then
    ${SCRIPT_DIR}/05-install-citus.sh
    ${SCRIPT_DIR}/06-install-pgstatmonitor.sh
else
    echo "Skipping Citus and pg_stat_monitor installation for PostgreSQL version $PG_MAJOR_VERSION."
fi

${SCRIPT_DIR}/07-install-decoderbufs.sh
${SCRIPT_DIR}/08-install-patroni.sh
${SCRIPT_DIR}/09-install-pgbadger.sh
${SCRIPT_DIR}/10-install-pgbouncer.sh
${SCRIPT_DIR}/11-install-hypopg.sh
${SCRIPT_DIR}/12-install-dexter.sh
${SCRIPT_DIR}/13-install-pgmetrics.sh

if [[ "$PG_MAJOR_VERSION" -lt 18 ]]; then
    ${SCRIPT_DIR}/14-install-pg-repack.sh
else
    echo "Skipping pg_repack installation for PostgreSQL version $PG_MAJOR_VERSION."
fi

${SCRIPT_DIR}/15-install-pg-cron.sh

${SCRIPT_DIR}/99-cleanup.sh

echo "=========================================="
echo "Setup completed successfully!"
echo "=========================================="
