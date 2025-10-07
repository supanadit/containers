# pgBackRest Cron-Based Backup Scheduler

This document explains how to use the enhanced cron-based backup scheduler for pgBackRest automation.

## Overview

The backup scheduler has been updated to use cron expressions instead of fixed intervals. This provides much more flexibility in scheduling backups, especially to avoid office hours or peak business times.

## Environment Variables

The following environment variables control the backup schedule:

### Cron Schedule Variables

- `PGBACKREST_AUTO_FULL_CRON`: Cron expression for full backups
  - Default: `"0 2 * * *"` (daily at 2:00 AM)
  
- `PGBACKREST_AUTO_DIFF_CRON`: Cron expression for differential backups
  - Default: `"20 2,8,14,20 * * *"` (every 6 hours at :20 minutes past - 02:20, 08:20, 14:20, 20:20)
  
- `PGBACKREST_AUTO_INCR_CRON`: Cron expression for incremental backups
  - Default: `"*/15 * * * *"` (every 15 minutes)

### Other Variables

- `PGBACKREST_AUTO_FIRST_INCR_DELAY`: Delay in seconds before starting incremental backups
  - Default: `120` (2 minutes)
  
- `PGBACKREST_AUTO_PRIMARY_ONLY`: Only run backups on primary node
  - Default: `true`

## Cron Expression Format

Cron expressions use the standard 5-field format:

```
minute hour day month weekday
```

### Field Ranges
- **minute**: 0-59
- **hour**: 0-23 (24-hour format)
- **day**: 1-31
- **month**: 1-12
- **weekday**: 0-6 (0 = Sunday, 1 = Monday, etc.)

### Special Characters
- `*`: Matches any value
- `*/n`: Every n units (e.g., `*/15` = every 15 minutes)
- `n-m`: Range from n to m (e.g., `1-5` = 1, 2, 3, 4, 5)
- `n,m,o`: List of values (e.g., `1,3,5` = 1, 3, and 5)
- `n-m/s`: Range with step (e.g., `1-10/2` = 1, 3, 5, 7, 9)

## Example Schedules

### Conservative (Avoid Business Hours)

```bash
# Full backup: Sundays at 1:00 AM
PGBACKREST_AUTO_FULL_CRON="0 1 * * 0"

# Differential backup: Daily at 2:00 AM (except Sundays when full runs)
PGBACKREST_AUTO_DIFF_CRON="0 2 * * 1-6"

# Incremental backup: Every 30 minutes during off-hours
PGBACKREST_AUTO_INCR_CRON="*/30 0-6,18-23 * * *"
```

### Aggressive (More Frequent Backups)

```bash
# Full backup: Daily at 3:00 AM
PGBACKREST_AUTO_FULL_CRON="0 3 * * *"

# Differential backup: Every 4 hours at :15 past the hour
PGBACKREST_AUTO_DIFF_CRON="15 2,6,10,14,18,22 * * *"

# Incremental backup: Every 10 minutes
PGBACKREST_AUTO_INCR_CRON="*/10 * * * *"
```

### Business Hours Aware

```bash
# Full backup: Saturdays at 11:00 PM
PGBACKREST_AUTO_FULL_CRON="0 23 * * 6"

# Differential backup: Twice daily during off-hours
PGBACKREST_AUTO_DIFF_CRON="0 2,22 * * *"

# Incremental backup: Every 15 minutes outside business hours (9 AM - 6 PM)
PGBACKREST_AUTO_INCR_CRON="*/15 0-8,18-23 * * *"
```

## Validation

The system automatically validates cron expressions when the container starts. Invalid expressions will cause startup to fail with a clear error message.

## Backup Priority

The scheduler follows this priority order:
1. **Full backups** (highest priority)
2. **Differential backups** 
3. **Incremental backups** (lowest priority)

Only one backup type will run per minute to avoid conflicts.

## Logging

The scheduler logs its activities with timestamps:
- Startup messages show the configured cron schedules
- Debug messages indicate when a schedule matches
- Info messages track backup start/completion
- Error messages report backup failures

## Migration from Interval-Based Scheduling

If you were previously using interval-based environment variables, here's the mapping:

| Old Variable | Old Default | New Variable | New Default Equivalent |
|--------------|-------------|--------------|------------------------|
| `PGBACKREST_AUTO_FULL_INTERVAL` | 86400s (24h) | `PGBACKREST_AUTO_FULL_CRON` | `"0 2 * * *"` (daily 2 AM) |
| `PGBACKREST_AUTO_DIFF_INTERVAL` | 21600s (6h) | `PGBACKREST_AUTO_DIFF_CRON` | `"20 2,8,14,20 * * *"` (every 6h) |
| `PGBACKREST_AUTO_INCR_INTERVAL` | 900s (15m) | `PGBACKREST_AUTO_INCR_CRON` | `"*/15 * * * *"` (every 15m) |

The new defaults are designed to avoid typical business hours while maintaining similar backup frequency.