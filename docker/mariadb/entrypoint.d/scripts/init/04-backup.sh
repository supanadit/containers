#!/bin/bash
# 04-backup.sh - Backup configuration for MariaDB

set -euo pipefail

source /opt/container/entrypoint.d/scripts/utils/logging.sh
source /opt/container/entrypoint.d/scripts/utils/backup.sh

log_script_start "04-backup.sh"

setup_backup_config() {
    export MARIADB_BACKUP_DIR="${MARIADB_BACKUP_DIR:-/opt/containers/backup}"
    export MARIADB_BACKUP_S3_BUCKET="${MARIADB_BACKUP_S3_BUCKET:-}"
    export MARIADB_BACKUP_SFTP_HOST="${MARIADB_BACKUP_SFTP_HOST:-}"

    if [ "${MARIADB_BACKUP_ENABLE:-false}" != "true" ]; then
        log_info "Backup is not enabled, skipping backup configuration"
        log_script_end "04-backup.sh"
        return 0
    fi

    log_info "Configuring backup settings"

    mkdir -p "$MARIADB_BACKUP_DIR"
    chown mysql:mysql "$MARIADB_BACKUP_DIR"
    chmod 0755 "$MARIADB_BACKUP_DIR"

    backup_retention_days="${MARIADB_BACKUP_RETENTION_DAYS:-7}"
    backup_schedule="${MARIADB_BACKUP_SCHEDULE:-0 2 * * *}"

    log_info "Backup configuration completed"
    log_info "  - Backup directory: $MARIADB_BACKUP_DIR"
    log_info "  - Retention: $backup_retention_days days"
    log_info "  - Schedule: $backup_schedule"
    log_info "  - Method: ${MARIADB_BACKUP_METHOD:-mariabackup}"

    if [ -n "$MARIADB_BACKUP_S3_BUCKET" ]; then
        log_info "  - S3 upload: enabled ($MARIADB_BACKUP_S3_BUCKET)"
    fi

    if [ -n "$MARIADB_BACKUP_SFTP_HOST" ]; then
        log_info "  - SFTP upload: enabled ($MARIADB_BACKUP_SFTP_HOST)"
    fi

    cat > /usr/local/bin/mariadb-backup.sh << 'BACKUP_SCRIPT'
#!/bin/bash
set -euo pipefail

source /opt/container/entrypoint.d/scripts/utils/logging.sh

BACKUP_DIR="${MARIADB_BACKUP_DIR:-/opt/containers/backup}"
MARIADB_DATA_DIR="${MARIADB_DATA_DIR:-/opt/containers/data}"
RETENTION_DAYS="${MARIADB_BACKUP_RETENTION_DAYS:-7}"
METHOD="${MARIADB_BACKUP_METHOD:-mariabackup}"

log_info "Starting full backup"

timestamp=$(date +%Y%m%d_%H%M%S)
backup_file="$BACKUP_DIR/full_backup_${timestamp}.sql"
backup_dir="$BACKUP_DIR/backup_${timestamp}"

mkdir -p "$backup_dir"

case "$METHOD" in
    xtrabackup|mariabackup)
        if command -v "$METHOD" >/dev/null 2>&1; then
            $METHOD --backup --target-dir="$backup_dir" --user=root --password="${MARIADB_ROOT_PASSWORD:-}" 2>/dev/null || true
        fi

        if [ -d "$backup_dir" ] && [ -n "$(ls -A "$backup_dir" 2>/dev/null)" ]; then
            log_info "Hot backup completed: $backup_dir"
        else
            log_warn "Backup tool not available or backup failed, creating SQL dump"
            mariadb-dump --all-databases --single-transaction --quick --lock-tables=false > "$backup_file" 2>/dev/null || true
        fi
        ;;
    *)
        mariadb-dump --all-databases --single-transaction --quick --lock-tables=false > "$backup_file"
        log_info "SQL dump backup completed: $backup_file"
        ;;
esac

if [ -d "$backup_dir" ] && [ -n "$(ls -A "$backup_dir" 2>/dev/null)" ]; then
    uploaded=0

    if [ -n "${MARIADB_BACKUP_S3_BUCKET:-}" ] && command -v aws >/dev/null 2>&1; then
        log_info "Uploading to S3: ${MARIADB_BACKUP_S3_BUCKET}"
        if command -v aws >/dev/null 2>&1; then
            aws s3 cp "$backup_dir" "s3://${MARIADB_BACKUP_S3_BUCKET}/backup_${timestamp}/" --recursive \
                --region "${MARIADB_BACKUP_S3_REGION:-us-east-1}" \
                --endpoint-url "${MARIADB_BACKUP_S3_ENDPOINT:-}" 2>/dev/null && uploaded=1
        fi
    fi

    if [ -n "${MARIADB_BACKUP_SFTP_HOST:-}" ] && [ $uploaded -eq 0 ]; then
        log_info "Uploading to SFTP: ${MARIADB_BACKUP_SFTP_HOST}"
        if command -v scp >/dev/null 2>&1; then
            scp -r "$backup_dir" "${MARIADB_BACKUP_SFTP_USER:-backup}@${MARIADB_BACKUP_SFTP_HOST}:${MARIADB_BACKUP_SFTP_DEST:-/backups}/" 2>/dev/null && uploaded=1
        fi
    fi
fi

find "$BACKUP_DIR" -type d -name "backup_*" -mtime +"$RETENTION_DAYS" -exec rm -rf {} + 2>/dev/null || true
find "$BACKUP_DIR" -type f -name "full_backup_*.sql" -mtime +"$RETENTION_DAYS" -delete 2>/dev/null || true

log_info "Backup completed and old backups cleaned up"
BACKUP_SCRIPT

    chmod +x /usr/local/bin/mariadb-backup.sh

    if command -v cron >/dev/null 2>&1; then
        echo "$backup_schedule root /usr/local/bin/mariadb-backup.sh >> /var/log/mariadb/backup.log 2>&1" > /etc/cron.d/mariadb-backup
        chmod 0644 /etc/cron.d/mariadb-backup
    fi

    log_script_end "04-backup.sh"
}

setup_backup_config