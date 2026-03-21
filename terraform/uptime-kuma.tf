resource "proxmox_virtual_environment_container" "uptime_kuma" {
  node_name    = "sturm"
  vm_id        = 116
  unprivileged = true

  features {
    nesting = true
  }

  disk {
    datastore_id = "truenas-lvm"
    size         = 8
  }

  initialization {
    hostname = "uptime-kuma"

    dns {
      domain  = "tlesh.xyz"
      servers = ["1.1.1.1"]
    }

    ip_config {
      ipv4 {
        address = "192.168.233.16/24"
        gateway = "192.168.233.1"
      }
    }

    user_account {
      keys = [nonsensitive(data.doppler_secrets.this.map.SSH_PUBLIC_KEY)]
      # PM_API_PASSWORD reused for container root password (project-wide convention).
      # initialization[0].user_account is in ignore_changes — only applied at initial creation.
      password = data.doppler_secrets.this.map.PM_API_PASSWORD
    }
  }

  memory {
    dedicated = 512
    swap      = 256
  }

  network_interface {
    bridge      = "vmbr0"
    enabled     = true
    firewall    = true
    mac_address = "BC:24:11:A2:3F:11"
    name        = "eth0"
  }

  operating_system {
    template_file_id = proxmox_virtual_environment_download_file.ubuntu_24_04_lxc_template.id
    type             = "ubuntu"
  }

  lifecycle {
    ignore_changes = [
      node_name,
      operating_system[0].template_file_id,
      initialization[0].user_account,
      disk,
    ]
  }

  tags = ["terraform"]
}
