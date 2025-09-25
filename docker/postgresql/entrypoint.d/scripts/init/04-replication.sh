#!/bin/bash
set -e

create_replication_user() {
    if [[ "${HA_MODE:-}" == "native" && "${REPLICATION_ROLE:-}" == "primary" ]]; then
        log_info "Creating replication user..."
        psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<-EOSQL
            CREATE USER ${REPLICATION_USER:-replicator} WITH REPLICATION PASSWORD '${REPLICATION_PASSWORD}';
EOSQL
    fi
}

# Main function
main() {
    create_replication_user
}

# Execute main function
main "$@"
