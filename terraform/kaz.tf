resource "proxmox_virtual_environment_vm" "kaz" {
  name        = "kaz"
  description = "Docker host — managed by Terraform"
  tags        = ["terraform", "ubuntu", "docker"]

  node_name = "tika"
  vm_id     = 110

  agent {
    enabled = true
  }

  stop_on_destroy = true

  cpu {
    cores = 4
    type  = "x86-64-v2-AES"
  }

  memory {
    dedicated = 4096
  }

  disk {
    datastore_id = proxmox_storage_nfs.proxmox_nfs.id
    file_id      = proxmox_download_file.ubuntu_24_04_cloud_image.id
    interface    = "virtio0"
    iothread     = true
    discard      = "on"
    size         = 40
  }

  initialization {
    ip_config {
      ipv4 {
        address = "192.168.233.10/24"
        gateway = "192.168.233.1"
      }
    }

    user_account {
      keys     = [nonsensitive(data.doppler_secrets.this.map.SSH_PUBLIC_KEY)]
      password = data.doppler_secrets.this.map.ROOT_PASSWORD
      username = "root"
    }
  }

  network_device {
    bridge      = "vmbr0"
    firewall    = true
    mac_address = "BC:24:11:10:00:01"
  }

  operating_system {
    type = "l26"
  }

  serial_device {}

  lifecycle {
    ignore_changes = [
      node_name,
      disk[0].file_id,
    ]
  }
}
