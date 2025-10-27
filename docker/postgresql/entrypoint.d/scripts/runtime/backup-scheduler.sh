#!/bin/bash
# backup-scheduler.sh - Simple pgBackRest backup automation loop
# Schedules full/diff/incremental backups based on environment configuration.

set -euo pipefail

source /opt/container/entrypoint.d/scripts/utils/logging.sh
source /opt/container/entrypoint.d/scripts/utils/cluster.sh

STANZA="${PGBACKREST_STANZA:-default}"
CFG="/etc/pgbackrest.conf"

# Helper function to generate env command that removes all PGBACKREST environment variables
generate_clean_env_command() {
    local env_cmd="env"
    
    # Get all PGBACKREST_* environment variables and add them to the unset list
    while IFS='=' read -r var_name var_value; do
        if [[ "$var_name" =~ ^PGBACKREST_ ]]; then
            env_cmd="$env_cmd -u $var_name"
        fi
    done < <(env | grep '^PGBACKREST_')
    
    echo "$env_cmd"
}

# Cron schedules for backups; defaults chosen to avoid office hours
# Format: "minute hour day month weekday" (standard 5-field cron format)
# Default full backup: daily at 2 AM
FULL_CRON=${PGBACKREST_AUTO_FULL_CRON:-"0 2 * * *"}
# Default diff backup: every 6 hours at 20 minutes past the hour (02:20, 08:20, 14:20, 20:20)
DIFF_CRON=${PGBACKREST_AUTO_DIFF_CRON:-"20 2,8,14,20 * * *"}
# Default incremental backup: every 15 minutes except during full/diff backup hours
INCR_CRON=${PGBACKREST_AUTO_INCR_CRON:-"*/15 * * * *"}
FIRST_INCR_DELAY=${PGBACKREST_AUTO_FIRST_INCR_DELAY:-120} # Wait a bit after start before first incr

PRIMARY_ONLY=${PGBACKREST_AUTO_PRIMARY_ONLY:-true}
PROCESS_NAME="pgbackrest-auto"

BACKUP_TIMEZONE="${PGBACKREST_AUTO_TIMEZONE:-UTC}"

state_dir="${PGBACKREST_AUTO_STATE_DIR:-/tmp/pgbackrest-auto}" # ephemeral is fine; can be mounted if persistence desired
mkdir -p "$state_dir"

ts_now() { date +%s; }

write_pid() { echo $$ >"$state_dir/${PROCESS_NAME}.pid"; }

# Parse cron expression and check if current time matches
# Args: cron_expression
# Returns: 0 if current time matches, 1 if not
cron_matches() {
	local cron_expr="$1"
	local now_min now_hour now_day now_month now_wday
	
	# Get current time components
	now_min=$(TZ="$BACKUP_TIMEZONE" date +%M | sed 's/^0*//')   # Remove leading zeros
	now_hour=$(TZ="$BACKUP_TIMEZONE" date +%H | sed 's/^0*//')  # Remove leading zeros
	now_day=$(TZ="$BACKUP_TIMEZONE" date +%d | sed 's/^0*//')   # Remove leading zeros
	now_month=$(TZ="$BACKUP_TIMEZONE" date +%m | sed 's/^0*//')  # Remove leading zeros
	now_wday=$(TZ="$BACKUP_TIMEZONE" date +%w)                  # 0=Sunday, 1=Monday, etc.
	
	# Handle empty values (when sed removes leading zero from "00")
	[ -z "$now_min" ] && now_min=0
	[ -z "$now_hour" ] && now_hour=0
	[ -z "$now_day" ] && now_day=1
	[ -z "$now_month" ] && now_month=1
	
	# Parse cron expression
	read -ra cron_fields <<< "$cron_expr"
	if [ ${#cron_fields[@]} -ne 5 ]; then
		log_error "Invalid cron expression: $cron_expr (must have 5 fields, got ${#cron_fields[@]})"
		return 1
	fi
	
	local cron_min="${cron_fields[0]}"
	local cron_hour="${cron_fields[1]}"
	local cron_day="${cron_fields[2]}"
	local cron_month="${cron_fields[3]}"
	local cron_wday="${cron_fields[4]}"
	
	# Check each field
	if ! cron_field_matches "$now_min" "$cron_min" 0 59; then return 1; fi
	if ! cron_field_matches "$now_hour" "$cron_hour" 0 23; then return 1; fi
	if ! cron_field_matches "$now_day" "$cron_day" 1 31; then return 1; fi
	if ! cron_field_matches "$now_month" "$cron_month" 1 12; then return 1; fi
	if ! cron_field_matches "$now_wday" "$cron_wday" 0 6; then return 1; fi
	
	return 0
}

# Check if a single cron field matches the current value
# Args: current_value cron_field min_value max_value
cron_field_matches() {
	local current="$1"
	local field="$2"
	local min_val="$3"
	local max_val="$4"
	
	# Handle asterisk (matches all)
	if [ "$field" = "*" ]; then
		return 0
	fi
	
	# Handle step values (e.g., */15)
	if [[ "$field" =~ ^\*/([0-9]+)$ ]]; then
		local step="${BASH_REMATCH[1]}"
		if [ $((current % step)) -eq 0 ]; then
			return 0
		fi
		return 1
	fi
	
	# Handle ranges (e.g., 1-5)
	if [[ "$field" =~ ^([0-9]+)-([0-9]+)$ ]]; then
		local start="${BASH_REMATCH[1]}"
		local end="${BASH_REMATCH[2]}"
		if [ "$current" -ge "$start" ] && [ "$current" -le "$end" ]; then
			return 0
		fi
		return 1
	fi
	
	# Handle comma-separated values (e.g., 1,3,5)
	if [[ "$field" =~ , ]]; then
		local IFS=','
		local values=($field)
		for value in "${values[@]}"; do
			# Recursively check each value (handles ranges and steps in lists)
			if cron_field_matches "$current" "$value" "$min_val" "$max_val"; then
				return 0
			fi
		done
		return 1
	fi
	
	# Handle step values with ranges (e.g., 1-10/2)
	if [[ "$field" =~ ^([0-9]+)-([0-9]+)/([0-9]+)$ ]]; then
		local start="${BASH_REMATCH[1]}"
		local end="${BASH_REMATCH[2]}"
		local step="${BASH_REMATCH[3]}"
		if [ "$current" -ge "$start" ] && [ "$current" -le "$end" ]; then
			if [ $(((current - start) % step)) -eq 0 ]; then
				return 0
			fi
		fi
		return 1
	fi
	
	# Handle exact match
	if [ "$current" -eq "$field" ] 2>/dev/null; then
		return 0
	fi
	
	return 1
}

run_backup() {
	local type="$1"
	local clean_env_cmd
	clean_env_cmd="$(generate_clean_env_command)"
	log_info "[auto-backup] Starting ${type} backup for stanza=${STANZA}"
	if su -c "$clean_env_cmd pgbackrest --config=\"$CFG\" --stanza=\"$STANZA\" backup --type=\"$type\"" postgres; then
		log_info "[auto-backup] ${type} backup completed successfully"
		echo $(ts_now) >"$state_dir/last_${type}"
		return 0
	else
		log_error "[auto-backup] ${type} backup failed"
		return 1
	fi
}

# Check if backup was already run in the current minute to avoid duplicates
backup_already_run_this_minute() {
	local type="$1"
	local state_file="$state_dir/last_${type}"
	local current_minute
	current_minute=$(TZ="$BACKUP_TIMEZONE" date +"%Y-%m-%d %H:%M")
	
	if [ -f "$state_file" ]; then
		local last_run_minute
		last_run_minute=$(TZ="$BACKUP_TIMEZONE" date -d "@$(cat "$state_file" 2>/dev/null || echo 0)" +"%Y-%m-%d %H:%M" 2>/dev/null || echo "")
		if [ "$current_minute" = "$last_run_minute" ]; then
			return 0  # Already run this minute
		fi
	fi
	return 1  # Not run this minute
}

graceful_sleep() {
	local secs="$1"
	local i=0
	while [ $i -lt "$secs" ]; do
		sleep 5
		i=$((i+5))
		# Exit if parent (postgres or patroni) gone
		if [ -n "${PGBACKREST_PARENT_PID:-}" ] && ! kill -0 "$PGBACKREST_PARENT_PID" 2>/dev/null; then
			log_warn "[auto-backup] Parent process disappeared; exiting scheduler"
			exit 0
		fi
	done
}

log_info "[auto-backup] Scheduler starting with cron schedules:"
log_info "[auto-backup]   Full backup: $FULL_CRON"
log_info "[auto-backup]   Diff backup: $DIFF_CRON"  
log_info "[auto-backup]   Incremental backup: $INCR_CRON"
log_info "[auto-backup]   Backup timezone: $BACKUP_TIMEZONE"
write_pid

# Initial delay for incremental to avoid immediate load at container start
graceful_sleep "$FIRST_INCR_DELAY"

while true; do
	if [ "$PRIMARY_ONLY" = "true" ] && ! is_primary_role; then
		log_debug "[auto-backup] Instance not primary; skipping backups this cycle"
		graceful_sleep 30
		continue
	fi

	# Priority: full > diff > incr (check in order of priority)
	# Only run one backup type per minute to avoid conflicts
	
	if cron_matches "$FULL_CRON" && ! backup_already_run_this_minute "full"; then
		log_debug "[auto-backup] Full backup schedule matched: $FULL_CRON"
		run_backup full || true
	elif cron_matches "$DIFF_CRON" && ! backup_already_run_this_minute "diff"; then
		log_debug "[auto-backup] Diff backup schedule matched: $DIFF_CRON"
		run_backup diff || true
	elif cron_matches "$INCR_CRON" && ! backup_already_run_this_minute "incr"; then
		log_debug "[auto-backup] Incremental backup schedule matched: $INCR_CRON"
		run_backup incr || true
	fi

	graceful_sleep 60
done

