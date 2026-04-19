resource "proxmox_virtual_environment_container" "netdata" {
  node_name    = "tika"
  vm_id        = 105
  unprivileged = true

  description = "Netdata monitoring parent"

  features {
    nesting = true
  }

  disk {
    datastore_id = "vm_data"
    size         = 8
  }

  initialization {
    hostname = "netdata"

    dns {
      domain  = "tlesh.xyz"
      servers = ["1.1.1.1"]
    }

    ip_config {
      ipv4 {
        address = "192.168.233.23/24"
        gateway = "192.168.233.1"
      }
    }

    user_account {
      keys     = [nonsensitive(data.doppler_secrets.this.map.SSH_PUBLIC_KEY)]
      password = data.doppler_secrets.this.map.PM_API_PASSWORD
    }
  }

  memory {
    dedicated = 512
    swap      = 0
  }

  network_interface {
    bridge      = "vmbr0"
    enabled     = true
    firewall    = true
    mac_address = "BC:24:11:A2:3C:55"
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

  tags = ["terraform"]
}
