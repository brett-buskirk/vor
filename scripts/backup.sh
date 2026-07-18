#!/usr/bin/env bash
# =============================================================================
# Backup — PostgreSQL + ClickHouse to a DigitalOcean Spaces bucket
# =============================================================================
# Dumps the Plausible databases and uploads them to object storage. Intended to
# run ON the droplet (via cron) or over SSH.
#
# This is a SKELETON. The commands below are the intended shape; fill in the
# TODO(vor) markers before relying on it.
#
# Usage:
#   ./scripts/backup.sh
# =============================================================================
set -euo pipefail

# -----------------------------------------------------------------------------
# Configuration (override via environment)
# -----------------------------------------------------------------------------
PROJECT_DIR="${PROJECT_DIR:-/opt/vor}" # TODO(vor): match Terraform's /opt/<project_name>
BACKUP_DIR="${BACKUP_DIR:-/tmp/vor-backup}"
TIMESTAMP="$(date -u +%Y%m%dT%H%M%SZ)"

# DO Spaces target. TODO(vor): source these from the environment / a secrets
# manager — never hardcode credentials in this file.
SPACES_BUCKET="${SPACES_BUCKET:-your-vor-backups}"
SPACES_ENDPOINT="${SPACES_ENDPOINT:-nyc3.digitaloceanspaces.com}"

mkdir -p "${BACKUP_DIR}"

# -----------------------------------------------------------------------------
# PostgreSQL (accounts / site config / metadata)
# -----------------------------------------------------------------------------
echo "Backing up PostgreSQL..."
# TODO(vor): confirm the service name, DB name, and user. Example:
#   docker compose -f "${PROJECT_DIR}/docker-compose.yml" exec -T plausible_db \
#     pg_dump -U postgres plausible_db | gzip > "${BACKUP_DIR}/postgres-${TIMESTAMP}.sql.gz"

# -----------------------------------------------------------------------------
# ClickHouse (the analytics events)
# -----------------------------------------------------------------------------
echo "Backing up ClickHouse..."
# TODO(vor): pick a strategy — `clickhouse-backup`, a `BACKUP` statement, or a
# volume snapshot. A simple per-table dump example:
#   docker compose -f "${PROJECT_DIR}/docker-compose.yml" exec -T plausible_events_db \
#     clickhouse-client --query "BACKUP DATABASE plausible_events_db TO ..."

# -----------------------------------------------------------------------------
# Upload to DO Spaces
# -----------------------------------------------------------------------------
echo "Uploading to s3://${SPACES_BUCKET} (${SPACES_ENDPOINT})..."
# TODO(vor): use s3cmd / aws-cli configured for DO Spaces, e.g.:
#   aws --endpoint-url "https://${SPACES_ENDPOINT}" s3 cp \
#     "${BACKUP_DIR}/" "s3://${SPACES_BUCKET}/${TIMESTAMP}/" --recursive

# TODO(vor): prune old backups (retention policy) and alert on failure.

echo "Backup skeleton finished for ${TIMESTAMP} (no data moved — fill in the TODOs)."
