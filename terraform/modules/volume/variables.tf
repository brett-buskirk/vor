variable "name" {
  description = "Name of the Block Storage volume"
  type        = string
}

variable "region" {
  description = "DigitalOcean region for the volume (must match the droplet's region)"
  type        = string
}

variable "size_gb" {
  description = "Size of the volume in GiB. Sized for the ClickHouse events table plus Postgres metadata."
  type        = number
  default     = 50
}

variable "filesystem_type" {
  description = "Initial filesystem to format the volume with (ext4 or xfs)"
  type        = string
  default     = "ext4"
}

variable "description" {
  description = "Human-readable description shown in the DigitalOcean console"
  type        = string
  default     = "vor analytics data (PostgreSQL + ClickHouse)"
}

variable "tags" {
  description = "Tags to apply to the volume"
  type        = list(string)
  default     = []
}
