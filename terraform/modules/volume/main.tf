# =============================================================================
# Volume Module
# =============================================================================
# Creates a DigitalOcean Block Storage volume for the vor analytics data.
# The PostgreSQL (accounts/site config) and ClickHouse (events) data dirs live
# on this volume so analytics data survives droplet rebuilds.
#
# The volume is attached to the droplet by the `droplet` module (volume_ids).
# =============================================================================

terraform {
  required_providers {
    digitalocean = {
      source  = "digitalocean/digitalocean"
      version = "~> 2.0"
    }
  }
}

resource "digitalocean_volume" "this" {
  name                    = var.name
  region                  = var.region
  size                    = var.size_gb
  initial_filesystem_type = var.filesystem_type
  description             = var.description
  tags                    = var.tags

  # TODO(vor): decide on snapshot policy. DO snapshots of this volume are the
  # cheapest disaster-recovery hedge for the databases — either automate them
  # (digitalocean_volume_snapshot) or document a manual cadence in SECURITY.md.
}
