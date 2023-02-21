resource "proxmox_vm_qemu" "kaz" {
  name        = "kaz"
  target_node = "huma"
  iso         = "ubuntu-22.04.1-live-server-amd64.iso"

  desc = "Docker server"
  os_type = ubuntu
  memory = 16384
  sockets = 1
  cores = 4
  ssh_user = 
  sshkeys = file("~/.ssh/id_rsa.pub")
  ipconfig0 = [
    gw=192.168.233.1,
    ip=192.168.233.10/24]

  ]
  automatic_reboot = true
  onboot = true
  oncreate = true
  agent = 1
  nameserver = 192.168.233.1

  disk {
    storage = groot
    type = virtio
    size = 100G
  }

  network {
    bridge = vmbr0
    model = virtio
    firewall = false
}
}