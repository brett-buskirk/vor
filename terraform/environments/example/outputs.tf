# =============================================================================
# Outputs — Example Environment
# =============================================================================

output "droplet_ip" {
  description = "Public IPv4 address of the analytics droplet (point analytics_domain here)"
  value       = module.analytics_droplet.ipv4_address
}

output "droplet_private_ip" {
  description = "Private (VPC) IPv4 address of the analytics droplet"
  value       = module.analytics_droplet.ipv4_address_private
}

output "droplet_name" {
  description = "Name of the analytics droplet"
  value       = module.analytics_droplet.name
}

output "analytics_domain" {
  description = "Public hostname for the Plausible instance (Plausible BASE_URL)"
  value       = var.analytics_domain
}

output "volume_id" {
  description = "ID of the Block Storage volume holding the database data dirs"
  value       = module.volume.id
}

output "ssh_command" {
  description = "SSH command to connect to the analytics droplet"
  value       = "ssh root@${module.analytics_droplet.ipv4_address}"
}

output "public_ingestion_url" {
  description = "Where tracked sites send events (the only public Plausible surface)"
  value       = "https://${var.analytics_domain}/api/event"
}

output "dashboard_access" {
  description = "How to reach the admin dashboard (Tailscale-only, not public)"
  value       = "Join the tailnet, then browse to the droplet's Tailscale hostname/IP over HTTPS. See CUSTOMIZATION.md."
}

output "project_dir" {
  description = "Directory on the droplet where the Docker Compose stack lives (keep in sync with ansible/inventory/group_vars/all.yml)"
  value       = local.project_dir
}

output "teardown_hint" {
  description = "Teardown reminder — the data volume is destroyed with the stack"
  value       = "terraform destroy removes the droplet, firewall, AND the data volume (analytics data is lost). Snapshot the volume or run scripts/backup.sh first if you need to keep the data."
}
