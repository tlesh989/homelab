resource "proxmox_virtual_environment_container" "pi_hole" {
  node_name    = "sturm"
  vm_id        = 102
  unprivileged = true

  console {
    enabled   = true
    tty_count = 2
    type      = "tty"
  }

  disk {
    datastore_id = "vm_data"
    size         = 8
  }

  initialization {
    hostname = "pi-hole"

    dns {
      domain = "127.0.0.1"
      servers = [
        "1.1.1.1",
      ]
    }

    ip_config {
      ipv4 {
        address = "192.168.233.3/24"
        gateway = "192.168.233.1"
      }
    }

    user_account {
      keys     = [nonsensitive(data.doppler_secrets.this.map.SSH_PUBLIC_KEY)]
      password = data.doppler_secrets.this.map.ROOT_PASSWORD
    }
  }

  memory {
    dedicated = 1024
    swap      = 512
  }

  network_interface {
    bridge      = "vmbr0"
    enabled     = true
    firewall    = true
    mac_address = "BC:24:11:F4:5D:EC"
    name        = "eth0"
  }

  operating_system {
    template_file_id = proxmox_virtual_environment_download_file.ubuntu_24_04_lxc_template.id
    type             = "ubuntu"
  }

  lifecycle {
    ignore_changes = [
      operating_system[0].template_file_id,
    ]
  }
}
