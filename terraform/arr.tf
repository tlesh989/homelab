resource "proxmox_virtual_environment_container" "arr" {
  node_name    = "bupu"
  vm_id        = 106
  unprivileged = false

  features {
    nesting = true
  }

  cpu {
    architecture = "amd64"
    cores        = 2
    units        = 1024
  }

  disk {
    datastore_id = "vm_data"
    size         = 200
  }

  initialization {
    hostname = "arr"

    dns {
      domain = "tlesh.xyz"
      servers = [
        "1.1.1.1",
      ]
    }

    ip_config {
      ipv4 {
        address = "192.168.233.24/24"
        gateway = "192.168.233.1"
      }
    }

    ip_config {
      ipv4 {
        address = "192.168.220.24/24"
      }
    }

    user_account {
      keys     = [nonsensitive(data.doppler_secrets.this.map.SSH_PUBLIC_KEY)]
      password = data.doppler_secrets.this.map.PM_API_PASSWORD
    }
  }

  memory {
    dedicated = 6144
    swap      = 0
  }

  network_interface {
    bridge      = "vmbr0"
    enabled     = true
    firewall    = true
    mac_address = "BC:24:11:C3:7D:55"
    name        = "eth0"
  }

  network_interface {
    bridge      = "vmbr1"
    enabled     = true
    firewall    = false
    mac_address = "BC:24:11:C3:7D:56"
    name        = "eth1"
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
