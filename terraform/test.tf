data "proxmox_virtual_environment_nodes" "available_nodes" {}

data "proxmox_virtual_environment_pools" "available_pools" {}

data "proxmox_virtual_environment_datastores" "available_datastores" {
  node_name = var.default_node_name
}

data "proxmox_virtual_environment_hosts" "first_node_host_entries" {
  node_name = var.default_node_name
}

output "available_nodes" {
  value = data.proxmox_virtual_environment_nodes.available_nodes
}

output "available_datastores" {
  value = data.proxmox_virtual_environment_datastores.available_datastores
}

output "first_node_host_entries" {
  value = data.proxmox_virtual_environment_hosts.first_node_host_entries
}

output "available_pools" {
  value = data.proxmox_virtual_environment_pools.available_pools
}