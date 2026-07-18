# =============================================================================
# vor — Example Environment
# =============================================================================
# Self-hosted Plausible Analytics on a single DigitalOcean droplet.
#
# This configuration creates:
#   - One analytics droplet (Plausible + PostgreSQL + ClickHouse + Caddy)
#   - A Block Storage volume for the database data dirs (survives rebuilds)
#   - A Cloud Firewall implementing vor's port model (see below)
#
# THE DEFINING ARCHITECTURAL SPLIT:
#   vor MUST expose a PUBLIC event-ingestion endpoint — visitors on the tracked
#   sites POST to it. So ports 80/443 are world-open (public /js/* + /api/event
#   plus ACME TLS), while the admin DASHBOARD is bound to the Tailscale
#   interface only (enforced in the Caddyfile, not the firewall). Postgres and
#   ClickHouse are never public.
#
# Prerequisites:
#   - SSH key added to your DigitalOcean account (fingerprint in tfvars)
#   - A domain/subdomain for analytics_domain, pointed at the droplet
#
# See CUSTOMIZATION.md for a step-by-step deployment guide.
# =============================================================================

terraform {
  required_version = ">= 1.0.0"

  required_providers {
    digitalocean = {
      source  = "digitalocean/digitalocean"
      version = "~> 2.0"
    }
  }

  # Remote state backend (recommended for team/production use).
  # Uncomment and fill in your values before running terraform apply.
  # TODO(vor): document the DO Spaces remote-state setup in CUSTOMIZATION.md.
  # backend "s3" {
  #   endpoint                    = "<region>.digitaloceanspaces.com"
  #   key                         = "terraform/<project_name>/terraform.tfstate"
  #   bucket                      = "<project_name>-terraform-state"
  #   region                      = "us-east-1"  # Required by provider; ignored by DO Spaces
  #   skip_credentials_validation = true
  #   skip_metadata_api_check     = true
  #   skip_region_validation      = true
  # }
}

provider "digitalocean" {
  token = var.do_token
}

# =============================================================================
# Locals — every name derives from project_name
# =============================================================================

locals {
  droplet_name  = "${var.project_name}-analytics"
  firewall_name = "${var.project_name}-analytics-firewall"
  volume_name   = "${var.project_name}-analytics-data"

  # Where the Docker Compose stack lives on the droplet. Threaded to Ansible
  # via ansible/inventory/group_vars/all.yml (keep the two in sync).
  project_dir = "/opt/${var.project_name}"
}

# =============================================================================
# Analytics Data Volume
# =============================================================================
# Holds the Postgres + ClickHouse data dirs so analytics data survives a
# droplet rebuild. Attached to the droplet below via volume_ids.
# =============================================================================

module "volume" {
  source = "../../modules/volume"

  name    = local.volume_name
  region  = var.region
  size_gb = var.volume_size_gb
  tags    = [var.project_name, "analytics"]
}

# =============================================================================
# Analytics Droplet
# =============================================================================

module "analytics_droplet" {
  source = "../../modules/droplet"

  name             = local.droplet_name
  region           = var.region
  size             = var.droplet_size
  image            = "ubuntu-24-04-x64"
  ssh_fingerprints = var.ssh_fingerprints
  volume_ids       = [module.volume.id]
  tags             = [var.project_name, "analytics", "plausible"]

  # TODO(vor): set vpc_uuid if you want the droplet inside a specific VPC. For
  # a single-node deployment the internal Docker network already isolates the
  # databases, so a VPC is optional.
}

# =============================================================================
# Cloud Firewall — vor port model
# =============================================================================
# 80 + 443 : world-open. Public event ingestion (/api/event, /js/*) and ACME
#            TLS both need these reachable from anywhere.
# 22       : restricted to var.ssh_allowed_ips (never 0.0.0.0/0).
#
# The admin dashboard is NOT opened here — it rides Tailscale, which needs no
# inbound firewall holes (NAT traversal / DERP). Postgres (5432) and ClickHouse
# (8123/9000) are intentionally absent, so they are denied from the public
# internet; they are reached only over the internal Docker network / localhost.
# =============================================================================

module "analytics_firewall" {
  source = "../../modules/firewall"

  name        = local.firewall_name
  droplet_ids = [module.analytics_droplet.id]

  inbound_rules = [
    {
      protocol         = "tcp"
      port_range       = "80"
      source_addresses = ["0.0.0.0/0", "::/0"]
    },
    {
      protocol         = "tcp"
      port_range       = "443"
      source_addresses = ["0.0.0.0/0", "::/0"]
    },
    {
      protocol         = "tcp"
      port_range       = "22"
      source_addresses = var.ssh_allowed_ips
    },
  ]
}

# =============================================================================
# DNS (optional)
# =============================================================================
# TODO(vor): if your domain's DNS is managed in DigitalOcean, uncomment to have
# `terraform apply` also point analytics_domain at the droplet. Otherwise create
# the A record manually at your DNS provider before requesting TLS certs.
#
# resource "digitalocean_record" "analytics" {
#   domain = var.dns_domain   # the apex, e.g. "example.com"
#   type   = "A"
#   name   = "analytics"      # subdomain label of analytics_domain
#   value  = module.analytics_droplet.ipv4_address
#   ttl    = 300
# }

# =============================================================================
# Ansible inventory (optional)
# =============================================================================
# TODO(vor): optionally render ansible/inventory/production.yml from a
# templatefile() here (see heimdall for the pattern) so the inventory tracks
# terraform apply automatically. For now, copy the droplet IP into
# ansible/inventory/manual.yml by hand (see manual.yml.example).
