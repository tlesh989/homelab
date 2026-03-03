data "proxmox_virtual_environment_vm" "ubuntu_cloud" {
  node_name = "bupu"
  vm_id     = 901
}

output "ubuntu_cloud_details" {
  value       = data.proxmox_virtual_environment_vm.ubuntu_cloud
  description = "Details for the ubuntu cloud vm"
}
