resource "proxmox_vm_qemu" "kaz" {
  name        = "kaz"
  target_node = "huma"
  clone       = "ubuntu-cloud"

  desc             = "Docker host"
  os_type          = "ubuntu"
  memory           = 16384
  sockets          = 1
  cores            = 4
  ipconfig0        = "ip=192.168.233.10/32,gw=192.168.233.1"
  automatic_reboot = true
  onboot           = true
  oncreate         = true
  agent            = 1
  qemu_os = "l26"
  nameserver       = "192.168.233.1"
  scsihw           = "virtio-scsi-single"

  disk {
    storage  = "local-lvm"
    type     = "virtio"
    size     = "100G"
    iothread = 1
  }

  network {
    bridge = "vmbr0"
    model  = "virtio"
  }
}