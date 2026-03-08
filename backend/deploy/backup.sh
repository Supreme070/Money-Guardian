#!/usr/bin/env bash
# ────────────────────────────────────────────────────────────────────────────
# Database Backup — Money Guardian
#
# Cron setup (daily at 3 AM):
#   0 3 * * * /opt/moneyguardian/app/backend/deploy/backup.sh >> /var/log/mg-backup.log 2>&1
#
# What this does:
#   1. Dumps PostgreSQL database via docker exec
#   2. Compresses with gzip
#   3. Removes backups older than 30 days
# ────────────────────────────────────────────────────────────────────────────
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BACKEND_DIR="$(dirname "$SCRIPT_DIR")"
BACKUP_DIR="/opt/moneyguardian/backups"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_FILE="$BACKUP_DIR/mg_backup_${TIMESTAMP}.sql.gz"
RETENTION_DAYS=30

echo "[$(date)] Starting database backup..."

# Ensure backup directory exists
mkdir -p "$BACKUP_DIR"

# Load env vars for database credentials
if [ -f "$BACKEND_DIR/.env" ]; then
    set -a
    source "$BACKEND_DIR/.env"
    set +a
fi

POSTGRES_USER="${POSTGRES_USER:-postgres}"
POSTGRES_DB="${POSTGRES_DB:-money_guardian}"

# Dump database
docker compose -f "$BACKEND_DIR/docker-compose.prod.yml" exec -T db \
    pg_dump -U "$POSTGRES_USER" "$POSTGRES_DB" | gzip > "$BACKUP_FILE"

# Verify backup
BACKUP_SIZE=$(stat -c%s "$BACKUP_FILE" 2>/dev/null || stat -f%z "$BACKUP_FILE" 2>/dev/null)
if [ "$BACKUP_SIZE" -lt 100 ]; then
    echo "[$(date)] ERROR: Backup file too small ($BACKUP_SIZE bytes), likely failed"
    rm -f "$BACKUP_FILE"
    exit 1
fi

echo "[$(date)] Backup complete: $BACKUP_FILE ($BACKUP_SIZE bytes)"

# Remove old backups
DELETED=$(find "$BACKUP_DIR" -name "mg_backup_*.sql.gz" -mtime +$RETENTION_DAYS -delete -print | wc -l)
if [ "$DELETED" -gt 0 ]; then
    echo "[$(date)] Cleaned up $DELETED backups older than $RETENTION_DAYS days"
fi
