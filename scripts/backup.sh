#!/usr/bin/env bash
# =============================================================================
# Backup — logical dump of the Plausible databases (PostgreSQL + ClickHouse)
# =============================================================================
# Runs ON the droplet, against the live stack in PROJECT_DIR. Writes a
# timestamped set of dumps to BACKUP_DIR and, if SPACES_BUCKET is set, uploads
# them to a DigitalOcean Spaces bucket.
#
#   PostgreSQL — pg_dump of the metadata DB (accounts, site config).
#   ClickHouse — per-table logical dump (schema + data in Native format).
#
# This is the manual/on-demand path. Scheduling (cron/systemd timer), retention,
# and failure alerting are post-1.0 — see docs/BACKUP.md. For the cheapest
# disaster-recovery hedge, snapshot the whole data volume (docs/BACKUP.md too):
# every stateful path lives on it.
#
# Usage:
#   ./scripts/backup.sh
#   SPACES_BUCKET=my-vor-backups ./scripts/backup.sh     # + offsite copy
# =============================================================================
set -euo pipefail

# -----------------------------------------------------------------------------
# Configuration (override via environment)
# -----------------------------------------------------------------------------
PROJECT_NAME="${PROJECT_NAME:-vor}"
PROJECT_DIR="${PROJECT_DIR:-/opt/${PROJECT_NAME}}"
BACKUP_DIR="${BACKUP_DIR:-/var/backups/${PROJECT_NAME}}"
TIMESTAMP="$(date -u +%Y%m%dT%H%M%SZ)"
DEST="${BACKUP_DIR}/${TIMESTAMP}"

# Database coordinates — must match plausible-conf.env (DATABASE_URL / CH URL).
PG_USER="${PG_USER:-postgres}"
PG_DB="${PG_DB:-plausible_db}"
CH_DB="${CH_DB:-plausible_events_db}"

# Optional offsite copy to DO Spaces. Leave SPACES_BUCKET empty to skip.
# Credentials come from the environment (AWS_ACCESS_KEY_ID / AWS_SECRET_ACCESS_KEY)
# or the aws CLI config — never hardcode them here.
SPACES_BUCKET="${SPACES_BUCKET:-}"
SPACES_ENDPOINT="${SPACES_ENDPOINT:-nyc3.digitaloceanspaces.com}"

# Thin wrapper so every docker compose call targets the deployed stack.
compose() { docker compose -f "${PROJECT_DIR}/docker-compose.yml" "$@"; }

mkdir -p "${DEST}"
echo "vor backup → ${DEST}"

# -----------------------------------------------------------------------------
# PostgreSQL (accounts / site config / metadata)
# -----------------------------------------------------------------------------
echo "  • PostgreSQL — pg_dump ${PG_DB}"
compose exec -T plausible_db pg_dump -U "${PG_USER}" -d "${PG_DB}" \
  | gzip >"${DEST}/postgres-${PG_DB}.sql.gz"

# -----------------------------------------------------------------------------
# ClickHouse (the analytics events)
# -----------------------------------------------------------------------------
# Per-table logical dump: the CREATE statement plus the rows in Native format.
# Restore with `clickhouse-client --query "INSERT INTO <db>.<table> FORMAT Native"`
# after recreating the table from its schema file. Views are skipped (they're
# derived). See docs/BACKUP.md for the full restore procedure.
echo "  • ClickHouse — logical dump of ${CH_DB}"
compose exec -T plausible_events_db clickhouse-client --query \
  "SELECT name FROM system.tables WHERE database = '${CH_DB}' AND engine NOT LIKE '%View%'" \
  | while IFS= read -r table; do
      [ -z "${table}" ] && continue
      echo "      - ${table}"
      compose exec -T plausible_events_db clickhouse-client --query \
        "SHOW CREATE TABLE ${CH_DB}.${table}" >"${DEST}/clickhouse-${table}.schema.sql"
      compose exec -T plausible_events_db clickhouse-client --query \
        "SELECT * FROM ${CH_DB}.${table} FORMAT Native" \
        | gzip >"${DEST}/clickhouse-${table}.native.gz"
    done

# -----------------------------------------------------------------------------
# Optional offsite copy to DO Spaces
# -----------------------------------------------------------------------------
if [ -n "${SPACES_BUCKET}" ]; then
  echo "  • Upload → s3://${SPACES_BUCKET}/${PROJECT_NAME}/${TIMESTAMP}/"
  aws --endpoint-url "https://${SPACES_ENDPOINT}" s3 cp \
    "${DEST}/" "s3://${SPACES_BUCKET}/${PROJECT_NAME}/${TIMESTAMP}/" --recursive
else
  echo "  • Offsite upload skipped (set SPACES_BUCKET to enable)"
fi

echo "Backup complete: ${DEST}"
echo "Scheduling, retention, and alerting are post-1.0 — see docs/BACKUP.md."
