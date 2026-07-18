#!/usr/bin/env bash
# =============================================================================
# Deploy — manual (non-Ansible) path
# =============================================================================
# Syncs docker/plausible/ to the droplet and brings the stack up. Prefer the
# Ansible playbook (ansible/playbooks/site.yml) for production; use this for
# quick iterations or when Ansible isn't available.
#
# Usage:
#   export TAILSCALE_IP=<droplet tailscale ip>   # for the dashboard listener
#   ./scripts/deploy.sh <droplet_public_ip>
# =============================================================================
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
REMOTE_USER="root"

# Deployment prefix — matches Terraform's project_name so paths line up with the
# provisioned resources (droplet /opt/<project_name>, volume mount /mnt/<...>).
# Override for a non-default deployment: PROJECT_NAME=acme ./scripts/deploy.sh ...
PROJECT_NAME="${PROJECT_NAME:-vor}"
REMOTE_DIR="/opt/${PROJECT_NAME}"

# Where the databases + Caddy certs live — the attached Block Storage volume
# mount. Must match DATA_ROOT in docker-compose.yml. Ansible mounts the volume
# here; on the manual path the volume must already be mounted at this path.
DATA_ROOT="${DATA_ROOT:-/mnt/${PROJECT_NAME}-analytics-data}"

GREEN=$'\033[0;32m'
YELLOW=$'\033[1;33m'
RED=$'\033[0;31m'
NC=$'\033[0m'

DROPLET_IP="${1:-}"

# Fall back to the Terraform output if no IP was passed.
if [ -z "${DROPLET_IP}" ]; then
	DROPLET_IP="$(terraform -chdir="${PROJECT_ROOT}/terraform/environments/example" output -raw droplet_ip 2>/dev/null || true)"
fi

if [ -z "${DROPLET_IP}" ]; then
	echo "${RED}Error:${NC} no droplet IP. Pass it as an argument or run terraform apply first:"
	echo "  $0 <droplet_public_ip>"
	exit 1
fi

echo "${GREEN}Deploying vor to ${REMOTE_USER}@${DROPLET_IP}${NC}"

if [ ! -f "${PROJECT_ROOT}/docker/plausible/plausible-conf.env" ]; then
	echo "${YELLOW}Warning:${NC} docker/plausible/plausible-conf.env not found."
	echo "  Copy plausible-conf.env.example, fill in the secrets, then re-run."
fi

# Sync the stack (compose + Caddyfile + clickhouse config + the filled-in env).
# TODO(vor): confirm the include/exclude set — the real env file must ship, the
# *.example files need not.
rsync -avz \
	--exclude '*.example' \
	"${PROJECT_ROOT}/docker/plausible/" \
	"${REMOTE_USER}@${DROPLET_IP}:${REMOTE_DIR}/"

# Bring the stack up. PUBLIC_IP / TAILSCALE_IP drive the Caddy port bindings;
# DATA_ROOT points the DB + cert bind mounts at the Block Storage volume. Create
# the data subdirs first so the first `up` doesn't race Docker's auto-mkdir.
# shellcheck disable=SC2029  # variables intentionally expand locally before SSH
ssh "${REMOTE_USER}@${DROPLET_IP}" \
	"mkdir -p ${DATA_ROOT}/postgres ${DATA_ROOT}/clickhouse ${DATA_ROOT}/clickhouse-logs ${DATA_ROOT}/plausible ${DATA_ROOT}/caddy ${DATA_ROOT}/caddy-config && \
	 cd ${REMOTE_DIR} && \
	 env PUBLIC_IP=${DROPLET_IP} TAILSCALE_IP=${TAILSCALE_IP:-} DATA_ROOT=${DATA_ROOT} docker compose pull && \
	 env PUBLIC_IP=${DROPLET_IP} TAILSCALE_IP=${TAILSCALE_IP:-} DATA_ROOT=${DATA_ROOT} docker compose up -d"

echo "${GREEN}Deploy complete.${NC}"
echo "  Public ingestion : https://<analytics_domain>/api/event"
echo "  Admin dashboard  : over Tailscale (https://${TAILSCALE_IP:-<tailscale-ip>}/)"
