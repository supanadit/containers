#!/bin/bash
# backup.sh - Backup utilities for MariaDB

set -euo pipefail

source /opt/container/entrypoint.d/scripts/utils/logging.sh

upload_to_s3() {
    local backup_file="$1"
    local s3_bucket="${MARIADB_BACKUP_S3_BUCKET:-}"
    local s3_region="${MARIADB_BACKUP_S3_REGION:-us-east-1}"
    local s3_endpoint="${MARIADB_BACKUP_S3_ENDPOINT:-}"

    if [ -z "$s3_bucket" ]; then
        log_error "S3 bucket not configured"
        return 1
    fi

    log_info "Uploading backup to S3: $s3_bucket"

    if command -v aws >/dev/null 2>&1; then
        if [ -n "$s3_endpoint" ]; then
            aws s3 cp "$backup_file" "s3://$s3_bucket/" --region "$s3_region" --endpoint-url "$s3_endpoint"
        else
            aws s3 cp "$backup_file" "s3://$s3_bucket/" --region "$s3_region"
        fi
        log_info "Backup uploaded to S3 successfully"
    else
        log_warn "AWS CLI not available, skipping S3 upload"
        return 1
    fi
}

upload_to_sftp() {
    local backup_file="$1"
    local sftp_host="${MARIADB_BACKUP_SFTP_HOST:-}"
    local sftp_port="${MARIADB_BACKUP_SFTP_PORT:-22}"
    local sftp_user="${MARIADB_BACKUP_SFTP_USER:-}"
    local sftp_key="${MARIADB_BACKUP_SFTP_KEY:-}"
    local sftp_dest="${MARIADB_BACKUP_SFTP_DEST:-/backups}"

    if [ -z "$sftp_host" ] || [ -z "$sftp_user" ]; then
        log_error "SFTP configuration incomplete"
        return 1
    fi

    log_info "Uploading backup to SFTP: $sftp_host"

    if command -v scp >/dev/null 2>&1; then
        if [ -n "$sftp_key" ]; then
            scp -i "$sftp_key" -P "$sftp_port" "$backup_file" "$sftp_user@$sftp_host:$sftp_dest/"
        else
            scp -P "$sftp_port" "$backup_file" "$sftp_user@$sftp_host:$sftp_dest/"
        fi
        log_info "Backup uploaded to SFTP successfully"
    else
        log_warn "SCP not available, skipping SFTP upload"
        return 1
    fi
}

restore_from_backup() {
    local backup_file="$1"
    local data_dir="${MARIADB_DATA_DIR:-/opt/containers/data}"

    log_info "Restoring from backup: $backup_file"

    if [ ! -f "$backup_file" ]; then
        log_error "Backup file not found: $backup_file"
        return 1
    fi

    mariadbd --user=mysql --datadir="$data_dir" --skip-networking --socket=/tmp/mysql.sock &
    local pid=$!

    sleep 5

    if [[ "$backup_file" == *.sql ]]; then
        mariadb --socket=/tmp/mysql.sock -u root -p"${MARIADB_ROOT_PASSWORD:-}" < "$backup_file"
    else
        log_warn "Unsupported backup format for restore"
        return 1
    fi

    kill $pid
    wait $pid 2>/dev/null || true

    log_info "Restore completed successfully"
}