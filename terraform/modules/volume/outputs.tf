output "id" {
  description = "The ID of the volume"
  value       = digitalocean_volume.this.id
}

output "name" {
  description = "The name of the volume"
  value       = digitalocean_volume.this.name
}

output "urn" {
  description = "The URN of the volume"
  value       = digitalocean_volume.this.urn
}
