resource "proxmox_virtual_environment_container" "plex" {
  node_name    = "sturm"
  vm_id        = 103
  unprivileged = false

  features {
    nesting = true
  }

  mount_point {
    path   = "/media/plex"
    volume = "/mnt/plex-media"
  }

  cpu {
    architecture = "amd64"
    cores        = 3
    units        = 1024
  }

  disk {
    datastore_id = "vm_data"
    size         = 100
  }

  initialization {
    hostname = "plex"

    dns {
      domain = "tlesh.xyz"
      servers = [
        "1.1.1.1",
      ]
    }

    ip_config {
      ipv4 {
        address = "192.168.233.12/24"
        gateway = "192.168.233.1"
      }
    }

    ip_config {
      ipv4 {
        address = "192.168.220.12/24"
      }
    }

    user_account {
      keys     = [nonsensitive(data.doppler_secrets.this.map.SSH_PUBLIC_KEY)]
      password = data.doppler_secrets.this.map.ROOT_PASSWORD
    }
  }

  memory {
    dedicated = 12288
    swap      = 0
  }

  network_interface {
    bridge      = "vmbr0"
    enabled     = true
    firewall    = false
    mac_address = "BC:24:11:74:AB:1A"
    name        = "eth0"
  }

  network_interface {
    bridge      = "vmbr1"
    enabled     = true
    firewall    = false
    mac_address = "BC:24:11:74:AB:1B"
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
      mount_point,
    ]
  }

  tags = [
    "terraform",
  ]
}
