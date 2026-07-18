#!/usr/bin/env bash
# =============================================================================
# Preflight Check — validate the local environment before deploying vor
# =============================================================================
# Confirms the required tools are installed and that Terraform variables have
# been populated from the example. Run from anywhere in the repo.
#
# Usage:
#   ./scripts/preflight.sh
#
# Exit 0 = all required checks passed (warnings may still be present).
# Exit 1 = one or more required checks failed.
# =============================================================================
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"

RED=$'\033[0;31m'
GREEN=$'\033[0;32m'
YELLOW=$'\033[1;33m'
BOLD=$'\033[1m'
NC=$'\033[0m'

FAILURES=0
WARNINGS=0

pass() { echo "  ${GREEN}✓${NC} $1"; }
fail() { echo "  ${RED}✗${NC} $1"; FAILURES=$((FAILURES + 1)); }
warn() { echo "  ${YELLOW}!${NC} $1"; WARNINGS=$((WARNINGS + 1)); }
header() { echo; echo "${BOLD}$1${NC}"; }

# -----------------------------------------------------------------------------
# Tools
# -----------------------------------------------------------------------------
header "Tools"

for tool in terraform ansible doctl tailscale; do
	if command -v "${tool}" >/dev/null 2>&1; then
		pass "${tool} found"
	elif [ "${tool}" = "tailscale" ]; then
		# Tailscale runs on the droplet, not necessarily the control machine.
		warn "${tool} not found locally (only needed on the droplet)"
	else
		fail "${tool} not found — install it before deploying"
	fi
done

# TODO(vor): version-gate the tools (terraform >= 1.0, ansible >= 2.12) like
# heimdall's preflight does, once minimum versions are locked.

# -----------------------------------------------------------------------------
# Terraform configuration
# -----------------------------------------------------------------------------
header "Terraform configuration"

TFVARS="${PROJECT_ROOT}/terraform/environments/example/terraform.tfvars"
TFVARS_EXAMPLE="${TFVARS}.example"

if [ -f "${TFVARS}" ]; then
	pass "terraform.tfvars exists"
	if grep -qE 'dop_v1_your|your-project-name|ab:cd:ef|your.home.ip|analytics.example.com' "${TFVARS}"; then
		fail "terraform.tfvars still contains placeholder values — fill them in"
	else
		pass "terraform.tfvars has no obvious placeholders"
	fi
	if grep -qE '"0\.0\.0\.0/0"' "${TFVARS}"; then
		fail "ssh_allowed_ips includes 0.0.0.0/0 — restrict SSH to your IP(s)"
	else
		pass "ssh_allowed_ips is not open to the world"
	fi
else
	if [ -f "${TFVARS_EXAMPLE}" ]; then
		fail "terraform.tfvars not found — copy and edit it: cp ${TFVARS_EXAMPLE} ${TFVARS}"
	else
		fail "terraform.tfvars.example is missing"
	fi
fi

# TODO(vor): also check the Plausible env file and Ansible group_vars once the
# deployment flow is finalized (docker/plausible/plausible-conf.env present, no
# CHANGE_ME left; ansible project_name/analytics_domain set).

# -----------------------------------------------------------------------------
# Summary
# -----------------------------------------------------------------------------
echo
echo "=================================================="
if [ "${FAILURES}" -eq 0 ] && [ "${WARNINGS}" -eq 0 ]; then
	echo "${GREEN}${BOLD}All checks passed. Ready to deploy.${NC}"
elif [ "${FAILURES}" -eq 0 ]; then
	echo "${YELLOW}${BOLD}${WARNINGS} warning(s) — review before deploying.${NC}"
else
	echo "${RED}${BOLD}${FAILURES} check(s) failed — fix the above before deploying.${NC}"
	echo "=================================================="
	exit 1
fi
echo "=================================================="
