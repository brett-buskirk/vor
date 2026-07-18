# =============================================================================
# Droplet Module
# =============================================================================
# Creates the DigitalOcean droplet that runs the vor Plausible Analytics stack
# (Plausible app + PostgreSQL + ClickHouse + Caddy, via Docker Compose).
#
# Analytics data lives on a separately-managed Block Storage volume (see the
# `volume` module) attached here, so the droplet can be rebuilt without losing
# the PostgreSQL/ClickHouse databases.
# =============================================================================

terraform {
  required_providers {
    digitalocean = {
      source  = "digitalocean/digitalocean"
      version = "~> 2.0"
    }
  }
}

resource "digitalocean_droplet" "this" {
  image    = var.image
  name     = var.name
  region   = var.region
  size     = var.size
  vpc_uuid = var.vpc_uuid
  ssh_keys = var.ssh_fingerprints
  tags     = var.tags

  # Attach the persistent data volume(s) holding the Postgres + ClickHouse
  # data dirs. Keeping the volume attached here means the databases survive a
  # droplet rebuild.
  volume_ids = var.volume_ids

  # TODO(vor): consider a cloud-init `user_data` block that installs Docker +
  # Tailscale on first boot, so the node joins the tailnet before Ansible runs.
  # Left to the Ansible roles for now (see ../../../ansible/).

  # NOTE: intentionally NO `create_before_destroy` here. A Block Storage volume
  # can only be attached to one droplet at a time, so building a replacement
  # droplet before destroying the old one would fail on the volume attachment.
}
