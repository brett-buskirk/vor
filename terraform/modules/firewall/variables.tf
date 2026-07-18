variable "name" {
  description = "Name of the firewall"
  type        = string
}

variable "droplet_ids" {
  description = "List of droplet IDs to apply the firewall to"
  type        = list(number)
  default     = []
}

variable "tags" {
  description = "Tags to apply the firewall to (droplets with these tags)"
  type        = list(string)
  default     = []
}

variable "inbound_rules" {
  description = "List of inbound firewall rules"
  type = list(object({
    protocol         = string
    port_range       = string
    source_addresses = list(string)
    source_tags      = optional(list(string))
  }))
  default = []
}
