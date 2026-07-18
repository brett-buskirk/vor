output "id" {
  description = "The ID of the firewall"
  value       = digitalocean_firewall.this.id
}

output "name" {
  description = "The name of the firewall"
  value       = digitalocean_firewall.this.name
}

output "status" {
  description = "The status of the firewall"
  value       = digitalocean_firewall.this.status
}
