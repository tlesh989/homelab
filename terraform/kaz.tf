resource "proxmox_vm_qemu" "kaz" {
  name        = "kaz"
  target_node = "huma"
  clone       = "ubuntu-cloud"

  desc             = "Docker host"
  os_type          = "ubuntu"
  memory           = 16384
  sockets          = 1
  cores            = 4
  ipconfig0        = "ip=192.168.233.10/24,gw=192.168.233.1"
  ssh_user         = var.ssh_user
  sshkeys          = file("~/.ssh/id_rsa.pub")
  ciuser           = var.ssh_user
  cipassword       = var.ssh_pass
  automatic_reboot = true
  onboot           = true
  agent            = 1
  qemu_os          = "l26"
  nameserver       = "192.168.233.1"
  scsihw           = "virtio-scsi-single"
  tags             = "terraform"
  vm_state         = "running"

  disks {
    virtio {
      virtio0 {
        disk {
          # backup             = true
          # cache              = "none"
          # discard            = true
          iothread = true
          # mbps_r_burst       = 0.0
          # mbps_r_concurrent  = 0.0
          # mbps_wr_burst      = 0.0
          # mbps_wr_concurrent = 0.0
          replicate = true
          size      = 100
          storage   = "local-lvm"
        }
      }
    }
  }


  network {
    bridge = "vmbr0"
    model  = "virtio"
  }
}
