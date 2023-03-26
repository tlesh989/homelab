variable "ssh_pass" {
  description = "Override the default cloud-init user's password. Sensitive."
  type        = string
  sensitive   = true
}

variable "ssh_user" {
  description = "Only applies when define_connection_info is true. The user with which to connect to the guest for preprovisioning. Forces re-creation on change."
  type        = string
}

variable "ssh_mkpasswd" {
  description = "Override the default cloud-init user's password. Not sure if this is used..."
  type        = string
}

variable "cf_tlesh_net_zone" {
  description = "The Cloudflare zone identifier to target for the resource."
  type        = string
}

variable "cf_tlesh_net_api" {
  description = "The Cloudflare API Token for operations."
  type        = string
}
