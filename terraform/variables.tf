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
