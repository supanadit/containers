#!/bin/bash
# backup-scheduler.sh - Simple pgBackRest backup automation loop
# Schedules full/diff/incremental backups based on environment configuration.

set -euo pipefail

source /opt/container/entrypoint.d/scripts/utils/logging.sh

STANZA="${PGBACKREST_STANZA:-default}"
CFG="/etc/pgbackrest.conf"

# Intervals (seconds); defaults chosen to be conservative if enabled without overrides
FULL_INT=${PGBACKREST_AUTO_FULL_INTERVAL:-86400}          # 24h
DIFF_INT=${PGBACKREST_AUTO_DIFF_INTERVAL:-21600}          # 6h
INCR_INT=${PGBACKREST_AUTO_INCR_INTERVAL:-900}            # 15m
FIRST_INCR_DELAY=${PGBACKREST_AUTO_FIRST_INCR_DELAY:-120} # Wait a bit after start before first incr

PRIMARY_ONLY=${PGBACKREST_AUTO_PRIMARY_ONLY:-true}
PROCESS_NAME="pgbackrest-auto"

state_dir="${PGBACKREST_AUTO_STATE_DIR:-/tmp/pgbackrest-auto}" # ephemeral is fine; can be mounted if persistence desired
mkdir -p "$state_dir"

ts_now() { date +%s; }

write_pid() { echo $$ >"$state_dir/${PROCESS_NAME}.pid"; }

is_primary() {
	# When Patroni in use, rely on patroni API if available; else check pg_isready + recovery status
	if [ "${PATRONI_ENABLE:-false}" = "true" ] && command -v curl >/dev/null 2>&1; then
		local endpoint="${PATRONI_REST_URL:-http://localhost:8008}"/master
		if curl -sf "${endpoint}" >/dev/null 2>&1; then
			return 0
		fi
	fi
	# Fallback: query pg to see if in recovery
	if command -v psql >/dev/null 2>&1; then
		if PGPASSWORD="${POSTGRES_PASSWORD:-}" psql -qtAX -U "${POSTGRES_USER:-postgres}" -h localhost -p "${POSTGRESQL_PORT:-5432}" -d "${POSTGRES_DB:-postgres}" -c "select pg_is_in_recovery();" 2>/dev/null | grep -q '^f'; then
			return 0
		fi
	fi
	return 1
}

run_backup() {
	local type="$1"
	log_info "[auto-backup] Starting ${type} backup for stanza=${STANZA}"
	if env -u PGBACKREST_ENABLE pgbackrest --config="$CFG" --stanza="$STANZA" backup --type="$type"; then
		log_info "[auto-backup] ${type} backup completed successfully"
		echo $(ts_now) >"$state_dir/last_${type}"
		return 0
	else
		log_error "[auto-backup] ${type} backup failed"
		return 1
	fi
}

time_since() {
	local file="$1"; local now=$(ts_now)
	if [ ! -f "$file" ]; then
		echo 999999999
		return 0
	fi
	local then=$(cat "$file" 2>/dev/null || echo 0)
	echo $((now-then))
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

log_info "[auto-backup] Scheduler starting (full=${FULL_INT}s diff=${DIFF_INT}s incr=${INCR_INT}s)"
write_pid

# Initial delay for incremental to avoid immediate load at container start
graceful_sleep "$FIRST_INCR_DELAY"

while true; do
	if [ "$PRIMARY_ONLY" = "true" ] && ! is_primary; then
		log_debug "[auto-backup] Instance not primary; skipping backups this cycle"
		graceful_sleep 30
		continue
	fi

	now=$(ts_now)
	since_full=$(time_since "$state_dir/last_full")
	since_diff=$(time_since "$state_dir/last_diff")
	since_incr=$(time_since "$state_dir/last_incr")

	# Priority: full > diff > incr
	if [ "$since_full" -ge "$FULL_INT" ]; then
		run_backup full || true
	elif [ "$since_diff" -ge "$DIFF_INT" ]; then
		run_backup diff || true
	elif [ "$since_incr" -ge "$INCR_INT" ]; then
		run_backup incr || true
	fi

	graceful_sleep 60
done

