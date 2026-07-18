# =============================================================================
# Variables — Example Environment
# =============================================================================

# -----------------------------------------------------------------------------
# DigitalOcean Authentication
# -----------------------------------------------------------------------------

variable "do_token" {
  description = "DigitalOcean API token"
  type        = string
  sensitive   = true
}

# -----------------------------------------------------------------------------
# Project
# -----------------------------------------------------------------------------

variable "project_name" {
  description = "Short identifier for this deployment (e.g. 'acme', 'myco'). Prefixes all resource names and tags, and derives the droplet name (<project_name>-analytics), firewall, volume, and project dir (/opt/<project_name>). Use lowercase letters, numbers, and hyphens only."
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9-]{0,30}[a-z0-9]$", var.project_name))
    error_message = "project_name must be 2-32 characters, lowercase alphanumeric and hyphens, not starting or ending with a hyphen."
  }
}

# -----------------------------------------------------------------------------
# Infrastructure Configuration
# -----------------------------------------------------------------------------

variable "region" {
  description = "DigitalOcean region slug (e.g. 'nyc3', 'ams3', 'sfo3')"
  type        = string
  default     = "nyc3"
}

variable "droplet_size" {
  description = "Droplet size for the analytics node. ClickHouse needs RAM — s-2vcpu-4gb (~$24/mo) is the recommended minimum."
  type        = string
  default     = "s-2vcpu-4gb"
}

variable "ssh_fingerprints" {
  description = "List of SSH key fingerprints registered with DigitalOcean (from: doctl compute ssh-key list)"
  type        = list(string)
}

variable "volume_size_gb" {
  description = "Size (GiB) of the Block Storage volume holding the Postgres + ClickHouse data dirs. Grows with event volume; resize later if needed."
  type        = number
  default     = 50
}

# -----------------------------------------------------------------------------
# Analytics Configuration
# -----------------------------------------------------------------------------

variable "analytics_domain" {
  description = "Public hostname for the Plausible instance (e.g. 'analytics.example.com'). Becomes Plausible's BASE_URL and the ACME-managed TLS host for the public ingestion endpoint. Point this DNS record at the droplet before applying."
  type        = string
}

# -----------------------------------------------------------------------------
# Security Configuration
# -----------------------------------------------------------------------------

variable "ssh_allowed_ips" {
  description = <<-EOT
    List of IP addresses/CIDRs allowed to SSH to the analytics node.
    Restrict this to known IPs — do NOT use ["0.0.0.0/0", "::/0"].
    The admin dashboard is reached over Tailscale, not SSH, so this list only
    needs your management IP(s).
    Example: ["203.0.113.10/32", "198.51.100.0/24"]
  EOT
  type        = list(string)

  validation {
    condition     = length(var.ssh_allowed_ips) > 0
    error_message = "ssh_allowed_ips must contain at least one entry. Set it to your known IPs."
  }
}
