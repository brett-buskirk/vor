#!/usr/bin/env bash
# =============================================================================
# Tailscale Setup — install Tailscale on the vor analytics droplet
# =============================================================================
# The admin dashboard is bound to the Tailscale interface, so the droplet must
# join your tailnet. Public event ingestion does NOT depend on Tailscale.
#
# Run this ON the droplet (or via `ssh root@<droplet> 'bash -s' < this script`).
#
# Usage:
#   ./scripts/setup-tailscale.sh
# =============================================================================
set -euo pipefail

echo "Installing Tailscale..."

# Staged install (avoid piping curl straight into a shell).
curl -fsSL https://tailscale.com/install.sh -o /tmp/tailscale-install.sh
sh /tmp/tailscale-install.sh
rm -f /tmp/tailscale-install.sh

# TODO(vor): support non-interactive auth for automation, e.g.:
#   tailscale up --authkey "${TAILSCALE_AUTH_KEY}" --ssh
# Pass TAILSCALE_AUTH_KEY via the environment — never hardcode it here.

cat <<'EOF'

==================================================
Tailscale installed. Authenticate this node:

  sudo tailscale up

Follow the printed URL to log in with your tailnet account.

Then grab this node's Tailscale IPv4:

  tailscale ip -4

Set that as TAILSCALE_IP for the compose stack (docker/plausible), so Caddy
binds the ADMIN DASHBOARD listener to the tailnet interface only. The public
event-ingestion endpoint stays on the droplet's PUBLIC IP (ports 80/443).

Browse the dashboard from any device on the SAME tailnet:

  https://<that-tailscale-ip>/     (accept the internal-CA cert, or wire up
                                     Tailscale certs — see Caddyfile.example)
==================================================
EOF
