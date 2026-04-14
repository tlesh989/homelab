resource "proxmox_virtual_environment_container" "tailscale" {
  node_name    = "tika"
  vm_id        = 101
  unprivileged = false

  features {
    nesting = true
  }

  disk {
    datastore_id = "vm_data"
    size         = 10
  }

  initialization {
    hostname = "tailscale"

    ip_config {
      ipv4 {
        address = "dhcp"
      }
    }

    user_account {
      keys     = [nonsensitive(data.doppler_secrets.this.map.SSH_PUBLIC_KEY)]
      password = data.doppler_secrets.this.map.PM_API_PASSWORD
    }
  }

  memory {
    dedicated = 2048
    swap      = 0
  }

  network_interface {
    bridge      = "vmbr0"
    enabled     = true
    firewall    = false
    mac_address = "EA:31:E7:19:05:63"
    name        = "eth0"
  }

  operating_system {
    template_file_id = proxmox_download_file.ubuntu_24_04_lxc_template.id
    type             = "ubuntu"
  }

  lifecycle {
    ignore_changes = [
      node_name,
      operating_system[0].template_file_id,
      initialization[0].user_account,
    ]
  }

  tags = [
    "terraform",
  ]
}
