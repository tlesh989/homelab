data "proxmox_virtual_environment_nodes" "available_nodes" {}

data "proxmox_virtual_environment_pools" "available_pools" {}

data "proxmox_virtual_environment_datastores" "available_datastores" {
  node_name = "bupu"
}

data "proxmox_virtual_environment_hosts" "first_node_host_entries" {
  node_name = "bupu"
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