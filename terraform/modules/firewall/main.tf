# =============================================================================
# Firewall Module
# =============================================================================
# Creates a DigitalOcean Cloud Firewall with configurable inbound rules and
# permissive outbound. Secure by default: only the inbound rules passed in are
# allowed; everything else is denied.
#
# vor's port model is decided by the caller (see environments/example/main.tf):
# 80 + 443 world-open for public event ingestion + ACME TLS, 22 restricted to
# known IPs. The admin dashboard rides Tailscale and needs no inbound holes.
# =============================================================================

terraform {
  required_providers {
    digitalocean = {
      source  = "digitalocean/digitalocean"
      version = "~> 2.0"
    }
  }
}

resource "digitalocean_firewall" "this" {
  name        = var.name
  droplet_ids = var.droplet_ids
  tags        = var.tags

  # Dynamic inbound rules
  dynamic "inbound_rule" {
    for_each = var.inbound_rules
    content {
      protocol         = inbound_rule.value.protocol
      port_range       = inbound_rule.value.port_range
      source_addresses = inbound_rule.value.source_addresses
      source_tags      = lookup(inbound_rule.value, "source_tags", null)
    }
  }

  # Allow all outbound TCP (package installs, ACME, Docker pulls, Tailscale)
  outbound_rule {
    protocol              = "tcp"
    port_range            = "1-65535"
    destination_addresses = ["0.0.0.0/0", "::/0"]
  }

  # Allow all outbound UDP (DNS, NTP, Tailscale DERP/NAT traversal)
  outbound_rule {
    protocol              = "udp"
    port_range            = "1-65535"
    destination_addresses = ["0.0.0.0/0", "::/0"]
  }

  # Allow outbound ICMP (ping)
  outbound_rule {
    protocol              = "icmp"
    destination_addresses = ["0.0.0.0/0", "::/0"]
  }
}
