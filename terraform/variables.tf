variable "default_node_name" {
  description = "The default Proxmox node to deploy resources on."
  type        = string
  default     = "bupu"
}

variable "pm_api_user" {
  description = "The username for the Proxmox VE API."
  type        = string
}

variable "pm_api_password" {
  description = "The password for the Proxmox VE API."
  type        = string
  sensitive   = true
}
