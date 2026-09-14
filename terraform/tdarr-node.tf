resource "proxmox_virtual_environment_container" "tdarr_node" {
  node_name    = "sturm"
  vm_id        = 118
  unprivileged = false

  features {
    nesting = true
  }

  # Intel iGPU passthrough for VAAPI hardware transcode (matches sturm's
  # /dev/dri layout used by Plex).
  device_passthrough {
    path = "/dev/dri/renderD128"
  }

  device_passthrough {
    path = "/dev/dri/card0"
  }

  cpu {
    architecture = "amd64"
    cores        = 4
    units        = 1024
  }

  disk {
    datastore_id = "vm_data"
    size         = 50
  }

  initialization {
    hostname = "tdarr-node"

    dns {
      domain = "tlesh.xyz"
      servers = [
        "1.1.1.1",
      ]
    }

    ip_config {
      ipv4 {
        address = "192.168.233.18/24"
        gateway = "192.168.233.1"
      }
    }

    ip_config {
      ipv4 {
        address = "192.168.220.18/24"
      }
    }

    user_account {
      keys     = [nonsensitive(data.doppler_secrets.this.map.SSH_PUBLIC_KEY)]
      password = data.doppler_secrets.this.map.ROOT_PASSWORD
    }
  }

  memory {
    dedicated = 4096
    swap      = 0
  }

  network_interface {
    bridge      = "vmbr0"
    enabled     = true
    firewall    = true
    mac_address = "BC:24:11:18:00:01"
    name        = "eth0"
  }

  network_interface {
    bridge      = "vmbr1"
    enabled     = true
    firewall    = false
    mac_address = "BC:24:11:18:00:02"
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
