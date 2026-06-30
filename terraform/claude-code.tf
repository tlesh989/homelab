resource "proxmox_virtual_environment_container" "claude_code" {
  node_name    = "tika"
  vm_id        = 125
  unprivileged = true

  cpu {
    architecture = "amd64"
    cores        = 1
    units        = 1024
  }

  disk {
    datastore_id = "truenas-lvm"
    size         = 10
  }

  initialization {
    hostname = "claude-code"

    dns {
      domain  = "tlesh.xyz"
      servers = ["192.168.233.3"]
    }

    ip_config {
      ipv4 {
        address = "192.168.233.22/24"
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
    swap      = 0
  }

  network_interface {
    bridge      = "vmbr0"
    enabled     = true
    firewall    = true
    mac_address = "BC:24:11:00:01:19"
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
      disk,
    ]
  }

  features {
    fuse    = false
    keyctl  = false
    mknod   = false
    mount   = []
    nesting = true
  }

  tags = ["terraform"]
}
